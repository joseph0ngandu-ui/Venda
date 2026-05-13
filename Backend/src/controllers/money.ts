import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/db';
import { AuthRequest } from '../middleware/auth';

type MoneyMetricRow = {
  matched_momo: string | number | null;
  pending_momo: string | number | null;
  unmatched_momo: string | number | null;
  outstanding_credit: string | number | null;
  open_credit_customers: number | null;
};

type MoMoTransactionRow = {
  id: string;
  merchant_id: string;
  sale_id: string | null;
  transaction_ref: string;
  sender_phone: string;
  amount: string | number;
  status: string | null;
  received_at: Date | string;
  created_at: Date | string;
  updated_at: Date | string;
};

type CreditEntryRow = {
  id: string;
  merchant_id: string;
  sale_id: string | null;
  customer_name: string;
  customer_phone: string | null;
  amount: string | number;
  amount_repaid: string | number | null;
  due_date: Date | string | null;
  status: string | null;
  created_at: Date | string;
  updated_at: Date | string;
};

const MOMO_STATUSES = new Set(['pending', 'matched', 'unmatched']);

const getRequestBody = (req: Request): Record<string, unknown> => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return {};
  }

  return req.body as Record<string, unknown>;
};

const normalizeText = (value: unknown) => {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim();
};

const parsePositiveNumber = (value: unknown) => {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) && numberValue > 0 ? numberValue : null;
};

const parseOptionalDate = (value: unknown) => {
  if (value === undefined || value === null || value === '') {
    return null;
  }

  const date = new Date(String(value));
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
};

const toIsoString = (value: Date | string | null | undefined) => {
  if (!value) {
    return null;
  }

  return new Date(value).toISOString();
};

const serializeMoMo = (row: MoMoTransactionRow) => ({
  id: row.id,
  merchant_id: row.merchant_id,
  sale_id: row.sale_id,
  transaction_ref: row.transaction_ref,
  sender_phone: row.sender_phone,
  amount: Number(row.amount),
  status: row.status ?? 'pending',
  received_at: toIsoString(row.received_at),
  created_at: toIsoString(row.created_at),
  updated_at: toIsoString(row.updated_at),
});

const serializeCreditEntry = (row: CreditEntryRow) => {
  const amount = Number(row.amount);
  const amountRepaid = Number(row.amount_repaid ?? 0);

  return {
    id: row.id,
    merchant_id: row.merchant_id,
    sale_id: row.sale_id,
    customer_name: row.customer_name,
    customer_phone: row.customer_phone,
    amount,
    amount_repaid: amountRepaid,
    amount_owed: Math.max(0, amount - amountRepaid),
    due_date: toIsoString(row.due_date),
    status: row.status ?? 'outstanding',
    created_at: toIsoString(row.created_at),
    updated_at: toIsoString(row.updated_at),
  };
};

const ensureMerchant = (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;

  if (!merchantId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }

  return merchantId;
};

const getRouteId = (req: Request, paramName: string) => {
  const rawValue = req.params[paramName];
  return Array.isArray(rawValue) ? rawValue[0] ?? '' : rawValue ?? '';
};

const normalizeMoMoStatus = (value: unknown, fallback = 'pending') => {
  const normalized = normalizeText(value).toLowerCase();
  return MOMO_STATUSES.has(normalized) ? normalized : fallback;
};

