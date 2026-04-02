import assert from 'node:assert/strict';
import test from 'node:test';
import {
  getPort,
  isCorsOriginAllowed,
  resetRuntimeConfigCache,
  validateRuntimeConfig,
} from '../src/config/env';

const RUNTIME_ENV_KEYS = [
  'CORS_ALLOWED_ORIGINS',
  'CORS_ALLOW_DEV_ORIGINS',
  'CORS_ALLOW_NO_ORIGIN',
  'DATABASE_URL',
  'JWT_SECRET',
  'NODE_ENV',
  'PORT',
] as const;

const withRuntimeEnv = <T>(overrides: Partial<Record<(typeof RUNTIME_ENV_KEYS)[number], string>>, fn: () => T) => {
  const previousValues = new Map<string, string | undefined>();

  for (const key of RUNTIME_ENV_KEYS) {
    previousValues.set(key, process.env[key]);
    delete process.env[key];
  }

  for (const [key, value] of Object.entries(overrides)) {
    if (typeof value === 'string') {
      process.env[key] = value;
    }
  }

  resetRuntimeConfigCache();

  try {
    return fn();
  } finally {
    for (const key of RUNTIME_ENV_KEYS) {
      const previousValue = previousValues.get(key);

      if (typeof previousValue === 'string') {
        process.env[key] = previousValue;
      } else {
        delete process.env[key];
      }
    }

    resetRuntimeConfigCache();
  }
};

const validBaseEnv = {
  DATABASE_URL: 'postgres://venda_user:venda_pass_2026@localhost:5432/venda',
  JWT_SECRET: 'test-runtime-secret',
} as const;

test('runtime config allows localhost browser origins by default outside production', () => {
  withRuntimeEnv(validBaseEnv, () => {
    validateRuntimeConfig();

    assert.equal(getPort(), 3000);
    assert.equal(isCorsOriginAllowed(undefined), true);
    assert.equal(isCorsOriginAllowed('http://localhost:5173'), true);
    assert.equal(isCorsOriginAllowed('https://127.0.0.1:8443'), true);
    assert.equal(isCorsOriginAllowed('http://[::1]:3000'), true);
    assert.equal(isCorsOriginAllowed('https://example.com'), false);
  });
});

test('runtime config requires explicit browser origins in production by default', () => {
  withRuntimeEnv(
    {
      ...validBaseEnv,
      NODE_ENV: 'production',
      CORS_ALLOWED_ORIGINS: 'https://admin.venda.test, https://pos.venda.test/',
      CORS_ALLOW_NO_ORIGIN: 'false',
      PORT: '3100',
    },
    () => {
      validateRuntimeConfig();

      assert.equal(getPort(), 3100);
      assert.equal(isCorsOriginAllowed('https://admin.venda.test'), true);
      assert.equal(isCorsOriginAllowed('https://pos.venda.test'), true);
      assert.equal(isCorsOriginAllowed('http://localhost:5173'), false);
      assert.equal(isCorsOriginAllowed(undefined), false);
    }
  );
});

test('runtime config rejects invalid CORS origin entries during startup validation', () => {
  withRuntimeEnv(
    {
      ...validBaseEnv,
      CORS_ALLOWED_ORIGINS: 'https://admin.venda.test/app,*',
    },
    () => {
      assert.throws(() => validateRuntimeConfig(), /CORS_ALLOWED_ORIGINS/);
    }
  );
});

test('runtime config rejects invalid port values during startup validation', () => {
  withRuntimeEnv(
    {
      ...validBaseEnv,
      PORT: '70000',
    },
    () => {
      assert.throws(() => validateRuntimeConfig(), /PORT must be an integer between 1 and 65535/);
    }
  );
});
