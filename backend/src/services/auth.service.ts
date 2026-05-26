import bcrypt from 'bcryptjs';
import { adminPool, appPool } from '../config/database';
import redisClient, { RedisKeys } from '../config/redis';
import { generateOtp, hashOtp, verifyOtp } from '../utils/otp';
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from '../utils/jwt';
import { sendOtpSms } from './sms.service';

const OTP_EXPIRY   = parseInt(process.env.OTP_EXPIRY_MINUTES || '5') * 60;
const MAX_ATTEMPTS = parseInt(process.env.OTP_MAX_ATTEMPTS   || '3');

export async function requestOtp(schoolSubdomain: string, mobile: string, admissionNo?: string) {
  const schoolRes = await adminPool.query(
    'SELECT id, name, is_active FROM schools WHERE subdomain = $1',
    [schoolSubdomain]
  );
  if (!schoolRes.rows.length) throw new Error('School not found');
  const school = schoolRes.rows[0];
  if (!school.is_active) throw new Error('School account is inactive');
  const schoolId: string = school.id;

  const OTP_RATE_LIMIT = parseInt(process.env.OTP_RATE_LIMIT_MAX || '5');
  const attKey = RedisKeys.otpAttempts(schoolId, mobile);
  const att = await redisClient.get(attKey);
  if (att && parseInt(att) >= OTP_RATE_LIMIT) throw new Error('Too many OTP requests. Wait 10 minutes.');

  let userId: string, userType: 'parent' | 'teacher', userName: string;

  if (admissionNo) {
    const client = await appPool.connect();
    try {
      await client.query("SET app.current_school_id = '" + schoolId + "'");
      const result = await client.query(
        `SELECT p.id as parent_id, p.full_name
         FROM parents p
         JOIN parent_students ps ON ps.parent_id = p.id
         JOIN students s ON s.id = ps.student_id
         WHERE REPLACE(p.mobile, '+', '') = REPLACE($1, '+', '')
         AND s.admission_no = $2
         AND p.is_active = true
         LIMIT 1`,
        [mobile, admissionNo]
      );
      if (!result.rows.length) throw new Error('No account found with this mobile and admission number');
      userId   = result.rows[0].parent_id;
      userType = 'parent';
      userName = result.rows[0].full_name;
    } finally { client.release(); }
  } else {
    const client = await appPool.connect();
    try {
      await client.query("SET app.current_school_id = '" + schoolId + "'");
      const result = await client.query(
        `SELECT * FROM teachers WHERE REPLACE(mobile, '+', '') = REPLACE($1, '+', '') AND is_active = true LIMIT 1`,
        [mobile]
      );
      if (!result.rows.length) throw new Error('No teacher account found for this mobile');
      userId   = result.rows[0].id;
      userType = 'teacher';
      userName = result.rows[0].full_name;
    } finally { client.release(); }
  }

  const otp     = process.env.SKIP_SMS === 'true'
    ? (process.env.DEFAULT_OTP || '000000')
    : generateOtp(parseInt(process.env.OTP_LENGTH || '6'));
  const otpHash = await hashOtp(otp);

  await redisClient.setEx(
    RedisKeys.otp(schoolId, mobile),
    OTP_EXPIRY,
    JSON.stringify({ hash: otpHash, userId, userType, schoolId, attempts: 0 })
  );
  await redisClient.incr(attKey);
  await redisClient.expire(attKey, 600);
  if (process.env.SKIP_SMS !== 'true') await sendOtpSms(mobile, otp);

  return { message: 'OTP sent to ' + mobile.slice(0, -4) + '****', userName };
}

export async function verifyOtpAndLogin(
  schoolSubdomain: string, mobile: string, otp: string,
  fcmToken?: string, platform?: string
) {
  const schoolRes = await adminPool.query(
    'SELECT id FROM schools WHERE subdomain = $1', [schoolSubdomain]
  );
  if (!schoolRes.rows.length) throw new Error('School not found');
  const schoolId: string = schoolRes.rows[0].id;

  const stored = await redisClient.get(RedisKeys.otp(schoolId, mobile));
  if (!stored) throw new Error('OTP expired or not requested');
  const { hash, userId, userType, attempts } = JSON.parse(stored);

  if (attempts >= MAX_ATTEMPTS) {
    await redisClient.del(RedisKeys.otp(schoolId, mobile));
    throw new Error('Too many attempts. Request new OTP.');
  }

  const valid = await verifyOtp(otp, hash);
  if (!valid) {
    await redisClient.setEx(
      RedisKeys.otp(schoolId, mobile),
      OTP_EXPIRY,
      JSON.stringify({ hash, userId, userType, schoolId, attempts: attempts + 1 })
    );
    throw new Error('Incorrect OTP. ' + (MAX_ATTEMPTS - attempts - 1) + ' attempts remaining.');
  }

  await redisClient.del(RedisKeys.otp(schoolId, mobile));

  const role        = userType === 'teacher' ? 'teacher' as const : 'parent' as const;
  const accessToken = generateAccessToken({ sub: userId, school_id: schoolId, role, user_type: userType });
  const { token: refreshToken, jti: refreshJti } = generateRefreshToken(userId, schoolId, role, userType);
  await redisClient.setEx(RedisKeys.refreshToken(userId, refreshJti), 30 * 24 * 3600, '1');

  if (fcmToken && platform) {
    await adminPool.query(
      `INSERT INTO device_tokens (user_id, user_type, school_id, fcm_token, platform)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (fcm_token) DO UPDATE SET last_seen = NOW()`,
      [userId, userType, schoolId, fcmToken, platform]
    );
  }

  // Check if PIN is already set for this user
  const client = await appPool.connect();
  let pinSet = false;
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const table = userType === 'teacher' ? 'teachers' : 'parents';
    const pinRow = await client.query(
      `SELECT pin_hash IS NOT NULL AS pin_set FROM ${table} WHERE id = $1`, [userId]
    );
    pinSet = pinRow.rows[0]?.pin_set ?? false;
  } finally { client.release(); }

  return { accessToken, refreshToken, userId, userType, schoolId, pin_set: pinSet };
}

