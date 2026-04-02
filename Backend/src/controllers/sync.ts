import { Response } from 'express';
import pool from '../config/db';
import { AuthRequest, normalizeStaffRole } from '../middleware/auth';

const getRequestBody = (req: AuthRequest): Record<string, unknown> => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return {};
  }

  return req.body as Record<string, unknown>;
};

const getArrayPayload = (value: unknown): Record<string, unknown>[] => {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter(item => item && typeof item === 'object' && !Array.isArray(item)) as Record<
    string,
    unknown
  >[];
};

const normalizeTimestamp = (value: unknown) => {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString();
  }

  if (typeof value !== 'string') {
    return null;
  }

  const trimmedValue = value.trim();

  if (!trimmedValue) {
    return null;
  }

  const parsedDate = new Date(trimmedValue);

  if (Number.isNaN(parsedDate.getTime())) {
    return null;
  }

  return parsedDate.toISOString();
};

const resolveTimestamps = (createdAtValue: unknown, updatedAtValue: unknown) => {
  const fallbackTimestamp = new Date().toISOString();

  return {
    createdAt: normalizeTimestamp(createdAtValue) ?? fallbackTimestamp,
    updatedAt: normalizeTimestamp(updatedAtValue) ?? fallbackTimestamp,
  };
};

const normalizeSyncedRole = (value: unknown) => {
  return normalizeStaffRole(typeof value === 'string' ? value : undefined);
};

const syncCursorColumn = (tableAlias?: string) => {
  if (!tableAlias) {
    return 'COALESCE(server_updated_at, updated_at)';
  }

  return `COALESCE(${tableAlias}.server_updated_at, ${tableAlias}.updated_at)`;
};

