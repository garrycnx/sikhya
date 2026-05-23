import { Request, Response } from 'express';
import { z } from 'zod';
import * as AuthService from '../services/auth.service';
import { sendSuccess, sendError } from '../utils/response';
import redisClient, { RedisKeys } from '../config/redis';

const requestOtpSchema = z.object({
  school_subdomain: z.string().min(1), mobile: z.string().min(10).max(15), admission_no: z.string().optional(),
});
const verifyOtpSchema = z.object({
  school_subdomain: z.string().min(1), mobile: z.string().min(10).max(15),
  otp: z.string().length(6), fcm_token: z.string().optional(), platform: z.enum(['android','ios']).optional(),
});
const setPinSchema = z.object({
  pin: z.string().regex(/^\d{4}$/, 'PIN must be 4 digits'),
});
const loginPinSchema = z.object({
  school_subdomain: z.string().min(1),
  mobile:           z.string().min(10).max(15),
  pin:              z.string().regex(/^\d{4}$/, 'PIN must be 4 digits'),
  admission_no:     z.string().optional(),
});

export async function requestOtp(req: Request, res: Response) {
  console.log('requestOtp body:', JSON.stringify(req.body));
  const p = requestOtpSchema.safeParse(req.body);
  if (!p.success) {
    console.log('validation error:', p.error.errors);
    return sendError(res, p.error.errors[0].message, 422);
  }
  try { return sendSuccess(res, await AuthService.requestOtp(p.data.school_subdomain, p.data.mobile, p.data.admission_no)); }
  catch (e: unknown) {
    console.error('requestOtp error:', e);
    return sendError(res, e instanceof Error ? e.message : String(e));
  }
}

export async function verifyOtp(req: Request, res: Response) {
  const p = verifyOtpSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  try { return sendSuccess(res, await AuthService.verifyOtpAndLogin(p.data.school_subdomain, p.data.mobile, p.data.otp, p.data.fcm_token, p.data.platform)); }
  catch (e: unknown) { return sendError(res, e instanceof Error ? e.message : 'Failed', 401); }
}

export async function setPin(req: Request, res: Response) {
  const p = setPinSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  try {
    return sendSuccess(res, await AuthService.setPin(
      req.user!.id, req.user!.user_type, req.user!.school_id, p.data.pin
    ));
  } catch (e: unknown) { return sendError(res, e instanceof Error ? e.message : 'Failed'); }
}

export async function loginWithPin(req: Request, res: Response) {
  const p = loginPinSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  try {
    return sendSuccess(res, await AuthService.loginWithPin(
      p.data.school_subdomain, p.data.mobile, p.data.pin, p.data.admission_no
    ));
  } catch (e: unknown) { return sendError(res, e instanceof Error ? e.message : 'Failed', 401); }
}

export async function refreshToken(req: Request, res: Response) {
  const { refresh_token } = req.body;
  if (!refresh_token) return sendError(res, 'refresh_token required', 422);
  try { return sendSuccess(res, await AuthService.refreshAccessToken(refresh_token)); }
  catch { return sendError(res, 'Invalid refresh token', 401); }
}

export async function logout(req: Request, res: Response) {
  if (req.user) await redisClient.setEx(RedisKeys.blacklist(req.user.jti), 900, '1');
  return sendSuccess(res, { message: 'Logged out' });
}

export async function me(req: Request, res: Response) { return sendSuccess(res, req.user); }
