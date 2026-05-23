# School Management System

## Stack
- **Backend**: Node.js + TypeScript + Express (port 3000)
- **Database**: PostgreSQL 16 (port 5433) — note: non-standard port to avoid conflicts
- **Cache**: Redis 7 (port 6380) — note: non-standard port
- **Frontend**: Flutter (web: Chrome, mobile: Android emulator)
- **DB Admin**: pgAdmin 4 (port 5050)

---

## Quick Start

### 1. Start Docker services
```bash
cd docker
docker compose up -d
```
- PostgreSQL: `localhost:5433`
- Redis: `localhost:6380`
- pgAdmin: http://localhost:5050 → `admin@sghk.com` / `admin123`

Check containers are running:
```bash
docker ps
```
Expected containers: `school_mgmt_db`, `school_mgmt_redis`, `school_mgmt_pgadmin`

### 2. Run migrations
In pgAdmin, connect to `school_mgmt` and run in order:
```
backend/migrations/001_core_schema.sql
backend/migrations/002_academic_schema.sql
```

Connect to psql directly:
```bash
docker exec -it school_mgmt_db psql -U school_admin -d school_mgmt
```

### 3. Start backend API
```bash
cd backend
npm run dev
```
- API: http://localhost:3000/api/v1
- Health: http://localhost:3000/api/v1/health

Backend auto-restarts on file changes via `tsx watch`.

### 4. Run Flutter app

**On Chrome (web):**
```bash
cd mobile
flutter run -d chrome
```

**On Android emulator:**
```bash
flutter emulators --launch Pixel_8   # wait ~60s for boot
flutter run
```

> ⚠️ For Chrome/web: `api_constants.dart` must use `http://localhost:3000/api/v1`
> ⚠️ For Android emulator: use `http://10.0.2.2:3000/api/v1`

---

## Project Structure
```
school-mgmt/
├── docker/
│   └── docker-compose.yml          # PostgreSQL, Redis, pgAdmin
├── backend/
│   ├── src/
│   │   ├── config/
│   │   │   ├── database.ts         # adminPool + appPool (row-level security)
│   │   │   └── redis.ts            # Redis client + key helpers
│   │   ├── controllers/
│   │   │   ├── auth.controller.ts
│   │   │   └── parent.controller.ts
│   │   ├── middleware/
│   │   │   └── auth.ts             # JWT authenticate + requireRole
│   │   ├── routes/
│   │   │   ├── index.ts
│   │   │   └── auth.routes.ts
│   │   ├── services/
│   │   │   ├── auth.service.ts     # OTP request/verify, JWT generation
│   │   │   └── sms.service.ts      # Twilio (prints to console in dev)
│   │   └── utils/
│   │       ├── jwt.ts
│   │       ├── otp.ts              # bcrypt hash/verify
│   │       └── response.ts
│   ├── migrations/
│   └── .env                        # secrets — never commit this
└── mobile/
    └── lib/
        ├── core/
        │   ├── constants/
        │   │   ├── api_constants.dart   # all API endpoint paths
        │   │   ├── app_colors.dart
        │   │   └── app_router.dart      # GoRouter with auth redirect
        │   ├── network/
        │   │   └── api_client.dart      # Dio + JWT interceptor
        │   └── storage/
        │       └── secure_storage.dart  # flutter_secure_storage
        └── features/
            ├── auth/presentation/
            │   ├── providers/auth_provider.dart
            │   └── screens/
            │       ├── login_screen.dart   # 10-digit mobile + +91 prefix
            │       └── otp_screen.dart     # 6-digit OTP + 60s timer
            └── dashboard/presentation/
                └── screens/dashboard_screen.dart
```

---

## Database

### Connection details
| Field    | Value              |
|----------|--------------------|
| Host     | localhost          |
| Port     | **5433**           |
| Database | school_mgmt        |
| User     | school_admin       |
| Password | localdev_password_change_in_prod |

### Key tables
| Table | Description |
|-------|-------------|
| schools | One row per school, identified by `subdomain` |
| parents | Mobile number is unique per school |
| students | Must have `class_id` (not null) |
| parent_students | Many-to-many join between parents and students |
| classes | Must have `name` AND `section` (not null) |
| academic_years | Required before creating classes |
| teachers | Login via mobile, no admission number needed |
| device_tokens | FCM push notification tokens |

### Redis key format
```
otp:{schoolId}:{mobile}           → OTP hash + metadata (5 min TTL)
otp_attempts:{schoolId}:{mobile}  → rate limit counter (10 min TTL)
refresh:{userId}:{jti}            → refresh token whitelist (30 days)
blacklist:{jti}                   → logged out access tokens (15 min TTL)
```

---

## Auth Flow
1. User enters school subdomain + 10-digit mobile + admission number
2. App prepends `+91` → sends `+91XXXXXXXXXX` to backend
3. Backend looks up school by subdomain → finds parent via mobile + admission_no JOIN
4. Generates 6-digit OTP → bcrypt hashes it → stores in Redis
5. In dev mode: OTP printed to backend console (no SMS sent)
6. User enters OTP → backend verifies hash → returns JWT access + refresh tokens
7. Tokens stored in flutter_secure_storage on device

---

## Test Data (current dev setup)
| Field | Value |
|-------|-------|
| School subdomain | demo |
| Parent mobile (enter in app) | 8377001181 (app adds +91) |
| Admission number | 2024-001 |
| Parent name | Gurpreet Singh |
| Student name | Arjun Sharma |
| Class | Class 1 - A |

---

## API Endpoints
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /auth/request-otp | No | Send OTP to mobile |
| POST | /auth/verify-otp | No | Verify OTP, get tokens |
| POST | /auth/refresh | No | Refresh access token |
| POST | /auth/logout | Yes | Invalidate tokens |
| GET | /auth/me | Yes | Get current user |
| GET | /parent/dashboard | Yes | Parent info + students |
| GET | /health | No | Server health check |

---

## Common Issues & Fixes

| Problem | Fix |
|---------|-----|
| `adb` not recognized | `$env:PATH += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"` |
| Emulator stuck offline | `adb emu kill` then relaunch |
| OTP "expired or not requested" | Check mobile has `+91` prefix, check Redis key matches |
| CORS error on Chrome | Move `app.options('*', cors())` before `app.use(cors(...))` |
| Flutter using old API URL | Press Shift+R for full restart after changing constants |
| `tsx` not working with Node v24 | Use `npx tsx` or downgrade Node |
| Docker port conflict | Change port mapping in docker-compose.yml |
