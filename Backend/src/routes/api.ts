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
import { createProduct, deleteProduct, listProducts, updateProduct } from '../controllers/products';
import { createSale, listSales } from '../controllers/sales';
import {
  createCreditEntry,
  createMoMoTransaction,
  getMoneySummary,
  matchMoMoTransaction,
  recordCreditRepayment,
  updateMoMoTransaction,
} from '../controllers/money';
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

// Product routes
router.get('/products', authenticateJWT, (req, res) => listProducts(req as AuthRequest, res));
router.post('/products', authenticateJWT, requireTeamManagementAccess, (req, res) =>
  createProduct(req as AuthRequest, res)
);
router.patch('/products/:productId', authenticateJWT, requireTeamManagementAccess, (req, res) =>
  updateProduct(req as AuthRequest, res)
);
router.delete('/products/:productId', authenticateJWT, requireTeamManagementAccess, (req, res) =>
  deleteProduct(req as AuthRequest, res)
);

// Sales routes
router.get('/sales', authenticateJWT, (req, res) => listSales(req as AuthRequest, res));
router.post('/sales', authenticateJWT, (req, res) => createSale(req as AuthRequest, res));

// Money routes
router.get('/money', authenticateJWT, (req, res) => getMoneySummary(req as AuthRequest, res));
router.post('/money/momo', authenticateJWT, (req, res) =>
  createMoMoTransaction(req as AuthRequest, res)
);
router.patch('/money/momo/:momoId', authenticateJWT, (req, res) =>
  updateMoMoTransaction(req as AuthRequest, res)
);
router.post('/money/momo/:momoId/match', authenticateJWT, (req, res) =>
  matchMoMoTransaction(req as AuthRequest, res)
);
router.post('/money/credits', authenticateJWT, (req, res) =>
  createCreditEntry(req as AuthRequest, res)
);
router.post('/money/credits/:creditId/repay', authenticateJWT, (req, res) =>
  recordCreditRepayment(req as AuthRequest, res)
);

// Reporting routes
router.get('/reports/summary', authenticateJWT, (req, res) => getReportsSummary(req as AuthRequest, res));

export default router;
