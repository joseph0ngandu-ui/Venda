import { Router } from 'express';
import { registerMerchant, loginMerchant, joinStaffByCompanyCode, getMe } from '../controllers/auth';
import {
  createStaff,
  deactivateStaff,
  listStaff,
  reactivateStaff,
  rotateStaffPin,
  updateStaff,
} from '../controllers/staff';
import { getReportsSummary } from '../controllers/reports';
import { pushSync, pullSync } from '../controllers/sync';
import {
  authenticateJWT,
  AuthRequest,
  requireAdminAccess,
  requireTeamManagementAccess,
} from '../middleware/auth';

const router = Router();

// Auth routes
router.post('/auth/register', registerMerchant);
router.post('/auth/login', loginMerchant);
router.post('/auth/join', joinStaffByCompanyCode);
router.post('/auth/staff/login', joinStaffByCompanyCode);
router.get('/auth/me', authenticateJWT, (req, res) => getMe(req as AuthRequest, res));

// Sync routes
router.post('/sync/push', authenticateJWT, (req, res) => pushSync(req as AuthRequest, res));
router.get('/sync/pull', authenticateJWT, (req, res) => pullSync(req as AuthRequest, res));

// Staff management routes
router.get('/staff', authenticateJWT, requireTeamManagementAccess, (req, res) =>
  listStaff(req as AuthRequest, res)
);
router.post('/staff', authenticateJWT, requireAdminAccess, (req, res) =>
  createStaff(req as AuthRequest, res)
);
router.patch('/staff/:staffId', authenticateJWT, requireAdminAccess, (req, res) =>
  updateStaff(req as AuthRequest, res)
);
router.post('/staff/:staffId/pin', authenticateJWT, (req, res) =>
  rotateStaffPin(req as AuthRequest, res)
);
router.post('/staff/:staffId/deactivate', authenticateJWT, requireAdminAccess, (req, res) =>
  deactivateStaff(req as AuthRequest, res)
);
router.post('/staff/:staffId/reactivate', authenticateJWT, requireAdminAccess, (req, res) =>
  reactivateStaff(req as AuthRequest, res)
);

// Reporting routes
router.get('/reports/summary', authenticateJWT, (req, res) => getReportsSummary(req as AuthRequest, res));

export default router;