export const pushSync = async (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;

  if (!merchantId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const body = getRequestBody(req);
  const products = getArrayPayload(body.products);
  const sales = getArrayPayload(body.sales);
  const saleLineItems = getArrayPayload(body.sale_line_items);
  const momoTransactions = getArrayPayload(body.momo_transactions);
  const creditEntries = getArrayPayload(body.credit_entries);
  const staff = getArrayPayload(body.staff);

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Sync Staff metadata without requiring the client to hold PIN hashes.
    for (const s of staff) {
      const timestamps = resolveTimestamps(s.created_at, s.updated_at);
      const existingStaff = await client.query(
        `
          SELECT id
          FROM staff
          WHERE id = $1 AND merchant_id = $2
          LIMIT 1
        `,
        [s.id, merchantId]
      );

      if (existingStaff.rows.length > 0) {
        await client.query(
          `
            UPDATE staff
            SET
              name = $1,
              role = $2,
              is_active = $3,
              deactivated_at = CASE WHEN $3 THEN NULL ELSE COALESCE(deactivated_at, CURRENT_TIMESTAMP) END,
              updated_at = COALESCE($4, CURRENT_TIMESTAMP)
            WHERE id = $5 AND merchant_id = $6
          `,
          [
            s.name,
            normalizeSyncedRole(s.role),
            s.is_active ?? true,
            timestamps.updatedAt,
            s.id,
            merchantId,
          ]
        );
        continue;
      }

      if (!s.pin_hash) {
        continue;
      }

      await client.query(
        `
          INSERT INTO staff (
            id,
            merchant_id,
            name,
            role,
            pin_hash,
            is_active,
            created_at,
            updated_at,
            pin_updated_at,
            deactivated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, COALESCE($8, CURRENT_TIMESTAMP), CASE WHEN $6 THEN NULL ELSE COALESCE($8, CURRENT_TIMESTAMP) END)
        `,
        [
          s.id,
          merchantId,
          s.name,
          normalizeSyncedRole(s.role),
          s.pin_hash,
          s.is_active ?? true,
          timestamps.createdAt,
          timestamps.updatedAt,
        ]
      );
    }

    // Sync Products
    for (const p of products) {
      const timestamps = resolveTimestamps(p.created_at, p.updated_at);
      await client.query(
        `INSERT INTO products (id, merchant_id, name, category, pricing_type, suggested_price, min_price, max_price, stock_quantity, low_stock_threshold, track_stock, is_service, is_active, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name, category = EXCLUDED.category, pricing_type = EXCLUDED.pricing_type, suggested_price = EXCLUDED.suggested_price, min_price = EXCLUDED.min_price, max_price = EXCLUDED.max_price, stock_quantity = EXCLUDED.stock_quantity, low_stock_threshold = EXCLUDED.low_stock_threshold, track_stock = EXCLUDED.track_stock, is_service = EXCLUDED.is_service, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at`,
        [p.id, merchantId, p.name, p.category, p.pricing_type, p.suggested_price, p.min_price, p.max_price, p.stock_quantity, p.low_stock_threshold, p.track_stock, p.is_service, p.is_active, timestamps.createdAt, timestamps.updatedAt]
      );
    }

    // Sync Sales
    for (const s of sales) {
      const timestamps = resolveTimestamps(s.created_at, s.updated_at);
      await client.query(
        `INSERT INTO sales (id, merchant_id, staff_id, reference, total_amount, payment_method, customer_phone, status, notes, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (id) DO UPDATE SET
         status = EXCLUDED.status, notes = EXCLUDED.notes, updated_at = EXCLUDED.updated_at`,
        [s.id, merchantId, s.staff_id, s.reference, s.total_amount, s.payment_method, s.customer_phone, s.status, s.notes, timestamps.createdAt, timestamps.updatedAt]
      );
    }

    // Sync Sale Line Items
    for (const li of saleLineItems) {
      const timestamps = resolveTimestamps(li.created_at, li.updated_at);
      await client.query(
        `INSERT INTO sale_line_items (id, sale_id, product_id, quantity, unit_price, original_price, final_price, discount_amount, discount_reason, price_override_by, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         ON CONFLICT (id) DO UPDATE SET
         final_price = EXCLUDED.final_price, updated_at = EXCLUDED.updated_at`,
        [li.id, li.sale_id, li.product_id, li.quantity, li.unit_price, li.original_price, li.final_price, li.discount_amount, li.discount_reason, li.price_override_by, timestamps.createdAt, timestamps.updatedAt]
      );
    }

    // Sync MoMo Transactions
    for (const m of momoTransactions) {
      const timestamps = resolveTimestamps(m.created_at, m.updated_at);
      await client.query(
        `INSERT INTO momo_transactions (id, merchant_id, sale_id, transaction_ref, sender_phone, amount, status, received_at, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (id) DO UPDATE SET
         sale_id = EXCLUDED.sale_id, status = EXCLUDED.status, updated_at = EXCLUDED.updated_at`,
        [m.id, merchantId, m.sale_id, m.transaction_ref, m.sender_phone, m.amount, m.status, m.received_at, timestamps.createdAt, timestamps.updatedAt]
      );
    }

    // Sync Credit Entries
    for (const c of creditEntries) {
      const timestamps = resolveTimestamps(c.created_at, c.updated_at);
      await client.query(
        `INSERT INTO credit_entries (id, merchant_id, sale_id, customer_name, customer_phone, amount, amount_repaid, due_date, status, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (id) DO UPDATE SET
         amount_repaid = EXCLUDED.amount_repaid, status = EXCLUDED.status, updated_at = EXCLUDED.updated_at`,
        [c.id, merchantId, c.sale_id, c.customer_name, c.customer_phone, c.amount, c.amount_repaid, c.due_date, c.status, timestamps.createdAt, timestamps.updatedAt]
      );
    }

    await client.query('COMMIT');
    res.json({ success: true, message: 'Batch sync complete' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Sync push error:', error);
    res.status(500).json({ error: 'Sync failed' });
  } finally {
    client.release();
  }
};

export const pullSync = async (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;
  const updatedAfter = normalizeTimestamp(req.query.updated_after);

  if (!merchantId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  if (!updatedAfter) {
    return res.status(400).json({ error: 'updated_after must be a valid ISO 8601 timestamp' });
  }

  try {
    const products = await pool.query(
      `
        SELECT
          id,
          merchant_id,
          name,
          category,
          pricing_type,
          suggested_price,
          min_price,
          max_price,
          stock_quantity,
          low_stock_threshold,
          track_stock,
          is_service,
          is_active,
          created_at,
          updated_at
        FROM products
        WHERE merchant_id = $1 AND ${syncCursorColumn()} > $2
      `,
      [merchantId, updatedAfter]
    );
    const sales = await pool.query(
      `
        SELECT
          id,
          merchant_id,
          staff_id,
          reference,
          total_amount,
          payment_method,
          customer_phone,
          status,
          notes,
          created_at,
          updated_at
        FROM sales
        WHERE merchant_id = $1 AND ${syncCursorColumn()} > $2
      `,
      [merchantId, updatedAfter]
    );
    const staff = await pool.query(
      `
        SELECT
          id,
          merchant_id,
          name,
          role,
          is_active,
          created_at,
          updated_at,
          last_login_at,
          pin_updated_at,
          deactivated_at,
          created_by_staff_id
        FROM staff
        WHERE merchant_id = $1 AND ${syncCursorColumn()} > $2
      `,
      [merchantId, updatedAfter]
    );
    const momo_transactions = await pool.query(
      `
        SELECT
          id,
          merchant_id,
          sale_id,
          transaction_ref,
          sender_phone,
          amount,
          status,
          received_at,
          created_at,
          updated_at
        FROM momo_transactions
        WHERE merchant_id = $1 AND ${syncCursorColumn()} > $2
      `,
      [merchantId, updatedAfter]
    );
    const credit_entries = await pool.query(
      `
        SELECT
          id,
          merchant_id,
          sale_id,
          customer_name,
          customer_phone,
          amount,
          amount_repaid,
          due_date,
          status,
          created_at,
          updated_at
        FROM credit_entries
        WHERE merchant_id = $1 AND ${syncCursorColumn()} > $2
      `,
      [merchantId, updatedAfter]
    );

    // For line items, we need to join or match the merchant ID of parent sales, 
    // but the easiest way is querying by sale_id IN (subquery)
    const sale_line_items = await pool.query(
      `SELECT
         items.id,
         items.sale_id,
         items.product_id,
         items.quantity,
         items.unit_price,
         items.original_price,
         items.final_price,
         items.discount_amount,
         items.discount_reason,
         items.price_override_by,
         items.created_at,
         items.updated_at
       FROM sale_line_items items
       JOIN sales s ON items.sale_id = s.id
       WHERE s.merchant_id = $1 AND ${syncCursorColumn('items')} > $2`,
      [merchantId, updatedAfter]
    );

    res.json({
      timestamp: new Date().toISOString(),
      data: {
        products: products.rows,
        sales: sales.rows,
        sale_line_items: sale_line_items.rows,
        staff: staff.rows,
        momo_transactions: momo_transactions.rows,
        credit_entries: credit_entries.rows
      }
    });

  } catch (error) {
    console.error('Sync pull error:', error);
    res.status(500).json({ error: 'Sync pull failed' });
  }
};
