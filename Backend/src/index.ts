import express from 'express';
import cors from 'cors';
import { getPort, isCorsOriginAllowed, validateRuntimeConfig } from './config/env';
import apiRoutes from './routes/api';
import { initDb } from './config/db';

validateRuntimeConfig();

const app = express();
const PORT = getPort();

const isSameOriginRequest = (origin: string, requestHost: string | undefined, requestProtocols: string[]) => {
  if (!requestHost) {
    return false;
  }

  return requestProtocols.some(protocol => `${protocol}://${requestHost}` === origin);
};

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

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'venda-api', timestamp: new Date().toISOString() });
});

const startServer = async () => {
  try {
    await initDb();

    app.listen(PORT, () => {
      console.log(`Venda Backend API running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start Venda Backend API:', error);
    process.exit(1);
  }
};

void startServer();