export async function setPin(userId: string, userType: string, schoolId: string, pin: string) {
  if (!/^\d{4}$/.test(pin)) throw new Error('PIN must be exactly 4 digits');
  const hash   = await bcrypt.hash(pin, 10);
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const table = userType === 'teacher' ? 'teachers' : 'parents';
    await client.query(`UPDATE ${table} SET pin_hash = $1 WHERE id = $2`, [hash, userId]);
  } finally { client.release(); }
  return { message: 'PIN set successfully' };
}

export async function loginWithPin(
  schoolSubdomain: string, mobile: string, pin: string, admissionNo?: string
) {
  if (!/^\d{4}$/.test(pin)) throw new Error('Invalid PIN');

  const schoolRes = await adminPool.query(
    'SELECT id, is_active FROM schools WHERE subdomain = $1', [schoolSubdomain]
  );
  if (!schoolRes.rows.length) throw new Error('School not found');
  if (!schoolRes.rows[0].is_active) throw new Error('School account is inactive');
  const schoolId: string = schoolRes.rows[0].id;

  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);

    let userId: string, userType: 'parent' | 'teacher', pinHash: string | null;

    if (admissionNo) {
      const r = await client.query(
        `SELECT p.id, p.pin_hash FROM parents p
         JOIN parent_students ps ON ps.parent_id = p.id
         JOIN students s ON s.id = ps.student_id
         WHERE REPLACE(p.mobile, '+', '') = REPLACE($1, '+', '')
           AND s.admission_no = $2 AND p.is_active = true LIMIT 1`,
        [mobile, admissionNo]
      );
      if (!r.rows.length) throw new Error('Account not found');
      userId   = r.rows[0].id;
      pinHash  = r.rows[0].pin_hash;
      userType = 'parent';
    } else {
      const r = await client.query(
        `SELECT id, pin_hash FROM teachers
         WHERE REPLACE(mobile, '+', '') = REPLACE($1, '+', '') AND is_active = true LIMIT 1`,
        [mobile]
      );
      if (!r.rows.length) throw new Error('Account not found');
      userId   = r.rows[0].id;
      pinHash  = r.rows[0].pin_hash;
      userType = 'teacher';
    }

    if (!pinHash) throw new Error('PIN not set. Please login with OTP first.');

    const valid = await bcrypt.compare(pin, pinHash);
    if (!valid) throw new Error('Incorrect PIN. Please try again.');

    const role        = userType === 'teacher' ? 'teacher' as const : 'parent' as const;
    const accessToken = generateAccessToken({ sub: userId, school_id: schoolId, role, user_type: userType });
    const { token: refreshToken, jti: refreshJti } = generateRefreshToken(userId, schoolId, role, userType);
    await redisClient.setEx(RedisKeys.refreshToken(userId, refreshJti), 30 * 24 * 3600, '1');

    return { accessToken, refreshToken, userId, userType, schoolId, pin_set: true };
  } finally { client.release(); }
}

export async function refreshAccessToken(refreshToken: string) {
  const payload = verifyRefreshToken(refreshToken);
  const exists  = await redisClient.get(RedisKeys.refreshToken(payload.sub, payload.jti));
  if (!exists) throw new Error('Refresh token revoked or expired');

  await redisClient.del(RedisKeys.refreshToken(payload.sub, payload.jti));
  const { token: newRefresh, jti: newJti } = generateRefreshToken(payload.sub, payload.school_id, payload.role, payload.user_type);
  await redisClient.setEx(RedisKeys.refreshToken(payload.sub, newJti), 30 * 24 * 3600, '1');

  const newAccess = generateAccessToken({
    sub: payload.sub, school_id: payload.school_id,
    role: payload.role, user_type: payload.user_type
  });
  return { accessToken: newAccess, refreshToken: newRefresh };
}
