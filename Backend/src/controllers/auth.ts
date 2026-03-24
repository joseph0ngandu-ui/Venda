import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/db';
import { AuthRequest } from '../middleware/auth';

export const registerMerchant = async (req: Request, res: Response) => {
  const { business_name, business_type, phone, pin } = req.body;

  if (!business_name || !business_type || !phone || !pin) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const existing = await pool.query('SELECT id FROM merchants WHERE phone = $1', [phone]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Phone number already registered' });
    }

    const salt = await bcrypt.genSalt(10);
    const pinHash = await bcrypt.hash(pin, salt);
    const merchantId = uuidv4();

    await pool.query(
      `INSERT INTO merchants (id, business_name, business_type, phone, pin_hash) 
       VALUES ($1, $2, $3, $4, $5)`,
      [merchantId, business_name, business_type, phone, pinHash]
    );

    // Create default owner staff account automatically
    const staffId = uuidv4();
    await pool.query(
      `INSERT INTO staff (id, merchant_id, name, role, pin_hash) 
       VALUES ($1, $2, $3, $4, $5)`,
      [staffId, merchantId, 'Owner', 'owner', pinHash] // Using same PIN for owner user
    );

    const token = jwt.sign(
      { id: merchantId, phone },
      process.env.JWT_SECRET || 'venda_secret_key',
      { expiresIn: '30d' }
    );

    res.status(201).json({
      message: 'Merchant registered successfully',
      merchant: {
        id: merchantId,
        business_name,
        business_type,
        phone
      },
      token
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const loginMerchant = async (req: Request, res: Response) => {
  const { phone, pin } = req.body;

  try {
    const result = await pool.query('SELECT * FROM merchants WHERE phone = $1', [phone]);
    
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid phone or PIN' });
    }

    const merchant = result.rows[0];
    const isMatch = await bcrypt.compare(pin, merchant.pin_hash);

    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid phone or PIN' });
    }

    const token = jwt.sign(
      { id: merchant.id, phone: merchant.phone },
      process.env.JWT_SECRET || 'venda_secret_key',
      { expiresIn: '30d' }
    );

    res.json({
      merchant: {
        id: merchant.id,
        business_name: merchant.business_name,
        business_type: merchant.business_type,
        phone: merchant.phone,
        currency: merchant.currency
      },
      token
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    const merchantId = req.merchant?.id;
    const result = await pool.query(
      'SELECT id, business_name, business_type, phone, currency, created_at FROM merchants WHERE id = $1',
      [merchantId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Merchant not found' });
    }

    res.json({ merchant: result.rows[0] });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};
