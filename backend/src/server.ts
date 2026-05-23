import 'express-async-errors';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
dotenv.config();
import { checkDbConnection } from './config/database';
import { connectRedis } from './config/redis';
import router from './routes';

const app = express();
const PORT = parseInt(process.env.PORT || '3000');

// Trust Railway's reverse proxy so rate-limiting and IP detection work correctly
app.set('trust proxy', 1);

app.use(helmet({
  crossOriginResourcePolicy: false,
  contentSecurityPolicy: false,
}));
// In production restrict to the actual Flutter web domain; in dev allow all origins
// Mobile app sends no Origin header — allow all origins
const allowedOrigins = true;

app.options('*', cors());
app.use(cors({
  origin: allowedOrigins,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(rateLimit({ windowMs: 60000, max: 1000, standardHeaders: true, legacyHeaders: false }));
app.use('/api/v1', router);
app.use((_req, res) => res.status(404).json({ success: false, error: 'Route not found' }));
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled:', err.message);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

async function start() {
  try {
    await checkDbConnection();
    await connectRedis();
    app.listen(PORT, () => {
      console.log('\n  Server -> http://localhost:' + PORT + '/api/v1');
      console.log('  Health -> http://localhost:' + PORT + '/api/v1/health\n');
    });
  } catch (err) { console.error('Startup failed:', err); process.exit(1); }
}
start();