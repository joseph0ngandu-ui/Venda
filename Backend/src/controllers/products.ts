import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/db';
import { AuthRequest } from '../middleware/auth';

type ProductRow = {
  id: string;
  merchant_id: string;
  name: string;
  category: string | null;
  pricing_type: string;
  suggested_price: string | number | null;
  min_price: string | number | null;
  max_price: string | number | null;
  stock_quantity: number | null;
  low_stock_threshold: number | null;
  track_stock: boolean | null;
  is_service: boolean | null;
  is_active: boolean | null;
  created_at: Date | string;
  updated_at: Date | string;
};

const PRICING_TYPES = new Set(['fixed', 'flexible', 'range', 'open', 'service']);

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

const parseOptionalNumber = (value: unknown) => {
  if (value === undefined || value === null || value === '') {
    return null;
  }

  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
};

const parseOptionalInteger = (value: unknown, fallback: number) => {
  const numberValue = parseOptionalNumber(value);
  if (numberValue === null) {
    return fallback;
  }

  return Math.max(0, Math.floor(numberValue));
};

const parseOptionalBoolean = (value: unknown, fallback: boolean) => {
  if (typeof value === 'boolean') {
    return value;
  }

  const normalized = normalizeText(value).toLowerCase();

  if (normalized === 'true') {
    return true;
  }

  if (normalized === 'false') {
    return false;
  }

  return fallback;
};

const normalizePricingType = (value: unknown) => {
  const normalized = normalizeText(value).toLowerCase();
  return PRICING_TYPES.has(normalized) ? normalized : null;
};

const toIsoString = (value: Date | string | null | undefined) => {
  if (!value) {
    return new Date().toISOString();
  }

  return new Date(value).toISOString();
};

const serializeProduct = (row: ProductRow) => ({
  id: row.id,
  merchant_id: row.merchant_id,
  name: row.name,
  category: row.category ?? '',
  pricing_type: row.pricing_type,
  suggested_price: row.suggested_price === null ? null : Number(row.suggested_price),
  min_price: row.min_price === null ? null : Number(row.min_price),
  max_price: row.max_price === null ? null : Number(row.max_price),
  stock_quantity: Number(row.stock_quantity ?? 0),
  low_stock_threshold: Number(row.low_stock_threshold ?? 5),
  track_stock: row.track_stock ?? true,
  is_service: row.is_service ?? false,
  is_active: row.is_active ?? true,
  created_at: toIsoString(row.created_at),
  updated_at: toIsoString(row.updated_at),
});

const getProductId = (req: Request) => {
  const rawProductId = req.params.productId;
  return Array.isArray(rawProductId) ? rawProductId[0] ?? '' : rawProductId ?? '';
};

const ensureMerchant = (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;

  if (!merchantId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }

  return merchantId;
};

