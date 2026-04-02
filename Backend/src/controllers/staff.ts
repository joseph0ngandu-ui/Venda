import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/db';
import {
  AuthRequest,
  StaffRole,
  canManageAllStaff,
  canManageTeam,
  isValidStaffRole,
  normalizeStaffRole,
} from '../middleware/auth';

type StaffRow = {
  id: string;
  merchant_id: string;
  name: string;
  role: string;
  pin_hash?: string;
  is_active: boolean | null;
  created_at: Date | string;
  updated_at: Date | string;
  last_login_at: Date | string | null;
  pin_updated_at: Date | string | null;
  deactivated_at: Date | string | null;
  created_by_staff_id: string | null;
};

type StaffMemberResponse = {
  id: string;
  merchant_id: string;
  name: string;
  role: StaffRole;
  company_code: string;
  is_active: boolean;
  status: 'active' | 'inactive';
  created_at: string;
  updated_at: string;
  last_login_at: string | null;
  pin_updated_at: string | null;
  deactivated_at: string | null;
  created_by_staff_id: string | null;
  is_current_user: boolean;
};

const toIsoString = (value: Date | string | null | undefined) => {
  if (!value) {
    return null;
  }

  return new Date(value).toISOString();
};

const normalizeText = (value: unknown) => {
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim();
};

const getRequestBody = (req: Request): Record<string, unknown> => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return {};
  }

  return req.body as Record<string, unknown>;
};

const parseOptionalBoolean = (value: unknown) => {
  if (value === undefined) {
    return { provided: false, isValid: true, value: undefined as boolean | undefined };
  }

  if (typeof value === 'boolean') {
    return { provided: true, isValid: true, value };
  }

  const normalizedValue = normalizeText(value).toLowerCase();

  if (normalizedValue === 'true') {
    return { provided: true, isValid: true, value: true };
  }

  if (normalizedValue === 'false') {
    return { provided: true, isValid: true, value: false };
  }

  return { provided: true, isValid: false, value: undefined as boolean | undefined };
};

const parseRole = (value: unknown) => {
  const normalizedValue = normalizeText(value).toLowerCase();

  if (!isValidStaffRole(normalizedValue)) {
    return null;
  }

  return normalizedValue;
};

const isPinValid = (pin: string) => {
  return pin.length >= 4 && pin.length <= 12;
};

const roleSortWeight = (role: string) => {
  switch (normalizeStaffRole(role)) {
    case 'admin':
      return 0;
    case 'manager':
      return 1;
    case 'cashier':
      return 2;
  }
};

const serializeStaff = (
  row: StaffRow,
  companyCode: string,
  currentStaffId?: string
): StaffMemberResponse => {
  const role = normalizeStaffRole(row.role);
  const isActive = row.is_active ?? true;

  return {
    id: row.id,
    merchant_id: row.merchant_id,
    name: row.name,
    role,
    company_code: companyCode,
    is_active: isActive,
    status: isActive ? 'active' : 'inactive',
    created_at: toIsoString(row.created_at) ?? new Date().toISOString(),
    updated_at: toIsoString(row.updated_at) ?? new Date().toISOString(),
    last_login_at: toIsoString(row.last_login_at),
    pin_updated_at: toIsoString(row.pin_updated_at),
    deactivated_at: toIsoString(row.deactivated_at),
    created_by_staff_id: row.created_by_staff_id,
    is_current_user: row.id === currentStaffId,
  };
};

const buildPermissions = (role?: string | null) => {
  const normalizedRole = role ? normalizeStaffRole(role) : null;

  return {
    can_view_team: !!normalizedRole,
    can_manage_team: canManageTeam(normalizedRole),
    can_create_staff: canManageAllStaff(normalizedRole),
    can_update_roles: canManageAllStaff(normalizedRole),
    can_rotate_any_pin: canManageAllStaff(normalizedRole),
    can_rotate_own_pin: !!normalizedRole,
  };
};

