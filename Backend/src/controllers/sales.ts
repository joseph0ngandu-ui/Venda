import { Request, Response } from 'express';
import { PoolClient } from 'pg';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/db';
import { AuthRequest } from '../middleware/auth';

type SaleRow = {
  id: string;
  merchant_id: string;
  staff_id: string | null;
  reference: string;
  total_amount: string | number;
  payment_method: string;
  customer_phone: string | null;
  status: string | null;
  notes: string | null;
  created_at: Date | string;
  updated_at: Date | string;
  staff_name?: string | null;
};

type SaleLineItemRow = {
  id: string;
  sale_id: string;
  product_id: string | null;
  product_name?: string | null;
  quantity: string | number;
  unit_price: string | number;
  original_price: string | number | null;
  final_price: string | number;
  discount_amount: string | number | null;
  discount_reason: string | null;
  price_override_by: string | null;
  created_at: Date | string;
  updated_at: Date | string;
};

type ProductForSaleRow = {
  id: string;
  name: string;
  suggested_price: string | number | null;
  stock_quantity: number | null;
  track_stock: boolean | null;
  is_service: boolean | null;
  is_active: boolean | null;
};

type SubmittedLineItem = {
  productId: string | null;
  quantity: number;
  unitPrice: number;
  originalPrice: number | null;
  finalPrice: number;
  discountAmount: number;
  discountReason: string | null;
  priceOverrideBy: string | null;
};

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

const parseMoney = (value: unknown) => {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) && numberValue >= 0 ? numberValue : null;
};

const toIsoString = (value: Date | string | null | undefined) => {
  if (!value) {
    return new Date().toISOString();
  }

  return new Date(value).toISOString();
};

const generateSaleReference = () => {
  return `VND-${uuidv4().replace(/-/g, '').slice(0, 8).toUpperCase()}`;
};

const serializeLineItem = (row: SaleLineItemRow) => ({
  id: row.id,
  sale_id: row.sale_id,
  product_id: row.product_id,
  product_name: row.product_name ?? null,
  quantity: Number(row.quantity),
  unit_price: Number(row.unit_price),
  original_price: row.original_price === null ? null : Number(row.original_price),
  final_price: Number(row.final_price),
  discount_amount: Number(row.discount_amount ?? 0),
  discount_reason: row.discount_reason,
  price_override_by: row.price_override_by,
  created_at: toIsoString(row.created_at),
  updated_at: toIsoString(row.updated_at),
});

const serializeSale = (row: SaleRow, lineItems: SaleLineItemRow[] = []) => ({
  id: row.id,
  merchant_id: row.merchant_id,
  staff_id: row.staff_id,
  staff_name: row.staff_name ?? 'Staff',
  reference: row.reference,
  total_amount: Number(row.total_amount),
  payment_method: row.payment_method,
  customer_phone: row.customer_phone,
  status: row.status ?? 'completed',
  notes: row.notes,
  created_at: toIsoString(row.created_at),
  updated_at: toIsoString(row.updated_at),
  line_items: lineItems.map(serializeLineItem),
});

const ensureMerchant = (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;

  if (!merchantId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }

  return merchantId;
};

const getSubmittedItems = (body: Record<string, unknown>) => {
  const rawItems = body.items ?? body.line_items;

  if (!Array.isArray(rawItems)) {
    return [];
  }

  return rawItems.filter(item => item && typeof item === 'object' && !Array.isArray(item)) as Record<
    string,
    unknown
  >[];
};

const normalizeSubmittedItem = (
  rawItem: Record<string, unknown>,
  product: ProductForSaleRow | null
): SubmittedLineItem | null => {
  const productId = normalizeText(rawItem.product_id ?? rawItem.productId) || null;
  const quantity = parsePositiveNumber(rawItem.quantity);
  const explicitFinalPrice = parseMoney(rawItem.final_price ?? rawItem.finalPrice);
  const explicitUnitPrice = parseMoney(rawItem.unit_price ?? rawItem.unitPrice);
  const productSuggestedPrice =
    product?.suggested_price === null || product?.suggested_price === undefined
      ? null
      : Number(product.suggested_price);
  const finalPrice = explicitFinalPrice ?? explicitUnitPrice ?? productSuggestedPrice;

  if (!quantity || finalPrice === null) {
    return null;
  }

  const unitPrice = explicitUnitPrice ?? finalPrice;
  const originalPrice = parseMoney(rawItem.original_price ?? rawItem.originalPrice) ?? productSuggestedPrice ?? unitPrice;
  const discountAmount = parseMoney(rawItem.discount_amount ?? rawItem.discountAmount) ?? Math.max(0, originalPrice - finalPrice);
  const discountReason = normalizeText(rawItem.discount_reason ?? rawItem.discountReason) || null;
  const priceOverrideBy = normalizeText(rawItem.price_override_by ?? rawItem.priceOverrideBy) || null;

  return {
    productId,
    quantity,
    unitPrice,
    originalPrice,
    finalPrice,
    discountAmount,
    discountReason,
    priceOverrideBy,
  };
};

