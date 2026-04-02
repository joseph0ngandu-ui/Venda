import assert from 'node:assert/strict';
import test from 'node:test';
import type { Request } from 'express';
import pool from '../src/config/db';
import { updateStaff } from '../src/controllers/staff';
import { createAuthRequest, createMockResponse, replaceMethod } from './helpers';

const adminContext = {
  merchant: {
    id: 'merchant-1',
    companyCode: 'VND-MERCHANT',
  },
  staff: {
    id: 'staff-admin',
    merchantId: 'merchant-1',
    name: 'Admin User',
    role: 'admin' as const,
    companyCode: 'VND-MERCHANT',
  },
};

test('updateStaff rejects invalid is_active values before touching the database', async () => {
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
    const req = createAuthRequest({
      ...adminContext,
      params: { staffId: 'staff-target' },
      body: { is_active: 'maybe' },
    });
    const { res, state } = createMockResponse();

    await updateStaff(req as unknown as Request, res);

    assert.equal(state.statusCode, 400);
    assert.deepEqual(state.body, {
      error: 'Invalid is_active value. Use true or false.',
    });
    assert.equal(queryCalls, 0);
  } finally {
    restoreQuery();
  }
});

test('updateStaff treats non-object bodies as empty updates instead of throwing', async () => {
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
    const req = createAuthRequest({
      ...adminContext,
      params: { staffId: 'staff-target' },
      body: [],
    });
    const { res, state } = createMockResponse();

    await updateStaff(req as unknown as Request, res);

    assert.equal(state.statusCode, 400);
    assert.deepEqual(state.body, { error: 'No staff updates were provided' });
    assert.equal(queryCalls, 0);
  } finally {
    restoreQuery();
  }
});
