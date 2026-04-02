import assert from 'node:assert/strict';
import test from 'node:test';
import pool from '../src/config/db';
import { pullSync, pushSync } from '../src/controllers/sync';
import { createAuthRequest, createMockResponse, isIsoTimestamp, replaceMethod } from './helpers';

test('pushSync rejects unauthenticated requests before opening a database transaction', async () => {
  let connectCalls = 0;
  const restoreConnect = replaceMethod(
    pool,
    'connect',
    (async () => {
      connectCalls += 1;
      throw new Error('connect should not be called');
    }) as unknown as typeof pool.connect
  );

  try {
    const { res, state } = createMockResponse();

    await pushSync(
      createAuthRequest({
        body: {
          staff: [],
        },
      }),
      res
    );

    assert.equal(state.statusCode, 401);
    assert.deepEqual(state.body, { error: 'Unauthorized' });
    assert.equal(connectCalls, 0);
  } finally {
    restoreConnect();
  }
});

test('pullSync validates updated_after before running sync queries', async () => {
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
      merchant: {
        id: 'merchant-1',
        companyCode: 'VND-MERCHANT',
      },
      query: {
        updated_after: 'not-a-timestamp',
      },
    });
    const { res, state } = createMockResponse();

    await pullSync(req, res);

    assert.equal(state.statusCode, 400);
    assert.deepEqual(state.body, {
      error: 'updated_after must be a valid ISO 8601 timestamp',
    });
    assert.equal(queryCalls, 0);
  } finally {
    restoreQuery();
  }
});

test('pullSync uses the server sync cursor while keeping the response columns stable', async () => {
  const recordedQueries: Array<{ text: string; values?: unknown[] }> = [];
  const restoreQuery = replaceMethod(
    pool,
    'query',
    (async (text: string, values?: unknown[]) => {
      recordedQueries.push({ text, values });
      return { rows: [] };
    }) as unknown as typeof pool.query
  );

  try {
    const req = createAuthRequest({
      merchant: {
        id: 'merchant-1',
        companyCode: 'VND-MERCHANT',
      },
      query: {
        updated_after: '2026-04-01T00:00:00.000Z',
      },
    });
    const { res, state } = createMockResponse();

    await pullSync(req, res);

    assert.equal(state.statusCode, 200);
    assert.equal(recordedQueries.length, 6);
    assert.ok(recordedQueries.every(entry => entry.values?.[1] === '2026-04-01T00:00:00.000Z'));
    assert.ok(
      recordedQueries.every(entry => entry.text.includes('server_updated_at') || entry.text.includes('items.server_updated_at'))
    );
    assert.ok(recordedQueries.every(entry => !/\bSELECT\s+\*/i.test(entry.text)));
  } finally {
    restoreQuery();
  }
});

test('pullSync normalizes updated_after once and reuses the same cursor across sync queries', async () => {
  const recordedQueries: Array<{ text: string; values?: unknown[] }> = [];
  const expectedCursor = '2026-04-01T10:15:30.000Z';
  const restoreQuery = replaceMethod(
    pool,
    'query',
    (async (text: string, values?: unknown[]) => {
      recordedQueries.push({ text, values });

      if (text.includes('FROM products')) {
        return { rows: [{ id: 'product-1' }] };
      }

      if (text.includes('FROM sales') && !text.includes('JOIN sales')) {
        return { rows: [{ id: 'sale-1' }] };
      }

      if (text.includes('FROM staff')) {
        return { rows: [{ id: 'staff-1' }] };
      }

      if (text.includes('FROM momo_transactions')) {
        return { rows: [{ id: 'momo-1' }] };
      }

      if (text.includes('FROM credit_entries')) {
        return { rows: [{ id: 'credit-1' }] };
      }

      if (text.includes('FROM sale_line_items')) {
        return { rows: [{ id: 'line-item-1' }] };
      }

      return { rows: [] };
    }) as unknown as typeof pool.query
  );

  try {
    const req = createAuthRequest({
      merchant: {
        id: 'merchant-1',
        companyCode: 'VND-MERCHANT',
      },
      query: {
        updated_after: ' 2026-04-01T12:15:30+02:00 ',
      },
    });
    const { res, state } = createMockResponse();

    await pullSync(req, res);

    assert.equal(state.statusCode, 200);
    assert.equal(recordedQueries.length, 6);

    for (const entry of recordedQueries) {
      assert.deepEqual(entry.values, ['merchant-1', expectedCursor]);
    }

    const body = state.body as {
      timestamp: unknown;
      data: {
        products: Array<{ id: string }>;
        sales: Array<{ id: string }>;
        sale_line_items: Array<{ id: string }>;
        staff: Array<{ id: string }>;
        momo_transactions: Array<{ id: string }>;
        credit_entries: Array<{ id: string }>;
      };
    };

    assert.ok(isIsoTimestamp(body.timestamp));
    assert.deepEqual(body.data, {
      products: [{ id: 'product-1' }],
      sales: [{ id: 'sale-1' }],
      sale_line_items: [{ id: 'line-item-1' }],
      staff: [{ id: 'staff-1' }],
      momo_transactions: [{ id: 'momo-1' }],
      credit_entries: [{ id: 'credit-1' }],
    });
  } finally {
    restoreQuery();
  }
});