export const getMoneySummary = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  try {
    const [metricsResult, momoResult, creditResult] = await Promise.all([
      pool.query<MoneyMetricRow>(
        `
          SELECT
            COALESCE(SUM(amount) FILTER (WHERE status = 'matched'), 0) AS matched_momo,
            COALESCE(SUM(amount) FILTER (WHERE status = 'pending'), 0) AS pending_momo,
            COALESCE(SUM(amount) FILTER (WHERE status = 'unmatched'), 0) AS unmatched_momo,
            (
              SELECT COALESCE(SUM(GREATEST(amount - amount_repaid, 0)), 0)
              FROM credit_entries
              WHERE merchant_id = $1
                AND status <> 'paid'
            ) AS outstanding_credit,
            (
              SELECT COUNT(DISTINCT customer_name)::int
              FROM credit_entries
              WHERE merchant_id = $1
                AND status <> 'paid'
            ) AS open_credit_customers
          FROM momo_transactions
          WHERE merchant_id = $1
        `,
        [merchantId]
      ),
      pool.query<MoMoTransactionRow>(
        `
          SELECT *
          FROM momo_transactions
          WHERE merchant_id = $1
          ORDER BY received_at DESC, created_at DESC
          LIMIT 30
        `,
        [merchantId]
      ),
      pool.query<CreditEntryRow>(
        `
          SELECT *
          FROM credit_entries
          WHERE merchant_id = $1
          ORDER BY created_at DESC
          LIMIT 30
        `,
        [merchantId]
      ),
    ]);

    const metrics = metricsResult.rows[0] ?? {
      matched_momo: 0,
      pending_momo: 0,
      unmatched_momo: 0,
      outstanding_credit: 0,
      open_credit_customers: 0,
    };

    res.json({
      summary: {
        matched_momo: Number(metrics.matched_momo ?? 0),
        pending_momo: Number(metrics.pending_momo ?? 0),
        unmatched_momo: Number(metrics.unmatched_momo ?? 0),
        outstanding_credit: Number(metrics.outstanding_credit ?? 0),
        open_credit_customers: Number(metrics.open_credit_customers ?? 0),
      },
      momo_transactions: momoResult.rows.map(serializeMoMo),
      credit_entries: creditResult.rows.map(serializeCreditEntry),
    });
  } catch (error) {
    console.error('Money summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createMoMoTransaction = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const body = getRequestBody(req);
  const transactionRef = normalizeText(body.transaction_ref ?? body.reference);
  const senderPhone = normalizeText(body.sender_phone ?? body.phone);
  const amount = parsePositiveNumber(body.amount);
  const status = normalizeMoMoStatus(body.status);
  const receivedAt = parseOptionalDate(body.received_at) ?? new Date().toISOString();

  if (!transactionRef || !senderPhone || amount === null) {
    return res.status(400).json({ error: 'Transaction reference, sender phone, and amount are required' });
  }

  try {
    const result = await pool.query<MoMoTransactionRow>(
      `
        INSERT INTO momo_transactions (
          id,
          merchant_id,
          sale_id,
          transaction_ref,
          sender_phone,
          amount,
          status,
          received_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *
      `,
      [uuidv4(), merchantId, normalizeText(body.sale_id) || null, transactionRef, senderPhone, amount, status, receivedAt]
    );

    res.status(201).json({
      message: 'Mobile money transaction created successfully',
      momo_transaction: serializeMoMo(result.rows[0]),
    });
  } catch (error) {
    console.error('Create MoMo error:', error);

    if (error instanceof Error && error.message.includes('momo_transactions_merchant_id_transaction_ref_key')) {
      return res.status(409).json({ error: 'Transaction reference already exists' });
    }

    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateMoMoTransaction = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const momoId = getRouteId(req, 'momoId');
  const body = getRequestBody(req);
  const status = normalizeMoMoStatus(body.status);
  const saleId = normalizeText(body.sale_id) || null;

  try {
    const result = await pool.query<MoMoTransactionRow>(
      `
        UPDATE momo_transactions
        SET
          status = $1,
          sale_id = $2
        WHERE id = $3 AND merchant_id = $4
        RETURNING *
      `,
      [status, saleId, momoId, merchantId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Mobile money transaction not found' });
    }

    res.json({
      message: 'Mobile money transaction updated successfully',
      momo_transaction: serializeMoMo(result.rows[0]),
    });
  } catch (error) {
    console.error('Update MoMo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const matchMoMoTransaction = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const momoId = getRouteId(req, 'momoId');
  const saleId = normalizeText(getRequestBody(req).sale_id);

  if (!saleId) {
    return res.status(400).json({ error: 'Sale id is required' });
  }

  try {
    const result = await pool.query<MoMoTransactionRow>(
      `
        UPDATE momo_transactions m
        SET
          sale_id = s.id,
          status = 'matched'
        FROM sales s
        WHERE m.id = $1
          AND m.merchant_id = $2
          AND s.id = $3
          AND s.merchant_id = $2
        RETURNING m.*
      `,
      [momoId, merchantId, saleId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Matching transaction or sale was not found' });
    }

    res.json({
      message: 'Mobile money transaction matched successfully',
      momo_transaction: serializeMoMo(result.rows[0]),
    });
  } catch (error) {
    console.error('Match MoMo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createCreditEntry = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const body = getRequestBody(req);
  const customerName = normalizeText(body.customer_name ?? body.customerName);
  const customerPhone = normalizeText(body.customer_phone ?? body.customerPhone) || null;
  const amount = parsePositiveNumber(body.amount);
  const dueDate = parseOptionalDate(body.due_date ?? body.dueDate);
  const saleId = normalizeText(body.sale_id ?? body.saleId) || null;

  if (!customerName || amount === null) {
    return res.status(400).json({ error: 'Customer name and amount are required' });
  }

  try {
    const result = await pool.query<CreditEntryRow>(
      `
        INSERT INTO credit_entries (
          id,
          merchant_id,
          sale_id,
          customer_name,
          customer_phone,
          amount,
          amount_repaid,
          due_date,
          status
        )
        VALUES ($1, $2, $3, $4, $5, $6, 0, $7, 'outstanding')
        RETURNING *
      `,
      [uuidv4(), merchantId, saleId, customerName, customerPhone, amount, dueDate]
    );

    res.status(201).json({
      message: 'Credit entry created successfully',
      credit_entry: serializeCreditEntry(result.rows[0]),
    });
  } catch (error) {
    console.error('Create credit entry error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const recordCreditRepayment = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const creditId = getRouteId(req, 'creditId');
  const amount = parsePositiveNumber(getRequestBody(req).amount);

  if (amount === null) {
    return res.status(400).json({ error: 'Repayment amount is required' });
  }

  try {
    const result = await pool.query<CreditEntryRow>(
      `
        UPDATE credit_entries
        SET
          amount_repaid = LEAST(amount, COALESCE(amount_repaid, 0) + $1),
          status = CASE
            WHEN LEAST(amount, COALESCE(amount_repaid, 0) + $1) >= amount THEN 'paid'
            WHEN LEAST(amount, COALESCE(amount_repaid, 0) + $1) > 0 THEN 'partial'
            ELSE 'outstanding'
          END
        WHERE id = $2 AND merchant_id = $3
        RETURNING *
      `,
      [amount, creditId, merchantId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Credit entry not found' });
    }

    res.json({
      message: 'Credit repayment recorded successfully',
      credit_entry: serializeCreditEntry(result.rows[0]),
    });
  } catch (error) {
    console.error('Record credit repayment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
