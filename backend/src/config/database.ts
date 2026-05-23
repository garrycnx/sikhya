import { Pool, PoolClient } from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const isProd = process.env.NODE_ENV === 'production';
const sslConfig = isProd ? { rejectUnauthorized: false } : false;

// Railway provides DATABASE_URL; local dev uses individual vars
export const adminPool = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL, ssl: sslConfig,
        min: parseInt(process.env.DB_POOL_MIN || '2'), max: parseInt(process.env.DB_POOL_MAX || '10'),
        idleTimeoutMillis: 30000, connectionTimeoutMillis: 5000 }
    : { host: process.env.DB_HOST || 'localhost', port: parseInt(process.env.DB_PORT || '5432'),
        database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASSWORD,
        min: parseInt(process.env.DB_POOL_MIN || '2'), max: parseInt(process.env.DB_POOL_MAX || '10'),
        idleTimeoutMillis: 30000, connectionTimeoutMillis: 5000, ssl: sslConfig }
);

// app_user pool always uses individual vars (separate limited-privilege user)
export const appPool = new Pool({
  host:     process.env.DB_HOST     || (process.env.DATABASE_URL ? new URL(process.env.DATABASE_URL).hostname : 'localhost'),
  port:     parseInt(process.env.DB_PORT || (process.env.DATABASE_URL ? new URL(process.env.DATABASE_URL).port : '5432')),
  database: process.env.DB_NAME     || (process.env.DATABASE_URL ? new URL(process.env.DATABASE_URL).pathname.slice(1) : ''),
  user:     process.env.DB_APP_USER,
  password: process.env.DB_APP_PASSWORD,
  min: 2, max: 20, idleTimeoutMillis: 30000, connectionTimeoutMillis: 5000, ssl: sslConfig,
});

export async function getSchoolClient(schoolId: string): Promise<PoolClient> {
  const client = await appPool.connect();
  await client.query("SET app.current_school_id = '" + schoolId + "'");
  return client;
}

export async function queryWithSchool<T = unknown>(schoolId: string, query: string, params?: unknown[]): Promise<T[]> {
  const client = await getSchoolClient(schoolId);
  try { const r = await client.query(query, params); return r.rows as T[]; }
  finally { client.release(); }
}

export async function transactionWithSchool<T>(schoolId: string, fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await getSchoolClient(schoolId);
  try {
    await client.query('BEGIN'); const result = await fn(client); await client.query('COMMIT'); return result;
  } catch (err) { await client.query('ROLLBACK'); throw err; }
  finally { client.release(); }
}

export async function checkDbConnection(): Promise<void> {
  const client = await adminPool.connect();
  try { await client.query('SELECT 1'); console.log('OK PostgreSQL connected'); }
  finally { client.release(); }
}