const buildSummary = (staff: StaffMemberResponse[]) => {
  return staff.reduce(
    (summary, member) => {
      summary.total += 1;
      if (member.is_active) {
        summary.active += 1;
      } else {
        summary.inactive += 1;
      }

      if (member.role === 'admin') {
        summary.admins += 1;
      } else if (member.role === 'manager') {
        summary.managers += 1;
      } else {
        summary.cashiers += 1;
      }

      return summary;
    },
    {
      total: 0,
      active: 0,
      inactive: 0,
      admins: 0,
      managers: 0,
      cashiers: 0,
    }
  );
};

const loadStaffRow = async (merchantId: string, staffId: string, includePinHash = false) => {
  const fields = [
    'id',
    'merchant_id',
    'name',
    'role',
    'is_active',
    'created_at',
    'updated_at',
    'last_login_at',
    'pin_updated_at',
    'deactivated_at',
    'created_by_staff_id',
  ];

  if (includePinHash) {
    fields.splice(4, 0, 'pin_hash');
  }

  const result = await pool.query(
    `
      SELECT ${fields.join(', ')}
      FROM staff
      WHERE merchant_id = $1 AND id = $2
      LIMIT 1
    `,
    [merchantId, staffId]
  );

  return (result.rows[0] as StaffRow | undefined) ?? null;
};

const countActiveAdmins = async (merchantId: string) => {
  const result = await pool.query(
    `
      SELECT COUNT(*)::int AS count
      FROM staff
      WHERE merchant_id = $1
        AND is_active = TRUE
        AND role IN ('admin', 'owner')
    `,
    [merchantId]
  );

  return Number(result.rows[0]?.count ?? 0);
};

const getRouteStaffId = (req: Request) => {
  const rawStaffId = req.params.staffId;

  if (Array.isArray(rawStaffId)) {
    return rawStaffId[0] ?? '';
  }

  return rawStaffId ?? '';
};

const ensureManagementContext = (req: AuthRequest, res: Response) => {
  const merchantId = req.merchant?.id;
  const companyCode = req.merchant?.companyCode;

  if (!merchantId || !companyCode || !req.staff) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }

  return {
    merchantId,
    companyCode,
    actor: req.staff,
  };
};

