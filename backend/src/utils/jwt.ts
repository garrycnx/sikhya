import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { JwtPayload, UserRole, UserType } from '../types';

export function generateAccessToken(payload: Omit<JwtPayload, 'jti' | 'iat' | 'exp'>): string {
  return jwt.sign({ ...payload, jti: uuidv4() }, process.env.JWT_ACCESS_SECRET!, {
    expiresIn: (process.env.JWT_ACCESS_EXPIRES_IN || '15m') as any,
  });
}

export function generateRefreshToken(userId: string, schoolId: string, role: UserRole, userType: UserType): { token: string; jti: string } {
  const jti = uuidv4();
  const token = jwt.sign(
    { sub: userId, school_id: schoolId, jti, role, user_type: userType },
    process.env.JWT_REFRESH_SECRET!,
    { expiresIn: (process.env.JWT_REFRESH_EXPIRES_IN || '30d') as any },
  );
  return { token, jti };
}

export function verifyAccessToken(token: string): JwtPayload {
  return jwt.verify(token, process.env.JWT_ACCESS_SECRET!) as JwtPayload;
}

export function verifyRefreshToken(token: string): { sub: string; school_id: string; jti: string; role: UserRole; user_type: UserType } {
  return jwt.verify(token, process.env.JWT_REFRESH_SECRET!) as { sub: string; school_id: string; jti: string; role: UserRole; user_type: UserType };
}
