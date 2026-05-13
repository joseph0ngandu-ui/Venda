import type { Server } from 'node:http';
import express from 'express';
import cors from 'cors';
import {
  getPort,
  isCorsOriginAllowed,
  shouldAutoMigrateOnStartup,
  validateRuntimeConfig,
} from './config/env';
import apiRoutes from './routes/api';
import { checkDbConnectivity, closeDbPool, initDb, verifyDbSchema } from './config/db';

validateRuntimeConfig();

const app = express();
const PORT = getPort();
const SHUTDOWN_TIMEOUT_MS = 10_000;

let server: Server | null = null;
let isReady = false;
let shutdownPromise: Promise<void> | null = null;

const buildHealthPayload = (status: 'ok' | 'starting', ready: boolean, details?: Record<string, unknown>) => ({
  status,
  ready,
  service: 'venda-api',
  timestamp: new Date().toISOString(),
  ...details,
});

const buildReadinessPayload = (
  status: 'ready' | 'starting' | 'degraded',
  ready: boolean,
  database: 'ok' | 'starting' | 'unavailable'
) => ({
  status,
  ready,
  service: 'venda-api',
  timestamp: new Date().toISOString(),
  checks: {
    database,
  },
});

const isSameOriginRequest = (origin: string, requestHost: string | undefined, requestProtocols: string[]) => {
  if (!requestHost) {
    return false;
  }

  return requestProtocols.some(protocol => `${protocol}://${requestHost}` === origin);
};

const closeHttpServer = async () => {
  if (!server) {
    return;
  }

  await new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error(`Timed out waiting ${SHUTDOWN_TIMEOUT_MS}ms for HTTP server shutdown`));
    }, SHUTDOWN_TIMEOUT_MS);
    timeout.unref();

    server?.close(error => {
      clearTimeout(timeout);

      if (error) {
        reject(error);
        return;
      }

      resolve();
    });
  });
};

const shutdown = async (reason: string, exitCode = 0) => {
  if (shutdownPromise) {
    return shutdownPromise;
  }

  isReady = false;
  console.log(`Starting graceful shutdown (${reason})`);

  shutdownPromise = (async () => {
    let resolvedExitCode = exitCode;

    try {
      await closeHttpServer();
    } catch (error) {
      console.error('HTTP server shutdown failed:', error);
      resolvedExitCode = 1;
    }

    try {
      await closeDbPool();
    } catch (error) {
      console.error('Database pool shutdown failed:', error);
      resolvedExitCode = 1;
    }

    process.exit(resolvedExitCode);
  })();

  return shutdownPromise;
};

process.on('SIGTERM', () => {
  void shutdown('SIGTERM');
});

process.on('SIGINT', () => {
  void shutdown('SIGINT');
});

process.on('unhandledRejection', error => {
  console.error('Unhandled promise rejection:', error);
  void shutdown('unhandledRejection', 1);
});

process.on('uncaughtException', error => {
  console.error('Uncaught exception:', error);
  void shutdown('uncaughtException', 1);
});

app.disable('x-powered-by');

app.use((req, res, next) => {
  const origin = req.header('Origin');
  const requestHost = req.header('X-Forwarded-Host')?.split(',')[0]?.trim() || req.header('Host');
  const forwardedProto = req.header('X-Forwarded-Proto')?.split(',')[0]?.trim();
  const requestProtocols = [forwardedProto, req.protocol].filter((value): value is string => Boolean(value));

  if (!origin || isSameOriginRequest(origin, requestHost, requestProtocols) || isCorsOriginAllowed(origin)) {
    next();
    return;
  }

  res.status(403).json({ error: 'Origin not allowed by CORS policy' });
});

app.use(
  cors({
    origin(origin, callback) {
      callback(null, isCorsOriginAllowed(origin));
    },
  })
);
app.use(express.json({ limit: '10mb' })); // Support for large offline batches

app.use('/api/v1', apiRoutes);

const handleLiveness = (req: express.Request, res: express.Response) => {
  res.json(buildHealthPayload('ok', isReady));
};

const handleReadiness = async (req: express.Request, res: express.Response) => {
  if (!isReady) {
    res.status(503).json(buildReadinessPayload('starting', false, 'starting'));
    return;
  }

  try {
    await checkDbConnectivity();
    res.json(buildReadinessPayload('ready', true, 'ok'));
  } catch (error) {
    console.error('Readiness check failed:', error);
    res.status(503).json(buildReadinessPayload('degraded', false, 'unavailable'));
  }
};

app.get('/live', handleLiveness);
app.get('/health/live', handleLiveness);

app.get('/ready', async (req, res) => {
  await handleReadiness(req, res);
});

app.get('/health/ready', async (req, res) => {
  await handleReadiness(req, res);
});

// Legacy health endpoint retained for compatibility with existing smoke tooling and integrations.
app.get('/health', handleLiveness);

const startServer = async () => {
  try {
    if (shouldAutoMigrateOnStartup()) {
      console.log('DB_AUTO_MIGRATE enabled; applying database schema before startup');
      await initDb();
    } else {
      console.log('DB_AUTO_MIGRATE disabled; verifying database schema before startup');
      await verifyDbSchema();
    }

    await new Promise<void>((resolve, reject) => {
      const listeningServer = app.listen(PORT, () => resolve());
      listeningServer.once('error', reject);
      server = listeningServer;
    });

    isReady = true;
    console.log(`Venda Backend API running on port ${PORT}`);
  } catch (error) {
    console.error('Failed to start Venda Backend API:', error);

    try {
      await closeDbPool();
    } catch (closeError) {
      console.error('Failed to close database pool after startup error:', closeError);
    }

    process.exit(1);
  }
};

void startServer();