export const listStaff = async (req: AuthRequest, res: Response) => {
  const context = ensureManagementContext(req, res);

  if (!context) {
    return;
  }

  try {
    const result = await pool.query(
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
        WHERE merchant_id = $1
        ORDER BY
          is_active DESC,
          CASE
            WHEN role IN ('admin', 'owner') THEN 0
            WHEN role = 'manager' THEN 1
            ELSE 2
          END,
          lower(name) ASC,
          created_at ASC
      `,
      [context.merchantId]
    );

    const staff = (result.rows as StaffRow[])
      .map(row => serializeStaff(row, context.companyCode, context.actor.id))
      .sort((left, right) => {
        if (left.is_active !== right.is_active) {
          return left.is_active ? -1 : 1;
        }

        const roleDelta = roleSortWeight(left.role) - roleSortWeight(right.role);
        if (roleDelta !== 0) {
          return roleDelta;
        }

        return left.name.localeCompare(right.name, undefined, { sensitivity: 'base' });
      });

    res.json({
      company_code: context.companyCode,
      permissions: buildPermissions(context.actor.role),
      summary: buildSummary(staff),
      staff,
    });
  } catch (error) {
    console.error('List staff error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const createStaff = async (req: Request, res: Response) => {
  const authReq = req as AuthRequest;
  const context = ensureManagementContext(authReq, res);

  if (!context) {
    return;
  }

  const body = getRequestBody(req);
  const name = normalizeText(body.name);
  const role = parseRole(body.role);
  const pin = normalizeText(body.pin);

  if (!name || !role || !pin) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!isPinValid(pin)) {
    return res.status(400).json({ error: 'PIN must be between 4 and 12 characters' });
  }

  try {
    const pinHash = await bcrypt.hash(pin, await bcrypt.genSalt(10));
    const result = await pool.query(
      `
        INSERT INTO staff (
          id,
          merchant_id,
          name,
          role,
          pin_hash,
          is_active,
          created_by_staff_id,
          last_login_at,
          pin_updated_at,
          deactivated_at
        )
        VALUES ($1, $2, $3, $4, $5, TRUE, $6, NULL, CURRENT_TIMESTAMP, NULL)
        RETURNING
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
      `,
      [uuidv4(), context.merchantId, name, role, pinHash, context.actor.id]
    );

    const staff = serializeStaff(result.rows[0] as StaffRow, context.companyCode, context.actor.id);

    res.status(201).json({
      message: 'Staff created successfully',
      company_code: context.companyCode,
      staff,
    });
  } catch (error) {
    console.error('Create staff error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const updateStaff = async (req: Request, res: Response) => {
  const authReq = req as AuthRequest;
  const context = ensureManagementContext(authReq, res);

  if (!context) {
    return;
  }

  const body = getRequestBody(req);
  const targetStaffId = getRouteStaffId(req);
  const name = normalizeText(body.name);
  const roleInput = body.role;
  const nextRole = roleInput === undefined ? undefined : parseRole(roleInput);
  const parsedIsActive = parseOptionalBoolean(body.is_active);
  const nextActive = parsedIsActive.value;

  if (!targetStaffId) {
    return res.status(400).json({ error: 'Missing staff id' });
  }

  if (!name && roleInput === undefined && !parsedIsActive.provided) {
    return res.status(400).json({ error: 'No staff updates were provided' });
  }

  if (roleInput !== undefined && !nextRole) {
    return res.status(400).json({ error: 'Invalid staff role' });
  }

  if (!parsedIsActive.isValid) {
    return res
      .status(400)
      .json({ error: 'Invalid is_active value. Use true or false.' });
  }

  try {
    const currentStaff = await loadStaffRow(context.merchantId, targetStaffId);

    if (!currentStaff) {
      return res.status(404).json({ error: 'Staff member not found' });
    }

    if (targetStaffId === context.actor.id && nextActive === false) {
      return res.status(409).json({ error: 'You cannot deactivate your own account' });
    }

    const finalRole = nextRole ?? normalizeStaffRole(currentStaff.role);
    const finalIsActive = nextActive ?? (currentStaff.is_active ?? true);
    const currentIsAdmin = normalizeStaffRole(currentStaff.role) === 'admin' && (currentStaff.is_active ?? true);

    if (currentIsAdmin && (!finalIsActive || finalRole !== 'admin')) {
      const activeAdmins = await countActiveAdmins(context.merchantId);
      if (activeAdmins <= 1) {
        return res.status(409).json({ error: 'At least one active admin must remain on the team' });
      }
    }

    const assignments: string[] = [];
    const values: unknown[] = [];
    let parameterIndex = 1;

    if (name) {
      assignments.push(`name = $${parameterIndex++}`);
      values.push(name);
    }

    if (nextRole) {
      assignments.push(`role = $${parameterIndex++}`);
      values.push(nextRole);
    }

    if (nextActive !== undefined) {
      assignments.push(`is_active = $${parameterIndex++}`);
      values.push(nextActive);
      assignments.push(`deactivated_at = ${nextActive ? 'NULL' : 'CURRENT_TIMESTAMP'}`);
    }

    assignments.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(context.merchantId, targetStaffId);

    const result = await pool.query(
      `
        UPDATE staff
        SET ${assignments.join(', ')}
        WHERE merchant_id = $${parameterIndex++} AND id = $${parameterIndex}
        RETURNING
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
      `,
      values
    );

    const staff = serializeStaff(result.rows[0] as StaffRow, context.companyCode, context.actor.id);

    res.json({
      message: 'Staff updated successfully',
      company_code: context.companyCode,
      staff,
    });
  } catch (error) {
    console.error('Update staff error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

const setStaffActiveState = async (
  req: AuthRequest,
  res: Response,
  isActive: boolean,
  successMessage: string
) => {
  const context = ensureManagementContext(req, res);

  if (!context) {
    return;
  }

  const resolvedStaffId = getRouteStaffId(req);

  if (!resolvedStaffId) {
    return res.status(400).json({ error: 'Missing staff id' });
  }

  try {
    const currentStaff = await loadStaffRow(context.merchantId, resolvedStaffId);

    if (!currentStaff) {
      return res.status(404).json({ error: 'Staff member not found' });
    }

    if (!isActive && resolvedStaffId === context.actor.id) {
      return res.status(409).json({ error: 'You cannot deactivate your own account' });
    }

    const currentIsAdmin = normalizeStaffRole(currentStaff.role) === 'admin' && (currentStaff.is_active ?? true);
    if (!isActive && currentIsAdmin) {
      const activeAdmins = await countActiveAdmins(context.merchantId);
      if (activeAdmins <= 1) {
        return res.status(409).json({ error: 'At least one active admin must remain on the team' });
      }
    }

    const result = await pool.query(
      `
        UPDATE staff
        SET
          is_active = $1,
          deactivated_at = CASE WHEN $1 THEN NULL ELSE CURRENT_TIMESTAMP END,
          updated_at = CURRENT_TIMESTAMP
        WHERE merchant_id = $2 AND id = $3
        RETURNING
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
      `,
      [isActive, context.merchantId, resolvedStaffId]
    );

    const staff = serializeStaff(result.rows[0] as StaffRow, context.companyCode, context.actor.id);

    res.json({
      message: successMessage,
      company_code: context.companyCode,
      staff,
    });
  } catch (error) {
    console.error('Update staff status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const deactivateStaff = async (req: Request, res: Response) => {
  return setStaffActiveState(req as AuthRequest, res, false, 'Staff deactivated successfully');
};

export const reactivateStaff = async (req: Request, res: Response) => {
  return setStaffActiveState(req as AuthRequest, res, true, 'Staff reactivated successfully');
};

export const rotateStaffPin = async (req: Request, res: Response) => {
  const authReq = req as AuthRequest;
  const context = ensureManagementContext(authReq, res);

  if (!context) {
    return;
  }

  const body = getRequestBody(req);
  const targetStaffId = getRouteStaffId(req);
  const newPin = normalizeText(body.pin ?? body.new_pin);
  const currentPin = normalizeText(body.current_pin);

  if (!targetStaffId) {
    return res.status(400).json({ error: 'Missing staff id' });
  }

  if (!newPin) {
    return res.status(400).json({ error: 'Missing new PIN' });
  }

  if (!isPinValid(newPin)) {
    return res.status(400).json({ error: 'PIN must be between 4 and 12 characters' });
  }

  try {
    const targetStaff = await loadStaffRow(context.merchantId, targetStaffId, true);

    if (!targetStaff) {
      return res.status(404).json({ error: 'Staff member not found' });
    }

    const isSelfRotation = targetStaffId === context.actor.id;
    const canRotateAnyPin = canManageAllStaff(context.actor.role);

    if (!isSelfRotation && !canRotateAnyPin) {
      return res.status(403).json({ error: 'Admin access required to rotate another staff member PIN' });
    }

    if (isSelfRotation && !canRotateAnyPin) {
      if (!currentPin) {
        return res.status(400).json({ error: 'Current PIN is required to rotate your PIN' });
      }

      const isCurrentPinValid = await bcrypt.compare(currentPin, targetStaff.pin_hash || '');
      if (!isCurrentPinValid) {
        return res.status(401).json({ error: 'Current PIN is incorrect' });
      }
    }

    const pinHash = await bcrypt.hash(newPin, await bcrypt.genSalt(10));
    const result = await pool.query(
      `
        UPDATE staff
        SET
          pin_hash = $1,
          pin_updated_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
        WHERE merchant_id = $2 AND id = $3
        RETURNING
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
      `,
      [pinHash, context.merchantId, targetStaffId]
    );

    const staff = serializeStaff(result.rows[0] as StaffRow, context.companyCode, context.actor.id);

    res.json({
      message: 'Staff PIN rotated successfully',
      company_code: context.companyCode,
      staff,
    });
  } catch (error) {
    console.error('Rotate staff PIN error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

export const listStaffMembers = listStaff;
export const createStaffMember = createStaff;
export const updateStaffMember = updateStaff;
