#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { setTimeout: sleep } = require('node:timers/promises');
const dotenv = require('dotenv');
const { Pool } = require('pg');

const projectRoot = path.resolve(__dirname, '..');
dotenv.config({ path: path.join(projectRoot, '.env') });

const distEntry = path.join(projectRoot, 'dist', 'index.js');

if (!fs.existsSync(distEntry)) {
  console.error('[smoke] Missing build output at dist/index.js. Run `npm run build` first.');
  process.exit(1);
}

const parsePort = value => {
  const port = Number.parseInt(String(value), 10);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`Invalid SMOKE_PORT value: ${value}`);
  }
  return port;
};

const port = parsePort(process.env.SMOKE_PORT || 3101);
const baseUrl = `http://127.0.0.1:${port}`;
const databaseUrl = process.env.DATABASE_URL?.trim();
const jwtSecret = process.env.JWT_SECRET?.trim();

if (!databaseUrl) {
  console.error('[smoke] DATABASE_URL is required. Export it or set it in Backend/.env.');
  process.exit(1);
}

if (!jwtSecret) {
  console.error('[smoke] JWT_SECRET is required. Export it or set it in Backend/.env.');
  process.exit(1);
}

const runId = `${Date.now()}`;
const merchantPhone = `26097${runId.slice(-7)}`;
const merchantPin = '2468';
const merchantPayload = {
  owner_name: 'Smoke Owner',
  business_name: `Smoke Test ${runId}`,
  business_type: 'retail',
  phone: merchantPhone,
  pin: merchantPin,
};

let serverProcess;
let cleanupPool;
let cleanupScheduled = false;

const prefixStream = (stream, prefix) => {
  let buffer = '';
  stream.setEncoding('utf8');
  stream.on('data', chunk => {
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      if (line.trim()) {
        console.log(`${prefix}${line}`);
      }
    }
  });
  stream.on('end', () => {
    if (buffer.trim()) {
      console.log(`${prefix}${buffer}`);
    }
  });
};

const waitForExit = child =>
  new Promise(resolve => {
    child.once('exit', (code, signal) => {
      resolve({ code, signal });
    });
  });

const stopServer = async () => {
  if (!serverProcess || serverProcess.exitCode !== null) {
    return;
  }

  const exitPromise = waitForExit(serverProcess);
  serverProcess.kill('SIGTERM');

  const exited = await Promise.race([
    exitPromise.then(result => ({ timedOut: false, result })),
    sleep(5_000).then(() => ({ timedOut: true })),
  ]);

  if (exited.timedOut) {
    serverProcess.kill('SIGKILL');
    await exitPromise;
  }
};

const cleanupMerchant = async () => {
  if (!cleanupScheduled) {
    return;
  }

  cleanupPool ??= new Pool({ connectionString: databaseUrl });
  await cleanupPool.query('DELETE FROM merchants WHERE phone = $1', [merchantPhone]);
};

const parseJson = text => {
  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch (error) {
    return null;
  }
};

const requestJson = async (method, route, body, headers = {}) => {
  const response = await fetch(`${baseUrl}${route}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(5_000),
  });

  const text = await response.text();
  return {
    status: response.status,
    json: parseJson(text),
    text,
  };
};

const waitForHealth = async () => {
  const deadline = Date.now() + 30_000;
  let lastError;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${baseUrl}/health`, {
        signal: AbortSignal.timeout(2_000),
      });
      const json = await response.json();

      if (response.ok && json?.status === 'ok') {
        return json;
      }

      lastError = new Error(`Unexpected health response: ${response.status} ${JSON.stringify(json)}`);
    } catch (error) {
      lastError = error;
    }

    if (serverProcess?.exitCode !== null) {
      throw new Error(`Server exited before health check passed with code ${serverProcess.exitCode}`);
    }

    await sleep(500);
  }

  throw lastError ?? new Error('Timed out waiting for health check');
};

const assertCondition = (condition, message, details) => {
  if (!condition) {
    const detailBlock = details ? `\n${JSON.stringify(details, null, 2)}` : '';
    throw new Error(`${message}${detailBlock}`);
  }
};

const main = async () => {
  console.log(`[smoke] Starting compiled backend on ${baseUrl}`);
  serverProcess = spawn(process.execPath, [distEntry], {
    cwd: projectRoot,
    env: {
      ...process.env,
      PORT: String(port),
      DATABASE_URL: databaseUrl,
      JWT_SECRET: jwtSecret,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  prefixStream(serverProcess.stdout, '[api] ');
  prefixStream(serverProcess.stderr, '[api] ');

  const health = await waitForHealth();
  console.log(`[smoke] Health check passed at ${health.timestamp}`);

  const registerResponse = await requestJson('POST', '/api/v1/auth/register', merchantPayload);
  assertCondition(registerResponse.status === 201, 'Merchant registration failed', registerResponse);
  assertCondition(typeof registerResponse.json?.token === 'string', 'Registration did not return a JWT', registerResponse);
  assertCondition(registerResponse.json?.merchant?.phone === merchantPhone, 'Registration response phone mismatch', registerResponse);
  cleanupScheduled = true;
  console.log('[smoke] Merchant registration passed');

  const loginResponse = await requestJson('POST', '/api/v1/auth/login', {
    phone: merchantPhone,
    pin: merchantPin,
  });
  assertCondition(loginResponse.status === 200, 'Merchant login failed', loginResponse);
  assertCondition(typeof loginResponse.json?.token === 'string', 'Login did not return a JWT', loginResponse);
  assertCondition(
    loginResponse.json?.company_code === registerResponse.json?.company_code,
    'Company code changed between register and login',
    {
      register_company_code: registerResponse.json?.company_code,
      login_company_code: loginResponse.json?.company_code,
    }
  );
  console.log('[smoke] Merchant login passed');

  const meResponse = await requestJson('GET', '/api/v1/auth/me', undefined, {
    authorization: `Bearer ${loginResponse.json.token}`,
  });
  assertCondition(meResponse.status === 200, 'GET /auth/me failed', meResponse);
  assertCondition(meResponse.json?.authenticated === true, 'GET /auth/me did not return an authenticated session', meResponse);
  assertCondition(meResponse.json?.merchant?.phone === merchantPhone, 'GET /auth/me returned the wrong merchant', meResponse);
  assertCondition(meResponse.json?.staff?.role === 'admin', 'GET /auth/me returned an unexpected staff role', meResponse);
  console.log('[smoke] Protected auth flow passed');

  console.log('[smoke] Live backend smoke passed');
};

(async () => {
  try {
    await main();
  } catch (error) {
    const message = error instanceof Error ? error.stack || error.message : String(error);
    console.error(`[smoke] ${message}`);
    process.exitCode = 1;
  } finally {
    try {
      await cleanupMerchant();
    } catch (error) {
      const message = error instanceof Error ? error.stack || error.message : String(error);
      console.error(`[smoke] Cleanup failed: ${message}`);
      process.exitCode = 1;
    }

    try {
      await stopServer();
    } catch (error) {
      const message = error instanceof Error ? error.stack || error.message : String(error);
      console.error(`[smoke] Failed to stop backend cleanly: ${message}`);
      process.exitCode = 1;
    }

    if (cleanupPool) {
      await cleanupPool.end();
    }
  }
})();
