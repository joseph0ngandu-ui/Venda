import { Router } from 'express';
import { registerMerchant, loginMerchant, getMe } from '../controllers/auth';
import { pushSync, pullSync } from '../controllers/sync';
import { authenticateJWT, AuthRequest } from '../middleware/auth';

const router = Router();

// Auth routes
router.post('/auth/register', registerMerchant);
router.post('/auth/login', loginMerchant);
router.get('/auth/me', authenticateJWT, (req, res) => getMe(req as AuthRequest, res));

// Sync routes
router.post('/sync/push', authenticateJWT, (req, res) => pushSync(req as AuthRequest, res));
router.get('/sync/pull', authenticateJWT, (req, res) => pullSync(req as AuthRequest, res));

export default router;
