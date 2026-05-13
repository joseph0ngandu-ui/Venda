#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { spawn } = require('node:child_process');
const { setTimeout: sleep } = require('node:timers/promises');
const dotenv = require('dotenv');
const { Pool } = require('pg');

const projectRoot = path.resolve(__dirname, '..');
dotenv.config({ path: path.join(projectRoot, '.env') });

const distEntry = path.join(projectRoot, 'dist', 'index.js');
const distMigrateEntry = path.join(projectRoot, 'dist', 'scripts', 'db-migrate.js');

if (!fs.existsSync(distEntry)) {
  console.error('[smoke] Missing build output at dist/index.js. Run `npm run build` first.');
  process.exit(1);
}

if (!fs.existsSync(distMigrateEntry)) {
  console.error('[smoke] Missing migration build output at dist/scripts/db-migrate.js. Run `npm run build` first.');
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
const staffInitialPin = '1357';
const staffRotatedPin = '9753';

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

const runNodeScript = async (entryPath, label, env = process.env) => {
  const child = spawn(process.execPath, [entryPath], {
    cwd: projectRoot,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  prefixStream(child.stdout, `${label} `);
  prefixStream(child.stderr, `${label} `);

  const result = await waitForExit(child);

  if (result.code !== 0) {
    throw new Error(`${label.trim()} exited with code ${result.code ?? 'unknown'}`);
  }
};

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
  let response;

  try {
    response = await fetch(`${baseUrl}${route}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...headers,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(5_000),
    });
  } catch (error) {
    const serverExitCode =
      typeof serverProcess?.exitCode === 'number' ? `; server exited with code ${serverProcess.exitCode}` : '';
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Request failed for ${method} ${route}: ${message}${serverExitCode}`);
  }

  const text = await response.text();
  return {
    status: response.status,
    json: parseJson(text),
    text,
  };
};

const waitForEndpoint = async (route, expectedStatus, validateBody, label) => {
  const deadline = Date.now() + 30_000;
  let lastError;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${baseUrl}${route}`, {
        signal: AbortSignal.timeout(2_000),
      });
      const json = await response.json();

      if (response.status === expectedStatus && validateBody(json)) {
        return json;
      }

      lastError = new Error(`Unexpected ${label} response: ${response.status} ${JSON.stringify(json)}`);
    } catch (error) {
      lastError = error;
    }

    if (serverProcess?.exitCode !== null) {
      throw new Error(`Server exited before health check passed with code ${serverProcess.exitCode}`);
    }

    await sleep(500);
  }

  throw lastError ?? new Error(`Timed out waiting for ${label}`);
};

const waitForHealth = async () => {
  return waitForEndpoint('/health/live', 200, json => json?.status === 'ok', 'liveness check');
};

const waitForReadiness = async () => {
  return waitForEndpoint(
    '/health/ready',
    200,
    json => (json?.status === 'ready' || json?.status === 'ok') && json?.ready === true && json?.checks?.database === 'ok',
    'readiness check'
  );
};

const assertCondition = (condition, message, details) => {
  if (!condition) {
    const detailBlock = details ? `\n${JSON.stringify(details, null, 2)}` : '';
    throw new Error(`${message}${detailBlock}`);
  }
};

const main = async () => {
  console.log('[smoke] Applying database migrations with the dedicated entrypoint');
  await runNodeScript(distMigrateEntry, '[migrate]', {
    ...process.env,
    DATABASE_URL: databaseUrl,
  });

  console.log(`[smoke] Starting compiled backend on ${baseUrl}`);
  serverProcess = spawn(process.execPath, [distEntry], {
    cwd: projectRoot,
    env: {
      ...process.env,
      DB_AUTO_MIGRATE: 'false',
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
  const readiness = await waitForReadiness();
  console.log(`[smoke] Readiness check passed at ${readiness.timestamp}`);

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

  const adminToken = loginResponse.json.token;
  const companyCode = loginResponse.json.company_code;

  const createStaffResponse = await requestJson(
    'POST',
    '/api/v1/staff',
    {
      name: 'Smoke Cashier',
      role: 'cashier',
      pin: staffInitialPin,
    },
    {
      authorization: `Bearer ${adminToken}`,
    }
  );
  assertCondition(createStaffResponse.status === 201, 'Staff creation failed', createStaffResponse);
  assertCondition(createStaffResponse.json?.staff?.role === 'cashier', 'Staff create returned wrong role', createStaffResponse);
  assertCondition(
    typeof createStaffResponse.json?.staff?.id === 'string' && createStaffResponse.json.staff.id.length > 0,
    'Staff create did not return a staff id',
    createStaffResponse
  );
  console.log('[smoke] Staff creation passed');

  const createdStaffId = createStaffResponse.json.staff.id;

  const adminListResponse = await requestJson('GET', '/api/v1/staff', undefined, {
    authorization: `Bearer ${adminToken}`,
  });
  assertCondition(adminListResponse.status === 200, 'Admin staff listing failed', adminListResponse);
  assertCondition(
    adminListResponse.json?.permissions?.can_create_staff === true,
    'Admin staff listing returned unexpected permissions',
    adminListResponse
  );
  assertCondition(
    Array.isArray(adminListResponse.json?.staff) &&
      adminListResponse.json.staff.some(member => member.id === createdStaffId && member.role === 'cashier'),
    'Created cashier was missing from staff directory',
    adminListResponse
  );
  console.log('[smoke] Staff directory listing passed');

  const cashierLoginResponse = await requestJson('POST', '/api/v1/auth/join', {
    company_code: companyCode,
    pin: staffInitialPin,
  });
  assertCondition(cashierLoginResponse.status === 200, 'Cashier join/login failed', cashierLoginResponse);
  assertCondition(cashierLoginResponse.json?.staff?.id === createdStaffId, 'Cashier login resolved the wrong staff member', cashierLoginResponse);
  assertCondition(cashierLoginResponse.json?.staff?.role === 'cashier', 'Cashier login returned wrong role', cashierLoginResponse);
  console.log('[smoke] Staff join/login passed');

  const cashierListResponse = await requestJson('GET', '/api/v1/staff', undefined, {
    authorization: `Bearer ${cashierLoginResponse.json.token}`,
  });
  assertCondition(cashierListResponse.status === 403, 'Cashier unexpectedly gained staff directory access', cashierListResponse);
  console.log('[smoke] Cashier authorization boundary passed');

  const promoteStaffResponse = await requestJson(
    'PATCH',
    `/api/v1/staff/${createdStaffId}`,
    {
      name: 'Smoke Manager',
      role: 'manager',
    },
    {
      authorization: `Bearer ${adminToken}`,
    }
  );
  assertCondition(promoteStaffResponse.status === 200, 'Staff promotion failed', promoteStaffResponse);
  assertCondition(promoteStaffResponse.json?.staff?.role === 'manager', 'Staff promotion returned wrong role', promoteStaffResponse);
  console.log('[smoke] Staff promotion passed');

  const managerLoginResponse = await requestJson('POST', '/api/v1/auth/join', {
    company_code: companyCode,
    pin: staffInitialPin,
  });
  assertCondition(managerLoginResponse.status === 200, 'Manager join/login failed after promotion', managerLoginResponse);
  assertCondition(managerLoginResponse.json?.staff?.role === 'manager', 'Manager login returned wrong role', managerLoginResponse);

  const managerListResponse = await requestJson('GET', '/api/v1/staff', undefined, {
    authorization: `Bearer ${managerLoginResponse.json.token}`,
  });
  assertCondition(managerListResponse.status === 200, 'Manager could not access staff directory', managerListResponse);
  assertCondition(
    managerListResponse.json?.permissions?.can_manage_team === true &&
      managerListResponse.json?.permissions?.can_create_staff === false,
    'Manager permissions were not scoped correctly',
    managerListResponse
  );
  console.log('[smoke] Manager authorization boundary passed');

  const deactivateResponse = await requestJson(
    'POST',
    `/api/v1/staff/${createdStaffId}/deactivate`,
    {},
    {
      authorization: `Bearer ${adminToken}`,
    }
  );
  assertCondition(deactivateResponse.status === 200, 'Staff deactivation failed', deactivateResponse);
  assertCondition(deactivateResponse.json?.staff?.is_active === false, 'Staff deactivation did not mark user inactive', deactivateResponse);

  const inactiveJoinResponse = await requestJson('POST', '/api/v1/auth/join', {
    company_code: companyCode,
    pin: staffInitialPin,
  });
  assertCondition(inactiveJoinResponse.status === 401, 'Inactive staff could still log in', inactiveJoinResponse);

  const inactiveMeResponse = await requestJson('GET', '/api/v1/auth/me', undefined, {
    authorization: `Bearer ${managerLoginResponse.json.token}`,
  });
  assertCondition(inactiveMeResponse.status === 403, 'Inactive staff token was still accepted', inactiveMeResponse);
  console.log('[smoke] Staff deactivation enforcement passed');

  const reactivateResponse = await requestJson(
    'POST',
    `/api/v1/staff/${createdStaffId}/reactivate`,
    {},
    {
      authorization: `Bearer ${adminToken}`,
    }
  );
  assertCondition(reactivateResponse.status === 200, 'Staff reactivation failed', reactivateResponse);
  assertCondition(reactivateResponse.json?.staff?.is_active === true, 'Staff reactivation did not mark user active', reactivateResponse);

  const rotatePinResponse = await requestJson(
    'POST',
    `/api/v1/staff/${createdStaffId}/pin`,
    {
      pin: staffRotatedPin,
    },
    {
      authorization: `Bearer ${adminToken}`,
    }
  );
  assertCondition(rotatePinResponse.status === 200, 'Staff PIN rotation failed', rotatePinResponse);

  const stalePinJoinResponse = await requestJson('POST', '/api/v1/auth/join', {
    company_code: companyCode,
    pin: staffInitialPin,
  });
  assertCondition(stalePinJoinResponse.status === 401, 'Old staff PIN still worked after rotation', stalePinJoinResponse);

  const rotatedPinJoinResponse = await requestJson('POST', '/api/v1/auth/join', {
    company_code: companyCode,
    pin: staffRotatedPin,
  });
  assertCondition(rotatedPinJoinResponse.status === 200, 'Rotated staff PIN login failed', rotatedPinJoinResponse);
  assertCondition(
    rotatedPinJoinResponse.json?.staff?.id === createdStaffId && rotatedPinJoinResponse.json?.staff?.role === 'manager',
    'Rotated staff login returned the wrong account',
    rotatedPinJoinResponse
  );
  console.log('[smoke] Staff reactivation and PIN rotation passed');

  const syncCursorBeforePush = new Date(Date.now() - 1_000).toISOString();
  const syncTimestamp = new Date().toISOString();
  const productId = randomUUID();
  const saleId = randomUUID();
  const saleLineItemId = randomUUID();
  const saleReference = `SMOKE-${runId}`;

  const syncPushResponse = await requestJson(
    'POST',
    '/api/v1/sync/push',
    {
      products: [
        {
          id: productId,
          name: 'Smoke Sync Product',
          category: 'smoke-tests',
          pricing_type: 'fixed',
          suggested_price: '21.25',
          min_price: '21.25',
          max_price: '21.25',
          stock_quantity: 6,
          low_stock_threshold: 1,
          track_stock: true,
          is_service: false,
          is_active: true,
          created_at: syncTimestamp,
          updated_at: syncTimestamp,
        },
      ],
      sales: [
        {
          id: saleId,
          staff_id: createdStaffId,
          reference: saleReference,
          total_amount: '42.50',
          payment_method: 'cash',
          customer_phone: '260971234567',
          status: 'completed',
          notes: 'Smoke sync sale',
          created_at: syncTimestamp,
          updated_at: syncTimestamp,
        },
      ],
      sale_line_items: [
        {
          id: saleLineItemId,
          sale_id: saleId,
          product_id: productId,
          quantity: '2',
          unit_price: '21.25',
          original_price: '21.25',
          final_price: '21.25',
          discount_amount: '0',
          discount_reason: null,
          price_override_by: null,
          created_at: syncTimestamp,
          updated_at: syncTimestamp,
        },
      ],
      momo_transactions: [],
      credit_entries: [],
      staff: [],
    },
    {
      authorization: `Bearer ${adminToken}`,
    }
  );
  assertCondition(syncPushResponse.status === 200, 'Sync push failed', syncPushResponse);
  assertCondition(syncPushResponse.json?.success === true, 'Sync push did not return success', syncPushResponse);
  console.log('[smoke] Sync push passed');

  const syncPullResponse = await requestJson(
    'GET',
    `/api/v1/sync/pull?updated_after=${encodeURIComponent(syncCursorBeforePush)}`,
    undefined,
    {
      authorization: `Bearer ${adminToken}`,
    }
  );
  assertCondition(syncPullResponse.status === 200, 'Sync pull failed', syncPullResponse);
  assertCondition(
    syncPullResponse.json?.data?.products?.some(product => product.id === productId),
    'Sync pull did not return the pushed product',
    syncPullResponse
  );
  assertCondition(
    syncPullResponse.json?.data?.sales?.some(sale => sale.id === saleId && sale.reference === saleReference),
    'Sync pull did not return the pushed sale',
    syncPullResponse
  );
  assertCondition(
    syncPullResponse.json?.data?.sale_line_items?.some(item => item.id === saleLineItemId && item.sale_id === saleId),
    'Sync pull did not return the pushed sale line item',
    syncPullResponse
  );
  console.log('[smoke] Sync round-trip passed');

  const reportsResponse = await requestJson('GET', '/api/v1/reports/summary?timeframe=week', undefined, {
    authorization: `Bearer ${adminToken}`,
  });
  assertCondition(reportsResponse.status === 200, 'Reports summary failed', reportsResponse);
  assertCondition(
    Number(reportsResponse.json?.summary?.sales_count ?? 0) >= 1,
    'Reports summary did not count the synced sale',
    reportsResponse
  );
  assertCondition(
    Number(reportsResponse.json?.summary?.total_revenue ?? 0) >= 42.5,
    'Reports summary did not include synced revenue',
    reportsResponse
  );
  assertCondition(
    reportsResponse.json?.payment_breakdown?.some(row => row.method === 'cash' && Number(row.amount ?? 0) >= 42.5),
    'Reports summary did not include the cash payment breakdown',
    reportsResponse
  );
  assertCondition(
    reportsResponse.json?.top_products?.some(product => product.id === productId && Number(product.revenue ?? 0) >= 42.5),
    'Reports summary did not include the synced product',
    reportsResponse
  );
  assertCondition(
    reportsResponse.json?.recent_sales?.some(sale => sale.id === saleId && sale.reference === saleReference),
    'Reports summary did not include the synced sale in recent sales',
    reportsResponse
  );
  console.log('[smoke] Reports summary passed');

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
