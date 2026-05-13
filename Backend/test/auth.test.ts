import assert from 'node:assert/strict';
import test from 'node:test';
import type { Request } from 'express';
import jwt from 'jsonwebtoken';
import { registerMerchant } from '../src/controllers/auth';
import pool from '../src/config/db';
import { resetRuntimeConfigCache } from '../src/config/env';
import { authenticateJWT } from '../src/middleware/auth';
import { createAuthRequest, createMockResponse, replaceMethod } from './helpers';

const TEST_JWT_SECRET = 'backend-test-secret';
const TEST_DATABASE_URL = 'postgres://venda_user:venda_pass_2026@localhost:5432/venda_test';

process.env.JWT_SECRET = TEST_JWT_SECRET;
process.env.DATABASE_URL = TEST_DATABASE_URL;
resetRuntimeConfigCache();

test('registerMerchant returns 400 when the request body is not an object', async () => {
  let queryCalls = 0;
  const restoreQuery = replaceMethod(
    pool,
    'query',
    (async () => {
      queryCalls += 1;
      return { rows: [] };
    }) as unknown as typeof pool.query
  );

  try {
    const { res, state } = createMockResponse();

    await registerMerchant({ body: null } as Request, res);

    assert.equal(state.statusCode, 400);
    assert.deepEqual(state.body, { error: 'Missing required fields' });
    assert.equal(queryCalls, 0);
  } finally {
    restoreQuery();
  }
});

test('authenticateJWT allows merchant sessions to fall back to token staff claims when the live staff row is missing', async () => {
  const token = jwt.sign(
    {
      merchantId: 'merchant-1',
      companyCode: 'VND-MERCHANT',
      authType: 'merchant',
      staffId: 'staff-1',
      staffName: 'Owner Jane',
      role: 'owner',
    },
    TEST_JWT_SECRET
  );
  const restoreQuery = replaceMethod(
    pool,
    'query',
    (async () => ({ rows: [] })) as unknown as typeof pool.query
  );

  try {
    const req = createAuthRequest({
      headers: {
        authorization: `Bearer ${token}`,
      },
    });
    const { res, state } = createMockResponse();
    let nextCalls = 0;

    await authenticateJWT(req, res, () => {
      nextCalls += 1;
    });

    assert.equal(nextCalls, 1);
    assert.equal(state.statusCode, 200);
    assert.equal(req.authType, 'merchant');
    assert.deepEqual(req.merchant, {
      id: 'merchant-1',
      phone: undefined,
      companyCode: 'VND-MERCHANT',
    });
    assert.deepEqual(req.staff, {
      id: 'staff-1',
      merchantId: 'merchant-1',
      name: 'Owner Jane',
      role: 'admin',
      companyCode: 'VND-MERCHANT',
    });
  } finally {
    restoreQuery();
  }
});

test('authenticateJWT rejects staff sessions when the staff row is missing', async () => {
  const token = jwt.sign(
    {
      merchantId: 'merchant-1',
      companyCode: 'VND-MERCHANT',
      authType: 'staff',
      staffId: 'staff-2',
      staffName: 'Cashier Joe',
      role: 'cashier',
    },
    TEST_JWT_SECRET
  );
  const restoreQuery = replaceMethod(
    pool,
    'query',
    (async () => ({ rows: [] })) as unknown as typeof pool.query
  );

  try {
    const req = createAuthRequest({
      headers: {
        authorization: `Bearer ${token}`,
      },
    });
    const { res, state } = createMockResponse();
    let nextCalls = 0;

    await authenticateJWT(req, res, () => {
      nextCalls += 1;
    });

    assert.equal(nextCalls, 0);
    assert.equal(state.statusCode, 403);
    assert.deepEqual(state.body, { error: 'Staff account is inactive' });
  } finally {
    restoreQuery();
  }
});

test('authenticateJWT accepts tokens signed with a configured previous JWT secret', async () => {
  const previousSecret = 'backend-previous-test-secret';
  process.env.JWT_SECRET_PREVIOUS = previousSecret;
  resetRuntimeConfigCache();
  const token = jwt.sign(
    {
      merchantId: 'merchant-1',
      companyCode: 'VND-MERCHANT',
      authType: 'merchant',
      staffId: 'staff-admin',
      staffName: 'Recovered Admin',
      role: 'admin',
    },
    previousSecret
  );

  const restoreQuery = replaceMethod(
    pool,
    'query',
    (async () => ({ rows: [] })) as unknown as typeof pool.query
  );

  try {
    const req = createAuthRequest({
      headers: {
        authorization: `Bearer ${token}`,
      },
    });
    const { res, state } = createMockResponse();
    let nextCalled = false;

    await authenticateJWT(req, res, () => {
      nextCalled = true;
    });

    assert.equal(nextCalled, true);
    assert.equal(state.statusCode, 200);
    assert.equal(req.merchant?.id, 'merchant-1');
    assert.equal(req.staff?.role, 'admin');
  } finally {
    delete process.env.JWT_SECRET_PREVIOUS;
    resetRuntimeConfigCache();
    restoreQuery();
  }
});