const loadProductForSale = async (client: PoolClient, merchantId: string, productId: string) => {
  const result = await client.query<ProductForSaleRow>(
    `
      SELECT
        id,
        name,
        suggested_price,
        stock_quantity,
        track_stock,
        is_service,
        is_active
      FROM products
      WHERE id = $1 AND merchant_id = $2
      FOR UPDATE
    `,
    [productId, merchantId]
  );

  return result.rows[0] ?? null;
};

export const listSales = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const limit = Math.min(Math.max(Number(req.query.limit ?? 50) || 50, 1), 200);

  try {
    const result = await pool.query<SaleRow>(
      `
        SELECT
          s.id,
          s.merchant_id,
          s.staff_id,
          s.reference,
          s.total_amount,
          s.payment_method,
          s.customer_phone,
          s.status,
          s.notes,
          s.created_at,
          s.updated_at,
          COALESCE(st.name, 'Staff') AS staff_name
        FROM sales s
        LEFT JOIN staff st ON st.id = s.staff_id
        WHERE s.merchant_id = $1
        ORDER BY s.created_at DESC
        LIMIT $2
      `,
      [merchantId, limit]
    );

    res.json({
      sales: result.rows.map(row => serializeSale(row)),
    });
  } catch (error) {
    console.error('List sales error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createSale = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const body = getRequestBody(req);
  const rawItems = getSubmittedItems(body);
  const paymentMethod = normalizeText(body.payment_method ?? body.paymentMethod) || 'Cash';
  const customerPhone = normalizeText(body.customer_phone ?? body.customerPhone) || null;
  const notes = normalizeText(body.notes) || null;
  const requestedReference = normalizeText(body.reference);
  const reference = requestedReference || generateSaleReference();
  const staffId = req.staff?.id ?? null;

  if (rawItems.length === 0) {
    return res.status(400).json({ error: 'At least one sale item is required' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const lineItems: SubmittedLineItem[] = [];

    for (const rawItem of rawItems) {
      const productId = normalizeText(rawItem.product_id ?? rawItem.productId);
      const product = productId ? await loadProductForSale(client, merchantId, productId) : null;

      if (productId && (!product || product.is_active === false)) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'One or more products were not found' });
      }

      const lineItem = normalizeSubmittedItem(rawItem, product);

      if (!lineItem) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Each sale item requires a quantity and price' });
      }

      lineItems.push(lineItem);
    }

    const totalAmount = lineItems.reduce((total, item) => total + item.finalPrice * item.quantity, 0);
    const saleId = uuidv4();
    const saleResult = await client.query<SaleRow>(
      `
        INSERT INTO sales (
          id,
          merchant_id,
          staff_id,
          reference,
          total_amount,
          payment_method,
          customer_phone,
          status,
          notes
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, 'completed', $8)
        RETURNING
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
      `,
      [saleId, merchantId, staffId, reference, totalAmount, paymentMethod, customerPhone, notes]
    );

    const insertedLineItems: SaleLineItemRow[] = [];

    for (const lineItem of lineItems) {
      const lineItemResult = await client.query<SaleLineItemRow>(
        `
          INSERT INTO sale_line_items (
            id,
            sale_id,
            product_id,
            quantity,
            unit_price,
            original_price,
            final_price,
            discount_amount,
            discount_reason,
            price_override_by
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
          RETURNING
            id,
            sale_id,
            product_id,
            quantity,
            unit_price,
            original_price,
            final_price,
            discount_amount,
            discount_reason,
            price_override_by,
            created_at,
            updated_at
        `,
        [
          uuidv4(),
          saleId,
          lineItem.productId,
          lineItem.quantity,
          lineItem.unitPrice,
          lineItem.originalPrice,
          lineItem.finalPrice,
          lineItem.discountAmount,
          lineItem.discountReason,
          lineItem.priceOverrideBy,
        ]
      );

      insertedLineItems.push(lineItemResult.rows[0]);

      if (lineItem.productId) {
        await client.query(
          `
            UPDATE products
            SET stock_quantity = GREATEST(0, COALESCE(stock_quantity, 0) - $1)
            WHERE id = $2
              AND merchant_id = $3
              AND track_stock = TRUE
              AND is_service = FALSE
          `,
          [Math.ceil(lineItem.quantity), lineItem.productId, merchantId]
        );
      }
    }

    await client.query('COMMIT');

    res.status(201).json({
      message: 'Sale completed successfully',
      sale: serializeSale(
        {
          ...saleResult.rows[0],
          staff_name: req.staff?.name ?? 'Staff',
        },
        insertedLineItems
      ),
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Create sale error:', error);

    if (error instanceof Error && error.message.includes('sales_merchant_id_reference_key')) {
      return res.status(409).json({ error: 'Sale reference already exists' });
    }

    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
};
