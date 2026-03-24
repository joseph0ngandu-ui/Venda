import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface AuthRequest extends Request {
  merchant?: {
    id: string;
    phone: string;
  };
}

export const authenticateJWT = (req: AuthRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const token = authHeader.split(' ')[1];

    jwt.verify(token, process.env.JWT_SECRET || 'venda_secret_key', (err, user) => {
      if (err) {
        return res.status(403).json({ error: 'Forbidden' });
      }

      req.merchant = user as any;
      next();
    });
  } else {
    res.status(401).json({ error: 'Unauthorized' });
  }
};