export const listProducts = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const search = normalizeText(req.query.search);
  const includeInactive = parseOptionalBoolean(req.query.include_inactive, false);
  const values: unknown[] = [merchantId];
  const filters = ['merchant_id = $1'];

  if (!includeInactive) {
    filters.push('is_active = TRUE');
  }

  if (search) {
    values.push(`%${search.toLowerCase()}%`);
    filters.push(`(lower(name) LIKE $${values.length} OR lower(COALESCE(category, '')) LIKE $${values.length})`);
  }

  try {
    const result = await pool.query<ProductRow>(
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
        WHERE ${filters.join(' AND ')}
        ORDER BY is_active DESC, lower(name) ASC, created_at DESC
      `,
      values
    );

    const products = result.rows.map(serializeProduct);

    res.json({
      summary: {
        total: products.length,
        active: products.filter(product => product.is_active).length,
        low_stock: products.filter(
          product =>
            product.is_active &&
            product.track_stock &&
            !product.is_service &&
            product.stock_quantity <= product.low_stock_threshold
        ).length,
      },
      products,
    });
  } catch (error) {
    console.error('List products error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createProduct = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const body = getRequestBody(req);
  const name = normalizeText(body.name);
  const category = normalizeText(body.category) || 'General';
  const pricingType = normalizePricingType(body.pricing_type) ?? 'fixed';
  const suggestedPrice = parseOptionalNumber(body.suggested_price);
  const minPrice = parseOptionalNumber(body.min_price);
  const maxPrice = parseOptionalNumber(body.max_price);
  const isService = parseOptionalBoolean(body.is_service, pricingType === 'service');
  const trackStock = parseOptionalBoolean(body.track_stock, !isService);
  const stockQuantity = parseOptionalInteger(body.stock_quantity, 0);
  const lowStockThreshold = parseOptionalInteger(body.low_stock_threshold, 5);

  if (!name) {
    return res.status(400).json({ error: 'Product name is required' });
  }

  if (pricingType === 'range' && minPrice !== null && maxPrice !== null && minPrice > maxPrice) {
    return res.status(400).json({ error: 'Minimum price must be less than or equal to maximum price' });
  }

  try {
    const result = await pool.query<ProductRow>(
      `
        INSERT INTO products (
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
          is_active
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, TRUE)
        RETURNING
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
      `,
      [
        uuidv4(),
        merchantId,
        name,
        category,
        pricingType,
        suggestedPrice,
        minPrice,
        maxPrice,
        stockQuantity,
        lowStockThreshold,
        trackStock,
        isService,
      ]
    );

    res.status(201).json({
      message: 'Product created successfully',
      product: serializeProduct(result.rows[0]),
    });
  } catch (error) {
    console.error('Create product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateProduct = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const productId = getProductId(req);

  if (!productId) {
    return res.status(400).json({ error: 'Missing product id' });
  }

  const body = getRequestBody(req);

  try {
    const existingResult = await pool.query<ProductRow>(
      `
        SELECT *
        FROM products
        WHERE id = $1 AND merchant_id = $2
        LIMIT 1
      `,
      [productId, merchantId]
    );

    const existing = existingResult.rows[0];

    if (!existing) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const nextPricingType =
      body.pricing_type === undefined ? existing.pricing_type : normalizePricingType(body.pricing_type);

    if (!nextPricingType) {
      return res.status(400).json({ error: 'Invalid pricing type' });
    }

    const nextName = body.name === undefined ? existing.name : normalizeText(body.name);
    const nextMinPrice = body.min_price === undefined ? existing.min_price : parseOptionalNumber(body.min_price);
    const nextMaxPrice = body.max_price === undefined ? existing.max_price : parseOptionalNumber(body.max_price);

    if (!nextName) {
      return res.status(400).json({ error: 'Product name is required' });
    }

    if (
      nextPricingType === 'range' &&
      nextMinPrice !== null &&
      nextMaxPrice !== null &&
      Number(nextMinPrice) > Number(nextMaxPrice)
    ) {
      return res.status(400).json({ error: 'Minimum price must be less than or equal to maximum price' });
    }

    const result = await pool.query<ProductRow>(
      `
        UPDATE products
        SET
          name = $1,
          category = $2,
          pricing_type = $3,
          suggested_price = $4,
          min_price = $5,
          max_price = $6,
          stock_quantity = $7,
          low_stock_threshold = $8,
          track_stock = $9,
          is_service = $10,
          is_active = $11
        WHERE id = $12 AND merchant_id = $13
        RETURNING
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
      `,
      [
        nextName,
        body.category === undefined ? existing.category : normalizeText(body.category),
        nextPricingType,
        body.suggested_price === undefined
          ? existing.suggested_price
          : parseOptionalNumber(body.suggested_price),
        nextMinPrice,
        nextMaxPrice,
        body.stock_quantity === undefined
          ? existing.stock_quantity
          : parseOptionalInteger(body.stock_quantity, 0),
        body.low_stock_threshold === undefined
          ? existing.low_stock_threshold
          : parseOptionalInteger(body.low_stock_threshold, 5),
        body.track_stock === undefined
          ? existing.track_stock
          : parseOptionalBoolean(body.track_stock, existing.track_stock ?? true),
        body.is_service === undefined
          ? existing.is_service
          : parseOptionalBoolean(body.is_service, existing.is_service ?? false),
        body.is_active === undefined
          ? existing.is_active
          : parseOptionalBoolean(body.is_active, existing.is_active ?? true),
        productId,
        merchantId,
      ]
    );

    res.json({
      message: 'Product updated successfully',
      product: serializeProduct(result.rows[0]),
    });
  } catch (error) {
    console.error('Update product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deleteProduct = async (req: AuthRequest, res: Response) => {
  const merchantId = ensureMerchant(req, res);

  if (!merchantId) {
    return;
  }

  const productId = getProductId(req);

  if (!productId) {
    return res.status(400).json({ error: 'Missing product id' });
  }

  try {
    const result = await pool.query<ProductRow>(
      `
        UPDATE products
        SET is_active = FALSE
        WHERE id = $1 AND merchant_id = $2
        RETURNING
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
      `,
      [productId, merchantId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.json({
      message: 'Product archived successfully',
      product: serializeProduct(result.rows[0]),
    });
  } catch (error) {
    console.error('Delete product error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
