import { Request, Response, NextFunction } from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';

export type StaffRole = 'admin' | 'manager' | 'cashier';

export const buildCompanyCode = (merchantId: string) => {
  return `VND-${merchantId.replace(/-/g, '').slice(0, 8).toUpperCase()}`;
};

export const normalizeStaffRole = (role?: string): StaffRole => {
  switch (role) {
    case 'admin':
    case 'manager':
    case 'cashier':
      return role;
    case 'owner':
      return 'admin';
    default:
      return 'admin';
  }
};

export interface AuthTokenPayload extends JwtPayload {
  merchantId?: string;
  id?: string;
  phone?: string;
  companyCode?: string;
  authType?: 'merchant' | 'staff';
  staffId?: string;
  staffName?: string;
  role?: string;
}

export interface AuthMerchant {
  id: string;
  phone?: string;
  companyCode: string;
}

export interface AuthStaff {
  id: string;
  merchantId: string;
  name: string;
  role: StaffRole;
  companyCode: string;
}

export interface AuthRequest extends Request {
  merchant?: AuthMerchant;
  staff?: AuthStaff;
  authType?: 'merchant' | 'staff';
}

export const authenticateJWT = (req: AuthRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const token = authHeader.slice(7).trim();

  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'venda_secret_key') as AuthTokenPayload;
    const merchantId = decoded.merchantId ?? decoded.id;

    if (!merchantId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const companyCode = decoded.companyCode ?? buildCompanyCode(merchantId);

    req.merchant = {
      id: merchantId,
      phone: decoded.phone,
      companyCode,
    };
    req.authType = decoded.authType ?? 'merchant';

    if (decoded.staffId) {
      req.staff = {
        id: decoded.staffId,
        merchantId,
        name: decoded.staffName ?? '',
        role: normalizeStaffRole(decoded.role),
        companyCode,
      };
    }

    next();
  } catch (error) {
    res.status(403).json({ error: 'Forbidden' });
  }
};
