import { createClient } from 'redis';

// Upstash (production) provides REDIS_URL like rediss://default:pass@host:port
// Local dev uses individual REDIS_HOST / REDIS_PORT / REDIS_PASSWORD vars
const redisClient = process.env.REDIS_URL
  ? createClient({
      url: process.env.REDIS_URL,
      socket: { tls: process.env.REDIS_URL.startsWith('rediss://'),
                reconnectStrategy: (r: number) => r > 10 ? new Error('Redis max retries') : Math.min(r * 100, 3000) },
    })
  : createClient({
      socket: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        reconnectStrategy: (r: number) => r > 10 ? new Error('Redis max retries') : Math.min(r * 100, 3000),
      },
      password: process.env.REDIS_PASSWORD,
    });
redisClient.on('error', (err: Error) => console.error('Redis error:', err));
redisClient.on('connect', () => console.log('OK Redis connected'));
export async function connectRedis() { if (!redisClient.isOpen) await redisClient.connect(); }
export const RedisKeys = {
  otp:           (s: string, m: string) => 'otp:' + s + ':' + m,
  otpAttempts:   (s: string, m: string) => 'otp_attempts:' + s + ':' + m,
  refreshToken:  (u: string, t: string) => 'refresh:' + u + ':' + t,
  blacklist:     (jti: string)          => 'blacklist:' + jti,
  schoolSettings:(s: string)            => 'school_settings:' + s,
};
export default redisClient;