import { Request, Response, NextFunction } from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';
import pool from '../config/db';
import { getJwtSecret } from '../config/env';

export type StaffRole = 'admin' | 'manager' | 'cashier';

const TEAM_MANAGER_ROLES: StaffRole[] = ['admin', 'manager'];

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

export const isValidStaffRole = (role: unknown): role is StaffRole => {
  return role === 'admin' || role === 'manager' || role === 'cashier';
};

export const canManageTeam = (role?: string | null) => {
  return !!role && TEAM_MANAGER_ROLES.includes(normalizeStaffRole(role));
};

export const canManageAllStaff = (role?: string | null) => {
  return !!role && normalizeStaffRole(role) === 'admin';
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

export const authenticateJWT = async (req: AuthRequest, res: Response, next: NextFunction) => {
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
    const decoded = jwt.verify(token, getJwtSecret()) as AuthTokenPayload;
    const merchantId = decoded.merchantId ?? decoded.id;

    if (!merchantId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const companyCode = decoded.companyCode ?? buildCompanyCode(merchantId);
    const authType = decoded.authType ?? 'merchant';

    req.merchant = {
      id: merchantId,
      phone: decoded.phone,
      companyCode,
    };
    req.authType = authType;

    if (decoded.staffId) {
      const result = await pool.query(
        `
          SELECT id, merchant_id, name, role, is_active
          FROM staff
          WHERE id = $1 AND merchant_id = $2
          LIMIT 1
        `,
        [decoded.staffId, merchantId]
      );

      const liveStaff = result.rows[0] as
        | { id: string; merchant_id: string; name: string; role: string; is_active: boolean | null }
        | undefined;

      if (!liveStaff) {
        if (authType !== 'merchant') {
          res.status(403).json({ error: 'Staff account is inactive' });
          return;
        }

        req.staff = {
          id: decoded.staffId,
          merchantId,
          name:
            typeof decoded.staffName === 'string' && decoded.staffName.trim()
              ? decoded.staffName.trim()
              : 'Owner',
          role: normalizeStaffRole(decoded.role),
          companyCode,
        };
      } else if (liveStaff.is_active === false) {
        res.status(403).json({ error: 'Staff account is inactive' });
        return;
      } else {
        req.staff = {
          id: liveStaff.id,
          merchantId,
          name: liveStaff.name,
          role: normalizeStaffRole(liveStaff.role),
          companyCode,
        };
      }
    }

    next();
  } catch (error) {
    res.status(403).json({ error: 'Forbidden' });
  }
};

export const requireTeamManagementAccess = (req: AuthRequest, res: Response, next: NextFunction) => {
  if (!req.staff || !canManageTeam(req.staff.role)) {
    res.status(403).json({ error: 'Team management access required' });
    return;
  }

  next();
};

export const requireAdminAccess = (req: AuthRequest, res: Response, next: NextFunction) => {
  if (!req.staff || !canManageAllStaff(req.staff.role)) {
    res.status(403).json({ error: 'Admin access required' });
    return;
  }

  next();
};
