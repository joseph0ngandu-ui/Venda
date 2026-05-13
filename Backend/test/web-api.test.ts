import assert from 'node:assert/strict';
import test from 'node:test';
import pool from '../src/config/db';
import { createProduct } from '../src/controllers/products';
import { createSale } from '../src/controllers/sales';
import { recordCreditRepayment } from '../src/controllers/money';
import { createAuthRequest, createMockResponse, replaceMethod } from './helpers';

const merchantContext = {
  merchant: {
    id: 'merchant-1',
    companyCode: 'VND-MERCHANT',
  },
  staff: {
    id: 'staff-1',
    merchantId: 'merchant-1',
    name: 'Cashier Jane',
    role: 'cashier' as const,
    companyCode: 'VND-MERCHANT',
  },
};

test('createProduct validates range pricing before inserting', async () => {
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
      ...merchantContext,
      body: {
        name: 'Premium Braids',
        pricing_type: 'range',
        min_price: 250,
        max_price: 100,
      },
    });
    const { res, state } = createMockResponse();

    await createProduct(req, res);

    assert.equal(state.statusCode, 400);
    assert.deepEqual(state.body, { error: 'Minimum price must be less than or equal to maximum price' });
    assert.equal(queryCalls, 0);
  } finally {
    restoreQuery();
  }
});

test('createSale rejects empty carts before opening a transaction', async () => {
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
    const req = createAuthRequest({
      ...merchantContext,
      body: {
        items: [],
      },
    });
    const { res, state } = createMockResponse();

    await createSale(req, res);

    assert.equal(state.statusCode, 400);
    assert.deepEqual(state.body, { error: 'At least one sale item is required' });
    assert.equal(connectCalls, 0);
  } finally {
    restoreConnect();
  }
});

test('createSale writes sale line items and decrements tracked stock in one transaction', async () => {
  const recordedQueries: Array<{ text: string; values?: unknown[] }> = [];
  let released = false;

  const client = {
    query: async (text: string, values?: unknown[]) => {
      recordedQueries.push({ text, values });

      if (text.includes('FROM products') && text.includes('FOR UPDATE')) {
        return {
          rows: [
            {
              id: 'product-1',
              name: 'Haircut',
              suggested_price: '150',
              stock_quantity: 8,
              track_stock: true,
              is_service: false,
              is_active: true,
            },
          ],
        };
      }

      if (text.includes('INSERT INTO sales')) {
        return {
          rows: [
            {
              id: 'sale-1',
              merchant_id: 'merchant-1',
              staff_id: 'staff-1',
              reference: values?.[3],
              total_amount: values?.[4],
              payment_method: values?.[5],
              customer_phone: values?.[6],
              status: 'completed',
              notes: values?.[7],
              created_at: '2026-05-14T08:00:00.000Z',
              updated_at: '2026-05-14T08:00:00.000Z',
            },
          ],
        };
      }

      if (text.includes('INSERT INTO sale_line_items')) {
        return {
          rows: [
            {
              id: 'line-1',
              sale_id: values?.[1],
              product_id: values?.[2],
              quantity: values?.[3],
              unit_price: values?.[4],
              original_price: values?.[5],
              final_price: values?.[6],
              discount_amount: values?.[7],
              discount_reason: values?.[8],
              price_override_by: values?.[9],
              created_at: '2026-05-14T08:00:00.000Z',
              updated_at: '2026-05-14T08:00:00.000Z',
            },
          ],
        };
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
      ...merchantContext,
      body: {
        payment_method: 'Cash',
        items: [
          {
            product_id: 'product-1',
            quantity: 2,
            final_price: 140,
          },
        ],
      },
    });
    const { res, state } = createMockResponse();

    await createSale(req, res);

    const saleInsert = recordedQueries.find(entry => entry.text.includes('INSERT INTO sales'));
    const stockUpdate = recordedQueries.find(entry => entry.text.includes('SET stock_quantity'));

    assert.equal(state.statusCode, 201);
    assert.equal((state.body as { sale: { total_amount: number } }).sale.total_amount, 280);
    assert.equal(saleInsert?.values?.[4], 280);
    assert.deepEqual(stockUpdate?.values, [2, 'product-1', 'merchant-1']);
    assert.equal(recordedQueries[0].text, 'BEGIN');
    assert.equal(recordedQueries[recordedQueries.length - 1]?.text, 'COMMIT');
    assert.equal(released, true);
  } finally {
    restoreConnect();
  }
});

test('recordCreditRepayment validates positive repayment amounts before updating', async () => {
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
      ...merchantContext,
      params: { creditId: 'credit-1' },
      body: { amount: 0 },
    });
    const { res, state } = createMockResponse();

    await recordCreditRepayment(req, res);

    assert.equal(state.statusCode, 400);
    assert.deepEqual(state.body, { error: 'Repayment amount is required' });
    assert.equal(queryCalls, 0);
  } finally {
    restoreQuery();
  }
});
