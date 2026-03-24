import { Response } from 'express';
import pool from '../config/db';
import { AuthRequest } from '../middleware/auth';

export const pushSync = async (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;
  const { products = [], sales = [], sale_line_items = [], momo_transactions = [], credit_entries = [], staff = [] } = req.body;

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Sync Staff
    for (const s of staff) {
      await client.query(
        `INSERT INTO staff (id, merchant_id, name, role, pin_hash, is_active, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name, role = EXCLUDED.role, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at`,
        [s.id, merchantId, s.name, s.role, s.pin_hash, s.is_active, s.created_at, s.updated_at]
      );
    }

    // Sync Products
    for (const p of products) {
      await client.query(
        `INSERT INTO products (id, merchant_id, name, category, pricing_type, suggested_price, min_price, max_price, stock_quantity, low_stock_threshold, track_stock, is_service, is_active, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name, category = EXCLUDED.category, pricing_type = EXCLUDED.pricing_type, suggested_price = EXCLUDED.suggested_price, min_price = EXCLUDED.min_price, max_price = EXCLUDED.max_price, stock_quantity = EXCLUDED.stock_quantity, low_stock_threshold = EXCLUDED.low_stock_threshold, track_stock = EXCLUDED.track_stock, is_service = EXCLUDED.is_service, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at`,
        [p.id, merchantId, p.name, p.category, p.pricing_type, p.suggested_price, p.min_price, p.max_price, p.stock_quantity, p.low_stock_threshold, p.track_stock, p.is_service, p.is_active, p.created_at, p.updated_at]
      );
    }

    // Sync Sales
    for (const s of sales) {
      await client.query(
        `INSERT INTO sales (id, merchant_id, staff_id, reference, total_amount, payment_method, customer_phone, status, notes, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (id) DO UPDATE SET
         status = EXCLUDED.status, notes = EXCLUDED.notes, updated_at = EXCLUDED.updated_at`,
        [s.id, merchantId, s.staff_id, s.reference, s.total_amount, s.payment_method, s.customer_phone, s.status, s.notes, s.created_at, s.updated_at]
      );
    }

    // Sync Sale Line Items
    for (const li of sale_line_items) {
      await client.query(
        `INSERT INTO sale_line_items (id, sale_id, product_id, quantity, unit_price, original_price, final_price, discount_amount, discount_reason, price_override_by, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         ON CONFLICT (id) DO UPDATE SET
         final_price = EXCLUDED.final_price, updated_at = EXCLUDED.updated_at`,
        [li.id, li.sale_id, li.product_id, li.quantity, li.unit_price, li.original_price, li.final_price, li.discount_amount, li.discount_reason, li.price_override_by, li.created_at, li.updated_at]
      );
    }

    // Sync MoMo Transactions
    for (const m of momo_transactions) {
      await client.query(
        `INSERT INTO momo_transactions (id, merchant_id, sale_id, transaction_ref, sender_phone, amount, status, received_at, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (id) DO UPDATE SET
         sale_id = EXCLUDED.sale_id, status = EXCLUDED.status, updated_at = EXCLUDED.updated_at`,
        [m.id, merchantId, m.sale_id, m.transaction_ref, m.sender_phone, m.amount, m.status, m.received_at, m.created_at, m.updated_at]
      );
    }

    // Sync Credit Entries
    for (const c of credit_entries) {
      await client.query(
        `INSERT INTO credit_entries (id, merchant_id, sale_id, customer_name, customer_phone, amount, amount_repaid, due_date, status, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         ON CONFLICT (id) DO UPDATE SET
         amount_repaid = EXCLUDED.amount_repaid, status = EXCLUDED.status, updated_at = EXCLUDED.updated_at`,
        [c.id, merchantId, c.sale_id, c.customer_name, c.customer_phone, c.amount, c.amount_repaid, c.due_date, c.status, c.created_at, c.updated_at]
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
  const updatedAfter = req.query.updated_after as string; // ISO 8601 string

  if (!updatedAfter) {
    return res.status(400).json({ error: 'Missing updated_after query parameter' });
  }

  try {
    const products = await pool.query('SELECT * FROM products WHERE merchant_id = $1 AND updated_at > $2', [merchantId, updatedAfter]);
    const sales = await pool.query('SELECT * FROM sales WHERE merchant_id = $1 AND updated_at > $2', [merchantId, updatedAfter]);
    const staff = await pool.query('SELECT * FROM staff WHERE merchant_id = $1 AND updated_at > $2', [merchantId, updatedAfter]);
    const momo_transactions = await pool.query('SELECT * FROM momo_transactions WHERE merchant_id = $1 AND updated_at > $2', [merchantId, updatedAfter]);
    const credit_entries = await pool.query('SELECT * FROM credit_entries WHERE merchant_id = $1 AND updated_at > $2', [merchantId, updatedAfter]);

    // For line items, we need to join or match the merchant ID of parent sales, 
    // but the easiest way is querying by sale_id IN (subquery)
    const sale_line_items = await pool.query(
      `SELECT items.* FROM sale_line_items items
       JOIN sales s ON items.sale_id = s.id
       WHERE s.merchant_id = $1 AND items.updated_at > $2`,
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
