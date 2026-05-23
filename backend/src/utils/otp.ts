import crypto from 'crypto';
import bcrypt from 'bcryptjs';
export function generateOtp(length = 6): string {
  const max = Math.pow(10, length), min = Math.pow(10, length - 1);
  return (crypto.randomInt(min, max)).toString();
}
export async function hashOtp(otp: string): Promise<string> { return bcrypt.hash(otp, 10); }
export async function verifyOtp(otp: string, hash: string): Promise<boolean> { return bcrypt.compare(otp, hash); }