test('pushSync normalizes synced staff role and timestamps for new staff rows', async () => {
  const recordedQueries: Array<{ text: string; values?: unknown[] }> = [];
  let released = false;

  const client = {
    query: async (text: string, values?: unknown[]) => {
      recordedQueries.push({ text, values });

      if (text.includes('SELECT id') && text.includes('FROM staff')) {
        return { rows: [] };
      }

      return { rows: [] };
    },
    release: () => {
      released = true;
    },
  };

  const restoreConnect = replaceMethod(
    pool,
    'connect',
    (async () => client) as unknown as typeof pool.connect
  );

  try {
    const req = createAuthRequest({
      merchant: {
        id: 'merchant-1',
        companyCode: 'VND-MERCHANT',
      },
      body: {
        staff: [
          {
            id: 'staff-1',
            name: 'Owner Jane',
            role: 'owner',
            pin_hash: 'hashed-pin',
            is_active: false,
            created_at: 'invalid-date',
            updated_at: '   ',
          },
        ],
        products: 'not-an-array',
      },
    });
    const { res, state } = createMockResponse();

    await pushSync(req, res);

    const staffInsert = recordedQueries.find(entry => entry.text.includes('INSERT INTO staff'));

    assert.ok(staffInsert);
    assert.equal(state.statusCode, 200);
    assert.deepEqual(state.body, { success: true, message: 'Batch sync complete' });
    assert.equal(staffInsert?.values?.[3], 'admin');
    assert.equal(staffInsert?.values?.[5], false);
    assert.ok(isIsoTimestamp(staffInsert?.values?.[6]));
    assert.ok(isIsoTimestamp(staffInsert?.values?.[7]));
    assert.equal(released, true);
  } finally {
    restoreConnect();
  }
});

test('pushSync preserves client updated_at while leaving propagation recency to the server cursor', async () => {
  const recordedQueries: Array<{ text: string; values?: unknown[] }> = [];
  let released = false;
  const staleUpdatedAt = '2024-01-15T08:30:00.000Z';

  const client = {
    query: async (text: string, values?: unknown[]) => {
      recordedQueries.push({ text, values });
      return { rows: [] };
    },
    release: () => {
      released = true;
    },
  };

  const restoreConnect = replaceMethod(
    pool,
    'connect',
    (async () => client) as unknown as typeof pool.connect
  );

  try {
    const req = createAuthRequest({
      merchant: {
        id: 'merchant-1',
        companyCode: 'VND-MERCHANT',
      },
      body: {
        products: [
          {
            id: 'product-1',
            name: 'Late Upload Product',
            category: 'General',
            pricing_type: 'fixed',
            suggested_price: 12.5,
            min_price: 10,
            max_price: 15,
            stock_quantity: 3,
            low_stock_threshold: 1,
            track_stock: true,
            is_service: false,
            is_active: true,
            created_at: '2024-01-10T08:30:00.000Z',
            updated_at: staleUpdatedAt,
          },
        ],
      },
    });
    const { res, state } = createMockResponse();

    await pushSync(req, res);

    const productUpsert = recordedQueries.find(entry => entry.text.includes('INSERT INTO products'));

    assert.ok(productUpsert);
    assert.equal(state.statusCode, 200);
    assert.deepEqual(state.body, { success: true, message: 'Batch sync complete' });
    assert.equal(productUpsert?.values?.[14], staleUpdatedAt);
    assert.ok(!productUpsert?.text.includes('server_updated_at'));
    assert.equal(released, true);
  } finally {
    restoreConnect();
  }
});
