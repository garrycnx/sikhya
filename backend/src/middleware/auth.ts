import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken } from '../utils/jwt';
import redisClient, { RedisKeys } from '../config/redis';
import { sendError } from '../utils/response';
import { AuthenticatedUser } from '../types';
declare global { namespace Express { interface Request { user?: AuthenticatedUser; } } }
export async function authenticate(req: Request, res: Response, next: NextFunction) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) return sendError(res, 'No token provided', 401);
  try {
    const payload = verifyAccessToken(auth.substring(7));
    const blacklisted = await redisClient.get(RedisKeys.blacklist(payload.jti));
    if (blacklisted) return sendError(res, 'Token revoked', 401);
    req.user = { id: payload.sub, school_id: payload.school_id, role: payload.role, user_type: payload.user_type, jti: payload.jti };
    return next();
  } catch { return sendError(res, 'Invalid or expired token', 401); }
}
export function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) return sendError(res, 'Insufficient permissions', 403);
    return next();
  };
}