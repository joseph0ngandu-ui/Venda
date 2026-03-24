import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/db';
import { AuthRequest, buildCompanyCode, normalizeStaffRole } from '../middleware/auth';

const AUTH_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60;

type MerchantRow = {
  id: string;
  business_name: string;
  business_type: string;
  phone: string;
  currency: string | null;
  created_at: Date | string;
  updated_at: Date | string;
};

type MerchantRowWithPin = MerchantRow & {
  pin_hash: string;
};

type StaffRow = {
  id: string;
  merchant_id: string;
  name: string;
  role: string;
  pin_hash?: string;
  is_active: boolean | null;
  created_at: Date | string;
  updated_at: Date | string;
};

type MerchantProfile = {
  id: string;
  business_name: string;
  business_type: string;
  phone: string;
  currency: string;
  company_code: string;
  created_at: string;
  updated_at: string;
};

type StaffProfile = {
  id: string;
  merchant_id: string;
  name: string;
  role: string;
  company_code: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

const toIsoString = (value: Date | string | null | undefined) => {
  if (!value) {
    return new Date().toISOString();
  }

  return new Date(value).toISOString();
};

const normalizeText = (value: unknown) => {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim();
};

const serializeMerchant = (merchant: MerchantRow): MerchantProfile => {
  const companyCode = buildCompanyCode(merchant.id);

  return {
    id: merchant.id,
    business_name: merchant.business_name,
    business_type: merchant.business_type,
    phone: merchant.phone,
    currency: merchant.currency || 'ZMW',
    company_code: companyCode,
    created_at: toIsoString(merchant.created_at),
    updated_at: toIsoString(merchant.updated_at),
  };
};

const serializeStaff = (staff: StaffRow, merchantId: string, companyCode: string): StaffProfile => {
  return {
    id: staff.id,
    merchant_id: merchantId,
    name: staff.name,
    role: normalizeStaffRole(staff.role),
    company_code: companyCode,
    is_active: staff.is_active ?? true,
    created_at: toIsoString(staff.created_at),
    updated_at: toIsoString(staff.updated_at),
  };
};

const synthesizeFallbackStaff = (merchant: MerchantRow): StaffRow => {
  return {
    id: merchant.id,
    merchant_id: merchant.id,
    name: merchant.business_name,
    role: 'admin',
    is_active: true,
    created_at: merchant.created_at,
    updated_at: merchant.updated_at,
  };
};

const loadMerchantById = async (merchantId: string) => {
  const result = await pool.query(
    `
      SELECT id, business_name, business_type, phone, currency, created_at, updated_at
      FROM merchants
      WHERE id = $1
      LIMIT 1
    `,
    [merchantId]
  );

  return (result.rows[0] as MerchantRow | undefined) ?? null;
};

const loadMerchantByCompanyCode = async (companyCode: string) => {
  const normalizedCompanyCode = companyCode.trim().toUpperCase();

  const result = await pool.query(
    `
      SELECT id, business_name, business_type, phone, currency, created_at, updated_at
      FROM merchants
      WHERE ('VND-' || upper(left(replace(id::text, '-', ''), 8))) = $1
      LIMIT 1
    `,
    [normalizedCompanyCode]
  );

  return (result.rows[0] as MerchantRow | undefined) ?? null;
};

const loadPrimaryStaff = async (merchantId: string) => {
  const result = await pool.query(
    `
      SELECT id, merchant_id, name, role, is_active, created_at, updated_at
      FROM staff
      WHERE merchant_id = $1
      ORDER BY
        CASE
          WHEN role IN ('admin', 'owner') THEN 0
          WHEN role = 'manager' THEN 1
          ELSE 2
        END,
        created_at ASC
      LIMIT 1
    `,
    [merchantId]
  );

  return (result.rows[0] as StaffRow | undefined) ?? null;
};

const loadStaffByPin = async (merchantId: string, pin: string) => {
  const result = await pool.query(
    `
      SELECT id, merchant_id, name, role, pin_hash, is_active, created_at, updated_at
      FROM staff
      WHERE merchant_id = $1
        AND is_active = TRUE
      ORDER BY
        CASE
          WHEN role IN ('admin', 'owner') THEN 0
          WHEN role = 'manager' THEN 1
          ELSE 2
        END,
        created_at ASC
    `,
    [merchantId]
  );

  for (const row of result.rows as StaffRow[]) {
    if (row.pin_hash && (await bcrypt.compare(pin, row.pin_hash))) {
      return row;
    }
  }

  return null;
};

const createAuthToken = (merchant: MerchantRow, staff: StaffRow, authType: 'merchant' | 'staff') => {
  const companyCode = buildCompanyCode(merchant.id);

  return jwt.sign(
    {
      merchantId: merchant.id,
      phone: merchant.phone,
      companyCode,
      authType,
      staffId: staff.id,
      staffName: staff.name,
      role: normalizeStaffRole(staff.role),
    },
    process.env.JWT_SECRET || 'venda_secret_key',
    { expiresIn: '30d' }
  );
};

const buildAuthResponse = (
  merchant: MerchantRow,
  staff: StaffRow,
  token: string,
  authType: 'merchant' | 'staff',
  message: string
) => {
  const merchantProfile = serializeMerchant(merchant);
  const staffProfile = serializeStaff(staff, merchant.id, merchantProfile.company_code);
  const expiresAt = new Date(Date.now() + AUTH_TOKEN_TTL_SECONDS * 1000).toISOString();

  return {
    message,
    auth_type: authType,
    token,
    token_type: 'Bearer',
    expires_in: AUTH_TOKEN_TTL_SECONDS,
    expires_at: expiresAt,
    company_code: merchantProfile.company_code,
    merchant: merchantProfile,
    staff: staffProfile,
    user: staffProfile,
    session: {
      access_token: token,
      token_type: 'Bearer',
      expires_in: AUTH_TOKEN_TTL_SECONDS,
      expires_at: expiresAt,
      auth_type: authType,
      company_code: merchantProfile.company_code,
      merchant_id: merchant.id,
      staff_id: staff.id,
      role: staffProfile.role,
    },
  };
};

export const registerMerchant = async (req: Request, res: Response) => {
  const businessName = normalizeText(req.body.business_name);
  const businessType = normalizeText(req.body.business_type);
  const phone = normalizeText(req.body.phone);
  const pin = normalizeText(req.body.pin);
  const ownerName = normalizeText(req.body.owner_name) || 'Owner';

  if (!businessName || !businessType || !phone || !pin) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const existing = await pool.query('SELECT id FROM merchants WHERE phone = $1', [phone]);
  if (existing.rows.length > 0) {
    return res.status(409).json({ error: 'Phone number already registered' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const salt = await bcrypt.genSalt(10);
    const pinHash = await bcrypt.hash(pin, salt);
    const merchantId = uuidv4();

    const merchantResult = await client.query(
      `
        INSERT INTO merchants (id, business_name, business_type, phone, pin_hash)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, business_name, business_type, phone, currency, created_at, updated_at
      `,
      [merchantId, businessName, businessType, phone, pinHash]
    );

    const staffResult = await client.query(
      `
        INSERT INTO staff (id, merchant_id, name, role, pin_hash)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, merchant_id, name, role, is_active, created_at, updated_at
      `,
      [uuidv4(), merchantId, ownerName, 'admin', pinHash]
    );

    await client.query('COMMIT');

    const merchant = merchantResult.rows[0] as MerchantRow;
    const ownerStaff = staffResult.rows[0] as StaffRow;
    const token = createAuthToken(merchant, ownerStaff, 'merchant');

    res.status(201).json(
      buildAuthResponse(merchant, ownerStaff, token, 'merchant', 'Merchant registered successfully')
    );
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    client.release();
  }
};

export const loginMerchant = async (req: Request, res: Response) => {
  const phone = normalizeText(req.body.phone);
  const pin = normalizeText(req.body.pin);

  if (!phone || !pin) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const result = await pool.query(
      `
        SELECT id, business_name, business_type, phone, pin_hash, currency, created_at, updated_at
        FROM merchants
        WHERE phone = $1
        LIMIT 1
      `,
      [phone]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid phone or PIN' });
    }

    const merchant = result.rows[0] as MerchantRowWithPin;
    const isMatch = await bcrypt.compare(pin, merchant.pin_hash);

    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid phone or PIN' });
    }

    const primaryStaff = (await loadPrimaryStaff(merchant.id)) ?? synthesizeFallbackStaff(merchant);
    const token = createAuthToken(merchant, primaryStaff, 'merchant');

    res.json(
      buildAuthResponse(merchant, primaryStaff, token, 'merchant', 'Merchant login successful')
    );
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const joinStaffByCompanyCode = async (req: Request, res: Response) => {
  const companyCode = normalizeText(req.body.company_code ?? req.body.companyCode).toUpperCase();
  const pin = normalizeText(req.body.pin);

  if (!companyCode || !pin) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const merchant = await loadMerchantByCompanyCode(companyCode);

    if (!merchant) {
      return res.status(404).json({ error: 'Company code not found' });
    }

    const staff = await loadStaffByPin(merchant.id, pin);

    if (!staff) {
      return res.status(401).json({ error: 'Invalid company code or PIN' });
    }

    const token = createAuthToken(merchant, staff, 'staff');

    res.json(
      buildAuthResponse(merchant, staff, token, 'staff', 'Staff login successful')
    );
  } catch (error) {
    console.error('Staff join/login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    const merchantId = req.merchant?.id;
    const merchant = merchantId ? await loadMerchantById(merchantId) : null;

    if (!merchant) {
      return res.status(404).json({ error: 'Merchant not found' });
    }

    const companyCode = buildCompanyCode(merchant.id);
    const staff =
      (req.staff?.id
        ? await pool.query(
            `
              SELECT id, merchant_id, name, role, is_active, created_at, updated_at
              FROM staff
              WHERE id = $1 AND merchant_id = $2
              LIMIT 1
            `,
            [req.staff.id, merchant.id]
          ).then(result => (result.rows[0] as StaffRow | undefined) ?? null)
        : null) ?? (await loadPrimaryStaff(merchant.id));

    const resolvedStaff = staff ?? synthesizeFallbackStaff(merchant);
    const authType = req.authType ?? 'merchant';
    const merchantProfile = serializeMerchant(merchant);
    const staffProfile = serializeStaff(resolvedStaff, merchant.id, companyCode);

    res.json({
      authenticated: true,
      auth_type: authType,
      company_code: companyCode,
      merchant: merchantProfile,
      staff: staffProfile,
      user: staffProfile,
      session: {
        authenticated: true,
        auth_type: authType,
        company_code: companyCode,
        merchant_id: merchant.id,
        staff_id: staffProfile.id,
        role: staffProfile.role,
      },
    });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
