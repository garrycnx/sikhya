import { Router } from 'express';
import * as Auth from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth';
import rateLimit from 'express-rate-limit';

const router = Router();

const otpLimiter = rateLimit({
  windowMs: 600000, max: parseInt(process.env.OTP_RATE_LIMIT_MAX || '5'),
  message: { success: false, error: 'Too many OTP requests, try again in 10 minutes' },
  standardHeaders: true, legacyHeaders: false,
});

const pinLimiter = rateLimit({
  windowMs: 300000, max: 10,
  message: { success: false, error: 'Too many PIN attempts, try again in 5 minutes' },
  standardHeaders: true, legacyHeaders: false,
});

router.post('/request-otp',  otpLimiter,             Auth.requestOtp);
router.post('/verify-otp',   otpLimiter,             Auth.verifyOtp);
router.post('/login-pin',    pinLimiter,             Auth.loginWithPin);
router.post('/set-pin',      authenticate,           Auth.setPin);
router.post('/refresh',                              Auth.refreshToken);
router.post('/logout',       authenticate,           Auth.logout);
router.get('/me',            authenticate,           Auth.me);

export default router;
