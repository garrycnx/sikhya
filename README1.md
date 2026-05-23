# School Management App — Complete Project Reference Guide

> This document is your go-to reference for understanding, maintaining, and modifying every part of this project.
> Use Ctrl+F to search for what you want to change.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Folder Structure — Full Tree](#2-folder-structure--full-tree)
3. [Mobile App — File-by-File Guide](#3-mobile-app--file-by-file-guide)
4. [Backend — File-by-File Guide](#4-backend--file-by-file-guide)
5. [Common Changes — Quick Reference](#5-common-changes--quick-reference)
6. [Adding New Features](#6-adding-new-features)
7. [API Endpoints Reference](#7-api-endpoints-reference)
8. [Environment & Configuration](#8-environment--configuration)
9. [Running the Project](#9-running-the-project)
10. [Deployment Checklist](#10-deployment-checklist)

---

## 1. Project Overview

This is a School Management System with:
- **Flutter mobile app** (Android + Web) for Parents and Teachers
- **Node.js/Express backend** with PostgreSQL database
- **OTP-based login** (no passwords — mobile number + OTP)
- **Role-based access** — Teacher sees teacher screens, Parent sees parent screens

```
school-mgmt/
├── mobile/        ← Flutter app (Android + Web)
├── backend/       ← Node.js + Express + PostgreSQL API
└── docker/        ← Docker setup files
```

---

## 2. Folder Structure — Full Tree

### Mobile App
```
mobile/
├── pubspec.yaml                          ← Dependencies list (add packages here)
├── android/
│   ├── app/
│   │   ├── build.gradle.kts              ← App ID, version, signing config
│   │   └── src/main/
│   │       ├── AndroidManifest.xml       ← App name, permissions
│   │       └── kotlin/com/edusync/
│   │           └── schoolapp/
│   │               └── MainActivity.kt  ← Android entry point (don't touch)
│   └── key.properties                   ← Signing credentials (never commit)
└── lib/
    ├── main.dart                         ← App entry point
    ├── app.dart                          ← Theme, colors, fonts, router setup
    └── core/
    │   ├── constants/
    │   │   ├── app_colors.dart           ← ALL color values for the entire app
    │   │   ├── api_constants.dart        ← ALL API URLs and endpoint paths
    │   │   └── app_router.dart           ← All navigation routes and redirects
    │   ├── network/
    │   │   └── api_client.dart           ← HTTP client (Dio), token handling
    │   ├── storage/
    │   │   └── secure_storage.dart       ← Saves/reads token, user type
    │   └── widgets/
    │       └── skeleton_loader.dart      ← Loading placeholder animation
    └── features/
        ├── auth/
        │   └── presentation/
        │       ├── providers/
        │       │   └── auth_provider.dart    ← Login/OTP logic + state
        │       └── screens/
        │           ├── login_screen.dart     ← Login page UI
        │           └── otp_screen.dart       ← OTP entry page UI
        ├── parent/
        │   └── presentation/
        │       └── screens/
        │           ├── parent_app_shell.dart         ← Parent home (5-tab nav)
        │           ├── parent_attendance_screen.dart ← Attendance calendar
        │           ├── parent_homework_screen.dart   ← Homework table
        │           ├── parent_marks_screen.dart      ← Marks/results view
        │           ├── parent_timetable_screen.dart  ← Class timetable
        │           ├── parent_announcements_screen.dart ← School notices
        │           └── parent_profile_screen.dart    ← Parent profile
        └── teacher/
            └── presentation/
                └── screens/
                    ├── teacher_app_shell.dart          ← Teacher home (4-tab nav)
                    ├── teacher_dashboard_screen.dart   ← Teacher home tab
                    ├── teacher_homework_list_screen.dart ← View all homework
                    ├── add_homework_screen.dart        ← Add new homework
                    ├── attendance_screen.dart          ← Mark attendance
                    ├── class_students_screen.dart      ← Student list for class
                    ├── add_edit_student_screen.dart    ← Add/edit student
                    ├── student_profile_screen.dart     ← Student detail view
                    ├── add_marks_screen.dart           ← Enter exam marks
                    ├── timetable_screen.dart           ← Manage timetable
                    ├── notifications_list_screen.dart  ← View announcements
                    ├── send_notification_screen.dart   ← Send announcement
                    ├── teacher_profile_screen.dart     ← Teacher profile
                    └── teacher_homework_list_screen.dart
```

### Backend
```
backend/
├── .env                          ← Environment variables (DB url, JWT secret, SMS key)
├── package.json                  ← Node.js dependencies
└── src/
    ├── server.ts                 ← Express app startup, CORS, middleware
    ├── config/
    │   ├── database.ts           ← PostgreSQL connection pool setup
    │   └── redis.ts              ← Redis connection (for OTP storage)
    ├── routes/
    │   ├── index.ts              ← Combines all routes under /api/v1
    │   ├── auth.routes.ts        ← /auth/* endpoints
    │   ├── admin.routes.ts       ← /admin/* endpoints
    │   └── teacher.routes.ts     ← /teacher/* endpoints
    ├── controllers/
    │   ├── auth.controller.ts    ← Login, OTP verify, token refresh
    │   ├── teacher.controller.ts ← All teacher actions
    │   ├── parent.controller.ts  ← All parent data views
    │   └── admin.controller.ts   ← Admin management
    ├── middleware/
    │   └── auth.ts               ← JWT verification, role checking
    ├── services/
    │   ├── auth.service.ts       ← OTP generation, JWT creation
    │   └── sms.service.ts        ← SMS gateway (sends OTP to phone)
    └── utils/
        ├── jwt.ts                ← Token encode/decode helpers
        ├── otp.ts                ← OTP generate/validate
        └── response.ts           ← Standard API response format
```

---

## 3. Mobile App — File-by-File Guide

---

### `lib/main.dart`
**What it does:** Starts the app. Clears any saved tokens on launch (so users must login fresh). Wraps everything in Riverpod's `ProviderScope`.

**When to edit:**
- Change app startup behavior
- Add initialization code (e.g., Firebase, notifications)

---

### `lib/app.dart`
**What it does:** Defines the entire visual theme — fonts, colors, button styles, input field styles, card styles, dialog styles. Also sets up the router.

**When to edit:**

| You want to change | What to look for in this file |
|--------------------|-------------------------------|
| Font family | `GoogleFonts.interTextTheme` → change `inter` to another font |
| Default text sizes | `bodyLarge`, `bodyMedium`, `titleMedium` etc. |
| Button shape/size | `elevatedButtonTheme` → `minimumSize`, `shape` |
| Card border radius | `cardTheme` → `BorderRadius.circular(14)` |
| Input field style | `inputDecorationTheme` → border, fill color, padding |
| App background color | `scaffoldBackgroundColor: AppColors.background` |
| AppBar style | `appBarTheme` → `backgroundColor`, `titleTextStyle` |
| Bottom sheet style | `bottomSheetTheme` |

---

### `lib/core/constants/app_colors.dart`
**What it does:** Stores every color used in the app as named constants.

**When to edit:** Change ANY color in the app.

```dart
// Key colors and where they appear:
primary        = Color(0xFF1565C0)  ← AppBar, buttons, links, active states
background     = Color(0xFFF4F6FB)  ← Screen background (grey-white)
surface        = Color(0xFFFFFFFF)  ← Cards, white panels
textPrimary    = Color(0xFF0F172A)  ← All main text (near black)
textSecondary  = Color(0xFF64748B)  ← Subtitles, hints (grey)
textMuted      = Color(0xFF94A3B8)  ← Placeholder text (light grey)
border         = Color(0xFFE2E8F0)  ← Card borders, dividers
danger         = Color(0xFFDC2626)  ← Error messages, delete buttons
success        = Color(0xFF16A34A)  ← Present/success states
warning        = Color(0xFFF59E0B)  ← Homework due badge
attendance     = Color(0xFF0EA5E9)  ← Attendance feature color
marks          = Color(0xFF16A34A)  ← Marks feature color
homework       = Color(0xFFF59E0B)  ← Homework feature color
timetable      = Color(0xFF8B5CF6)  ← Timetable feature color
```

**Example — change the main blue to green:**
```dart
static const primary = Color(0xFF16A34A);  // was blue, now green
```

---

### `lib/core/constants/api_constants.dart`
**What it does:** Stores the backend server address and every API endpoint path.

**When to edit:**
- **Change server URL** (most important before production):
```dart
static const baseUrl = 'http://YOUR_SERVER_IP:3000/api/v1';
// For production: 'https://api.yourschool.com/api/v1'
```
- Add a new endpoint when you add a new backend feature

**All endpoints defined here:**
```
Auth:     /auth/request-otp, /auth/verify-otp, /auth/refresh, /auth/logout
Parent:   /parent/dashboard, /parent/attendance, /parent/homework,
          /parent/timetable, /parent/marks, /parent/announcements
Teacher:  /teacher/dashboard, /teacher/classes, /teacher/attendance,
          /teacher/homework, /teacher/marks, /teacher/timetable,
          /teacher/students, /teacher/notifications
```

---

### `lib/core/constants/app_router.dart`
**What it does:** Defines every screen route (URL path) and which screen widget to show. Also handles redirecting unauthenticated users to login.

**Route map:**
```
/login              → LoginScreen
/otp                → OtpScreen
/dashboard          → ParentAppShell (parent home)
/teacher-dashboard  → TeacherAppShell (teacher home)
/parent/attendance  → ParentAttendanceScreen
/parent/homework    → ParentHomeworkScreen
/parent/marks       → ParentMarksScreen
/parent/timetable   → ParentTimetableScreen
/parent/announcements → ParentAnnouncementsScreen
```

**When to edit:**
- Add a new screen → add a new `GoRoute` entry
- Change which screen a route shows → change the `builder` return
- Change redirect logic → edit the `redirect` function

---

### `lib/core/network/api_client.dart`
**What it does:** All HTTP requests go through this. Automatically adds the auth token to every request header. If token expires, automatically tries to refresh it. If refresh fails, redirects to login.

**When to edit:**
- Change request timeout
- Add global request/response logging
- Change token refresh behavior

---

### `lib/core/storage/secure_storage.dart`
**What it does:** Saves and reads sensitive data (auth token, user type) encrypted on the device.

**Stores:**
- `auth_token` — JWT token for API calls
- `refresh_token` — Used to get new auth token
- `user_type` — `"teacher"` or `"parent"` (decides which home screen to show after login)

---

### `lib/features/auth/presentation/screens/login_screen.dart`
**What it does:** The animated login page. Has school ID, mobile number, admission number fields. Toggle between Parent and Teacher mode.

**When to edit:**

| Change | Where in file |
|--------|---------------|
| App name "School ERP" | Search `'School ERP'` → line ~206 |
| Subtitle "Connecting Schools..." | Search `'Connecting Schools'` |
| Floating icons (book, pencil etc.) | `_FloatIcon` calls in `_HeroSection` |
| Hero background gradient | `LinearGradient` in `_HeroSection` — colors list |
| Hero height | `height: 270` in `_HeroSection` |
| Form card styles | `_FormCard` widget |
| Toggle button labels | `_ToggleBtn` widget |
| Input field style | `_Field` widget at bottom of file |
| Pre-filled school ID | `TextEditingController(text: 'demo')` → change `'demo'` |

---

### `lib/features/auth/presentation/screens/otp_screen.dart`
**What it does:** OTP entry screen shown after login. Has 6 individual digit boxes, countdown timer, resend button.

**When to edit:**
- Change OTP countdown time: `_secs = 60` in `_startTimer()` → change `60`
- Change box style: `_OtpBoxes` widget → box width/height/border
- Change hero background: `_HeroSection` gradient colors

---

### `lib/features/auth/presentation/providers/auth_provider.dart`
**What it does:** Contains the logic for requesting OTP and verifying OTP. Stores loading/error state.

**When to edit:**
- Change what happens after successful login
- Add extra validation before OTP request

---

### `lib/features/parent/presentation/screens/parent_app_shell.dart`
**What it does:** The parent's main home screen with 5-tab bottom navigation. Contains the dashboard home tab, and navigation to all other parent screens.

**Key sections:**

| Section | What it shows |
|---------|---------------|
| `_HomeTab` | Dark navy header, child info strip, Quick Links row, Action Cards grid |
| `_ChildStrip` | Child's name, class, today's attendance status, homework count |
| `_AnnouncementTicker` | Yellow banner showing announcement count |
| Quick Links row | 5 circular icon buttons (Attendance, Marks, Homework, Timetable, Announcements) |
| Action Cards grid | 6 gradient cards (same as teacher interface) |
| `_MoreTab` | Settings-style list (Profile, Sign Out etc.) |
| `_ShellSkeleton` | Loading state shown while dashboard data loads |

**When to edit:**

| Change | Where |
|--------|-------|
| Quick Links icons/labels | `_CircleLink` widgets in `_HomeTab` |
| Action card colors | `_ActionCard` gradient colors in `_HomeTab` |
| Action card icons/labels | `_ActionCard` calls — icon and label parameters |
| Bottom nav tabs | `_BottomNav` widget — tabs list |
| Bottom nav color | `const _kNavy = Color(0xFF1A237E)` at top of file |
| Dashboard API data | `parentDashboardProvider` FutureProvider |

---

### `lib/features/parent/presentation/screens/parent_attendance_screen.dart`
**What it does:** Shows a monthly attendance calendar with stats row (percentage, present, absent, school days).

**When to edit:**

| Change | Where |
|--------|-------|
| Calendar cell colors | `_CalCell._bgColor` getter — switch cases |
| Stats row icons/colors | `_StatCol` widgets in `_buildBody` |
| Legend items | `_LegendItem` list at bottom of `_buildBody` |
| Month navigation | `_prevMonth()`, `_nextMonth()` methods |

---

### `lib/features/parent/presentation/screens/parent_homework_screen.dart`
**What it does:** Shows homework in a date-grouped table (same style as teacher). Columns: #, Subject, Assignment/Notes.

**When to edit:**
- Table header colors: `_accentColor` getter in `_DateTable`
- TODAY/OVERDUE badge colors: `_Badge` widget
- Column widths: `SizedBox(width: 86)` for Subject column

---

### `lib/features/parent/presentation/screens/parent_marks_screen.dart`
**What it does:** Shows student exam marks grouped by exam name.

---

### `lib/features/parent/presentation/screens/parent_timetable_screen.dart`
**What it does:** Shows weekly class timetable with day columns and period rows.

---

### `lib/features/parent/presentation/screens/parent_profile_screen.dart`
**What it does:** Parent profile with name, contact info, linked children, logout button. Uses a `SliverAppBar` with expandable header.

---

### `lib/features/teacher/presentation/screens/teacher_app_shell.dart`
**What it does:** Teacher's home with 4-tab bottom navigation: Dashboard | Homework | Classes | Profile.

**When to edit:**
- Add/remove tabs: `_tabs` list in `TeacherAppShell`
- Change tab icons/labels: `BottomNavigationBarItem` widgets
- Dashboard tab: `_DashboardTabWrapper`
- Classes tab: `_ClassesTab`

---

### `lib/features/teacher/presentation/screens/teacher_dashboard_screen.dart`
**What it does:** Teacher's main dashboard — shows class list with student counts and quick action cards.

**Key sections:**
- Gradient header (dark navy) with school name and teacher name
- Quick action cards: Attendance, Homework, Marks, Timetable, Students, Notifications
- Class list with expandable student counts

**When to edit:**
- Action card colors: `_palette` list in `_ClassesTab`
- Header gradient: `LinearGradient` in `_buildHeader`
- Action card labels/icons: `_ActionCard` calls

---

### `lib/features/teacher/presentation/screens/attendance_screen.dart`
**What it does:** Teacher marks daily attendance for a class. Has date picker, mark-all buttons, and individual student P/A/L toggles.

---

### `lib/features/teacher/presentation/screens/add_homework_screen.dart`
**What it does:** Form to assign homework — select class, subject (from list), title, description, due date.

**When to edit:**
- Add/remove subjects: `_subjectList` constant at top of file
- Change due date picker: `showDatePicker` call

---

### `lib/features/teacher/presentation/screens/add_marks_screen.dart`
**What it does:** Teacher enters marks for each student per subject. Has exam name, max marks, marks obtained, and remarks columns.

---

### `lib/features/teacher/presentation/screens/timetable_screen.dart`
**What it does:** Teacher views and manages the weekly class timetable. Can add/edit periods for each day.

---

### `lib/features/teacher/presentation/screens/class_students_screen.dart`
**What it does:** Shows list of all students in a class. Can search, view profile, transfer student to another class.

---

### `lib/features/teacher/presentation/screens/add_edit_student_screen.dart`
**What it does:** Form to add a new student or edit existing student details (name, admission no., roll no., DOB, address, emergency contact, parent info).

---

### `lib/features/teacher/presentation/screens/student_profile_screen.dart`
**What it does:** Full student detail view — attendance summary, marks history, homework, transfer option.

---

### `lib/features/teacher/presentation/screens/notifications_list_screen.dart`
**What it does:** Lists all announcements sent by this school. Can create new announcements.

---

### `lib/features/teacher/presentation/screens/send_notification_screen.dart`
**What it does:** Form to send a new announcement — title, message, target (all/parents/students), optional class filter.

---

### `lib/features/teacher/presentation/screens/teacher_profile_screen.dart`
**What it does:** Teacher profile with stats, class list, contact info, logout.

---

### `lib/core/widgets/skeleton_loader.dart`
**What it does:** Shimmer/pulse loading animation used as placeholder while data loads.

**Two widgets:**
- `SkeletonLoader(width, height, borderRadius)` — single bar
- `SkeletonCard(child)` — white card wrapper with shadow

---

## 4. Backend — File-by-File Guide

---

### `src/server.ts`
**What it does:** Starts Express server, sets up CORS (allows mobile app to connect), JSON parsing, rate limiting, mounts all routes.

**When to edit:**
- Change allowed CORS origins (which domains can call the API)
- Change port number (default 3000)
- Add new global middleware

---

### `src/config/database.ts`
**What it does:** Creates PostgreSQL connection pool. Every database query uses `appPool.connect()`.

**When to edit:**
- Database connection settings (usually via .env variables, not this file directly)

---

### `src/config/redis.ts`
**What it does:** Connects to Redis. Used to temporarily store OTP codes (they expire after 5 minutes).

---

### `src/routes/index.ts`
**What it does:** The main router. Combines all sub-routes under `/api/v1`. Also defines the 7 parent endpoints directly.

**Parent routes defined here:**
```
GET  /parent/dashboard       → getParentDashboard
GET  /parent/homework        → getParentHomework
GET  /parent/timetable       → getParentTimetable
GET  /parent/attendance      → getParentAttendance
GET  /parent/marks           → getParentMarks
GET  /parent/announcements   → getParentAnnouncementsList
POST /parent/announcements/:id/dismiss → dismissAnnouncement
```

---

### `src/routes/auth.routes.ts`
**Authentication endpoints:**
```
POST /auth/request-otp   → Send OTP to mobile number
POST /auth/verify-otp    → Verify OTP, return JWT tokens
POST /auth/refresh       → Refresh expired token
POST /auth/logout        → Clear token
GET  /auth/me            → Get current user info
```

---

### `src/routes/teacher.routes.ts`
**All teacher endpoints (56 total). Key groups:**
```
Dashboard:    GET  /teacher/dashboard
Classes:      GET  /teacher/classes, GET /teacher/all-classes
Students:     GET/POST/PUT/DELETE /teacher/classes/:id/students
Attendance:   GET/POST /teacher/attendance
Homework:     GET/POST/DELETE /teacher/homework
Marks:        GET/POST /teacher/marks
Timetable:    GET/POST/DELETE /teacher/timetable
Notifications: GET/POST /teacher/notifications
```

---

### `src/controllers/auth.controller.ts`
**What it does:** Handles OTP request (checks school exists, sends SMS), OTP verification (validates code, creates JWT), token refresh, logout.

**When to edit:**
- Change OTP expiry time: look for Redis `setex` call
- Change JWT expiry: look for `generateToken` calls
- Add extra validation on login (e.g., block certain numbers)

---

### `src/controllers/teacher.controller.ts`
**What it does:** Handles all 56 teacher API calls. Each exported function = one API endpoint.

**When to edit:** When you want to change what data the teacher sees or what they can do.

---

### `src/controllers/parent.controller.ts`
**What it does:** Handles all parent data fetching. Key function: `getParentDashboard` — the big SQL query that loads school name, student info, today's attendance, monthly attendance %, and homework count in one call.

**When to edit:**
- Change what shows on parent dashboard: edit the SQL in `getParentDashboard`
- Change attendance calculation logic: `getParentAttendance`
- Change how homework is filtered: `getParentHomework` (currently shows last 3 days + future)

---

### `src/middleware/auth.ts`
**What it does:** Checks JWT token on every protected API call. Extracts `user.id`, `user.school_id`, `user.role` and attaches to the request so controllers can use them.

**Role values:** `"teacher"`, `"parent"`, `"school_admin"`, `"super_admin"`

---

### `src/services/sms.service.ts`
**What it does:** Sends OTP SMS to a phone number via your SMS gateway provider.

**When to edit:**
- Change SMS provider (MSG91, Fast2SMS, Textlocal)
- Change OTP message text
- Add SMS delivery logging

---

### `src/utils/response.ts`
**What it does:** Standard format for all API responses.

```typescript
sendSuccess(res, data)  → { success: true, data: ... }
sendError(res, message, statusCode) → { success: false, error: "..." }
```

---

## 5. Common Changes — Quick Reference

### Change the App's Primary Blue Color
**File:** `mobile/lib/core/constants/app_colors.dart`
```dart
static const primary = Color(0xFF1565C0);  // Change this hex value
```
This automatically updates: AppBar, buttons, active tab indicator, links, focus borders.

---

### Change the App Name on Login Screen
**File:** `mobile/lib/features/auth/presentation/screens/login_screen.dart`
Search for `'School ERP'` → change to your school name.

---

### Change App Name on Phone (launcher name)
**File:** `mobile/android/app/src/main/AndroidManifest.xml`
```xml
android:label="School App"   ← Change this
```

---

### Change the Backend Server URL
**File:** `mobile/lib/core/constants/api_constants.dart`
```dart
static const baseUrl = 'http://192.168.1.69:3000/api/v1';
// Change to: 'https://your-domain.com/api/v1'
```

---

### Add a New Subject to Homework Dropdown
**File:** `mobile/lib/features/teacher/presentation/screens/add_homework_screen.dart`
```dart
const _subjectList = [
  'Mathematics',
  'English',
  'Your New Subject',   // ← Add here
  ...
];
```

---

### Change OTP Timer Duration
**File:** `mobile/lib/features/auth/presentation/screens/otp_screen.dart`
```dart
setState(() { _secs = 60; ... });  // Change 60 to any seconds
```

---

### Change Attendance Status Colors (Calendar)
**File:** `mobile/lib/features/parent/presentation/screens/parent_attendance_screen.dart`
```dart
Color get _bgColor {
  switch (status) {
    case 'present':  return const Color(0xFFE8F5E9);  // Light green
    case 'absent':   return const Color(0xFFFFEBEE);  // Light red
    case 'late':     return const Color(0xFFFFF3E0);  // Light orange
    ...
  }
}
```

---

### Change Parent Dashboard Quick Links
**File:** `mobile/lib/features/parent/presentation/screens/parent_app_shell.dart`
Search for `_CircleLink` — edit the icon, label, and `onTap` action for each link.

---

### Change Parent Action Card Colors
**File:** `mobile/lib/features/parent/presentation/screens/parent_app_shell.dart`
Search for `_ActionCard` — each card has a `gradient` with two `Color` values.

---

### Change Teacher Dashboard Action Card Colors
**File:** `mobile/lib/features/teacher/presentation/screens/teacher_app_shell.dart`
Search for `static const _palette` — list of colors, one per card.

---

### Change What Homework the Parent Sees (date range)
**File:** `backend/src/controllers/parent.controller.ts` → `getParentHomework`
```typescript
AND h.due_date >= CURRENT_DATE - INTERVAL '3 days'
// Change '3 days' to '7 days' to show a week of past homework
```

---

### Change Auto-Absent Logic for Attendance
**File:** `backend/src/controllers/parent.controller.ts` → `getParentAttendance`
```typescript
else if (isPast) status = 'absent';  // Remove this line to not auto-mark absent
```

---

### Change JWT Token Expiry
**File:** `backend/src/services/auth.service.ts`
Search for token expiry duration (e.g., `'7d'`, `'30d'`) and change it.

---

### Change OTP Expiry Time
**File:** `backend/src/controllers/auth.controller.ts`
Search for Redis `setex` call — second argument is expiry in seconds.
```typescript
await redis.setex(key, 300, otp);  // 300 = 5 minutes
```

---

### Add a New Screen (Example: Fee Screen for Parents)
**Step 1** — Create the screen file:
`mobile/lib/features/parent/presentation/screens/parent_fees_screen.dart`

**Step 2** — Add route in router:
`mobile/lib/core/constants/app_router.dart`
```dart
GoRoute(
  path: '/parent/fees',
  builder: (_, __) => const ParentFeesScreen(),
),
```

**Step 3** — Add backend endpoint in:
`backend/src/routes/index.ts`
```typescript
router.get('/parent/fees', authenticate, getParentFees);
```

**Step 4** — Add controller function in:
`backend/src/controllers/parent.controller.ts`

**Step 5** — Add API constant:
`mobile/lib/core/constants/api_constants.dart`
```dart
static const parentFees = '$baseUrl/parent/fees';
```

---

## 6. Adding New Features

### Add a New Bottom Nav Tab (Parent)
**File:** `mobile/lib/features/parent/presentation/screens/parent_app_shell.dart`

1. Add the screen to the `IndexedStack` children list
2. Add a new `_NavBtn` in `_BottomNav`
3. Update the tab count

### Add a New Bottom Nav Tab (Teacher)
**File:** `mobile/lib/features/teacher/presentation/screens/teacher_app_shell.dart`

Same pattern — add to `IndexedStack` and `BottomNavigationBar` items.

### Add Push Notifications
1. Add `firebase_messaging` to `pubspec.yaml`
2. Initialize in `main.dart`
3. Store FCM token in backend when user logs in
4. Add notification sending logic in `sms.service.ts` or new `notification.service.ts`

---

## 7. API Endpoints Reference

### Base URL
```
Development:  http://YOUR_LOCAL_IP:3000/api/v1
Production:   https://api.yourschool.com/api/v1
```

### Auth (no token needed)
```
POST /auth/request-otp    body: { school_subdomain, mobile, admission_no? }
POST /auth/verify-otp     body: { school_subdomain, mobile, otp }
POST /auth/refresh        body: { refresh_token }
POST /auth/logout
GET  /auth/me
```

### Parent (token required, role: parent)
```
GET /parent/dashboard
GET /parent/attendance?student_id=X&month=YYYY-MM
GET /parent/homework?class_id=X
GET /parent/timetable?class_id=X
GET /parent/marks?student_id=X
GET /parent/announcements
POST /parent/announcements/:id/dismiss
```

### Teacher (token required, role: teacher)
```
GET  /teacher/dashboard
GET  /teacher/classes
GET  /teacher/all-classes
GET  /teacher/attendance?class_id=X&date=YYYY-MM-DD
POST /teacher/attendance        body: { class_id, date, records: [...] }
GET  /teacher/homework
POST /teacher/homework          body: { class_id, subject_name, title, due_date }
DELETE /teacher/homework/:id
GET  /teacher/marks?class_id=X
POST /teacher/marks             body: { class_id, exam_name, records: [...] }
GET  /teacher/timetable?class_id=X
POST /teacher/timetable
GET  /teacher/classes/:id/students
POST /teacher/classes/:id/students
PUT  /teacher/students/:id
POST /teacher/transfer          body: { student_id, to_class_id }
GET  /teacher/notifications
POST /teacher/notifications
```

---

## 8. Environment & Configuration

### Backend `.env` file
```
# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Redis (for OTP storage)
REDIS_URL=redis://localhost:6379

# JWT
JWT_SECRET=your-very-long-random-secret-key
JWT_REFRESH_SECRET=another-very-long-random-secret
JWT_EXPIRES_IN=7d
JWT_REFRESH_EXPIRES_IN=30d

# SMS Gateway (Fast2SMS example)
SMS_API_KEY=your-fast2sms-api-key
SMS_SENDER_ID=SCHOOL

# Server
PORT=3000
NODE_ENV=production
```

### Mobile App — Change Server URL
**File:** `mobile/lib/core/constants/api_constants.dart`
```dart
static const baseUrl = 'https://your-production-server.com/api/v1';
```

### Android App ID
**File:** `mobile/android/app/build.gradle.kts`
```kotlin
applicationId = "com.edusync.schoolapp"  // Never change after first Play Store upload
```

### App Version
**File:** `mobile/pubspec.yaml`
```yaml
version: 1.0.0+1  # format: displayVersion+buildNumber
# Increment +1 (+2, +3...) every time you upload to Play Store
```

---

## 9. Running the Project

### Start Backend
```bash
cd backend
npm install          # first time only
npm run dev          # development with auto-reload
npm run build        # compile TypeScript
npm start            # production
```

### Start Mobile App (Web/Chrome)
```bash
cd mobile
flutter pub get      # first time only
flutter run -d chrome
```

### Start Mobile App (Physical Android Phone)
```bash
# Enable USB Debugging on phone first
cd mobile
flutter devices      # confirm phone is detected
flutter run          # builds and installs on phone
```

### Build Release APK (for sharing)
```bash
cd mobile
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Build Release AAB (for Play Store)
```bash
cd mobile
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 10. Deployment Checklist

### Before Going Live

- [ ] Change `baseUrl` in `api_constants.dart` to production HTTPS URL
- [ ] Backend is hosted on a real server (not localhost)
- [ ] PostgreSQL database is hosted (not local)
- [ ] `.env` file has production values (real JWT secret, SMS key)
- [ ] `applicationId` is NOT `com.example.*`
- [ ] `key.properties` is configured with your keystore
- [ ] App version incremented in `pubspec.yaml`
- [ ] App name set to school name in `AndroidManifest.xml`
- [ ] `flutter build appbundle --release` succeeds without errors
- [ ] Tested on a real Android phone

### Every Time You Update the App
1. Increment version in `pubspec.yaml`: `1.0.0+1` → `1.0.0+2`
2. `flutter build appbundle --release`
3. Upload new AAB to Google Play Console → Production
4. The `+number` (versionCode) must always go up — Play Store rejects if same or lower

---

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| White text on input fields | `app.dart` → `bodyMedium`/`bodyLarge` must have `color: AppColors.textPrimary` |
| Dropdown text is white | Add `style: TextStyle(color: Color(0xFF0F172A))` and `dropdownColor: Colors.white` to the `DropdownButtonFormField` |
| App crashes with ClassNotFoundException | `MainActivity.kt` package name must match `applicationId` in `build.gradle.kts` |
| API calls fail on phone (but work on web) | Change `localhost` to your computer's IP address in `api_constants.dart` |
| skeleton_loader Library not defined (web) | Run `flutter clean` then `flutter pub get` then restart |
| OTP screen fontSize crash | Never use `fontSize: 0` in TextStyle — use `Opacity(opacity:0)` to hide instead |
| App not updating after code change | Press `R` for hot restart (not just `r` hot reload) for structural changes |
| Play Store rejects upload | Increment `versionCode` (`+1` part in pubspec.yaml version) |
