-- Full clean schema for Railway PostgreSQL
-- Uses gen_random_uuid() (built-in PG13+), no uuid-ossp needed

CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- app_user role
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user LOGIN PASSWORD 'sikhya_app_2024';
  END IF;
END; $$;

-- updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── Core tables ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL, subdomain VARCHAR(100) UNIQUE NOT NULL,
  address TEXT, phone VARCHAR(20), email VARCHAR(150), logo_url TEXT,
  plan VARCHAR(30) NOT NULL DEFAULT 'starter' CHECK (plan IN ('starter','growth','enterprise')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE, settings JSONB NOT NULL DEFAULT '{}',
  school_start_time TIME, school_end_time TIME,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS academic_years (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(20) NOT NULL, start_date DATE NOT NULL, end_date DATE NOT NULL,
  is_current BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_current_year ON academic_years(school_id) WHERE is_current = TRUE;

CREATE TABLE IF NOT EXISTS classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  academic_year_id UUID NOT NULL REFERENCES academic_years(id),
  name VARCHAR(20) NOT NULL, section VARCHAR(10) NOT NULL, room_number VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, academic_year_id, name, section)
);

CREATE TABLE IF NOT EXISTS subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL, code VARCHAR(20), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, code)
);
ALTER TABLE subjects DROP CONSTRAINT IF EXISTS uq_subjects_school_name;
ALTER TABLE subjects ADD CONSTRAINT uq_subjects_school_name UNIQUE (school_id, name);

CREATE TABLE IF NOT EXISTS teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  employee_id VARCHAR(50), full_name VARCHAR(200) NOT NULL,
  email VARCHAR(150), mobile VARCHAR(20) NOT NULL, mobile_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE, pin_hash VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, mobile)
);

CREATE TABLE IF NOT EXISTS students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id),
  admission_no VARCHAR(50) NOT NULL, roll_number VARCHAR(20), full_name VARCHAR(200) NOT NULL,
  date_of_birth DATE, gender VARCHAR(10) CHECK (gender IN ('male','female','other')),
  blood_group VARCHAR(5), profile_photo TEXT, address TEXT, emergency_contact VARCHAR(20),
  is_active BOOLEAN NOT NULL DEFAULT TRUE, custom_fields JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, admission_no)
);
CREATE INDEX IF NOT EXISTS idx_students_school ON students(school_id);
CREATE INDEX IF NOT EXISTS idx_students_class  ON students(class_id);
CREATE INDEX IF NOT EXISTS idx_students_name   ON students USING GIN(full_name gin_trgm_ops);

CREATE TABLE IF NOT EXISTS parents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  full_name VARCHAR(200) NOT NULL, mobile VARCHAR(20) NOT NULL, email VARCHAR(150),
  relation VARCHAR(30) DEFAULT 'parent', is_active BOOLEAN NOT NULL DEFAULT TRUE,
  pin_hash VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, mobile)
);

CREATE TABLE IF NOT EXISTS parent_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  is_primary BOOLEAN NOT NULL DEFAULT TRUE, UNIQUE(parent_id, student_id)
);
CREATE INDEX IF NOT EXISTS idx_parent_students_parent  ON parent_students(parent_id);
CREATE INDEX IF NOT EXISTS idx_parent_students_student ON parent_students(student_id);

CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL, user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('parent','teacher','admin')),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL, platform VARCHAR(10) NOT NULL CHECK (platform IN ('android','ios')),
  last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(fcm_token)
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id, user_type);

CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
  full_name VARCHAR(200) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role VARCHAR(30) NOT NULL DEFAULT 'school_admin' CHECK (role IN ('super_admin','school_admin','staff')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE, last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── RLS ───────────────────────────────────────────────────────────────────────

ALTER TABLE classes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE students        ENABLE ROW LEVEL SECURITY;
ALTER TABLE parents         ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS school_isolation ON students;
DROP POLICY IF EXISTS school_isolation ON teachers;
DROP POLICY IF EXISTS school_isolation ON parents;
DROP POLICY IF EXISTS school_isolation ON classes;
DROP POLICY IF EXISTS school_isolation ON parent_students;
DROP POLICY IF EXISTS school_isolation ON device_tokens;

CREATE POLICY school_isolation ON students      USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON teachers      USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON parents       USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON classes       USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON parent_students USING (
  parent_id IN (SELECT id FROM parents WHERE school_id = current_setting('app.current_school_id')::UUID));
CREATE POLICY school_isolation ON device_tokens USING (school_id = current_setting('app.current_school_id')::UUID);

-- ── Triggers ──────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_schools_upd  ON schools;
DROP TRIGGER IF EXISTS trg_teachers_upd ON teachers;
DROP TRIGGER IF EXISTS trg_students_upd ON students;
DROP TRIGGER IF EXISTS trg_parents_upd  ON parents;

CREATE TRIGGER trg_schools_upd  BEFORE UPDATE ON schools  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_teachers_upd BEFORE UPDATE ON teachers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_students_upd BEFORE UPDATE ON students FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_parents_upd  BEFORE UPDATE ON parents  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Academic tables ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id),
  date DATE NOT NULL,
  status VARCHAR(20) NOT NULL CHECK (status IN ('present','absent','late','holiday','half_day')),
  marked_by UUID NOT NULL REFERENCES teachers(id), remarks TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(student_id, date)
);
CREATE INDEX IF NOT EXISTS idx_attendance_student  ON attendance(student_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_class_dt ON attendance(class_id, date);
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON attendance;
CREATE POLICY school_isolation ON attendance USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS exam_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL, weight DECIMAL(5,2), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, name)
);
ALTER TABLE exam_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON exam_types;
CREATE POLICY school_isolation ON exam_types USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS exams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  academic_year_id UUID NOT NULL REFERENCES academic_years(id),
  exam_type_id UUID NOT NULL REFERENCES exam_types(id),
  class_id UUID NOT NULL REFERENCES classes(id), subject_id UUID NOT NULL REFERENCES subjects(id),
  name VARCHAR(200) NOT NULL, max_marks DECIMAL(6,2) NOT NULL, pass_marks DECIMAL(6,2),
  exam_date DATE, is_published BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE exams ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON exams;
CREATE POLICY school_isolation ON exams USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS marks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  marks_obtained DECIMAL(6,2), grade VARCHAR(5), is_absent BOOLEAN NOT NULL DEFAULT FALSE,
  remarks TEXT, entered_by UUID NOT NULL REFERENCES teachers(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(exam_id, student_id)
);
CREATE INDEX IF NOT EXISTS idx_marks_student ON marks(student_id);
ALTER TABLE marks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON marks;
CREATE POLICY school_isolation ON marks USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS homework (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id), subject_id UUID NOT NULL REFERENCES subjects(id),
  teacher_id UUID NOT NULL REFERENCES teachers(id), title VARCHAR(300) NOT NULL, description TEXT,
  due_date DATE NOT NULL, attachment_urls TEXT[], is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_homework_class ON homework(class_id, due_date DESC);
ALTER TABLE homework ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON homework;
CREATE POLICY school_isolation ON homework USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS fee_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL, description TEXT, UNIQUE(school_id, name)
);

CREATE TABLE IF NOT EXISTS fee_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL, academic_year_id UUID NOT NULL REFERENCES academic_years(id),
  class_id UUID REFERENCES classes(id), amount DECIMAL(10,2) NOT NULL, due_date DATE NOT NULL,
  fee_category_id UUID NOT NULL REFERENCES fee_categories(id), is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fee_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  fee_plan_id UUID NOT NULL REFERENCES fee_plans(id),
  amount_due DECIMAL(10,2) NOT NULL, amount_paid DECIMAL(10,2) NOT NULL DEFAULT 0,
  due_date DATE NOT NULL, paid_date DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','partial','paid','overdue','waived')),
  payment_method VARCHAR(30), payment_ref JSONB, receipt_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fee_records_student ON fee_records(student_id, status);
ALTER TABLE fee_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON fee_records;
CREATE POLICY school_isolation ON fee_records USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  title VARCHAR(300) NOT NULL, body TEXT NOT NULL,
  type VARCHAR(30) NOT NULL DEFAULT 'general' CHECK (type IN ('general','holiday','emergency','exam','fee')),
  target VARCHAR(20) NOT NULL DEFAULT 'all' CHECK (target IN ('all','parents','teachers','class')),
  target_class_id UUID REFERENCES classes(id), attachment_urls TEXT[],
  show_from DATE, show_until DATE,
  is_published BOOLEAN NOT NULL DEFAULT FALSE, published_at TIMESTAMPTZ, created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON announcements;
CREATE POLICY school_isolation ON announcements USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS announcement_dismissals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id       UUID NOT NULL REFERENCES parents(id)       ON DELETE CASCADE,
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  dismissed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(parent_id, announcement_id)
);

CREATE TABLE IF NOT EXISTS notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  user_id UUID NOT NULL, user_type VARCHAR(20) NOT NULL,
  channel VARCHAR(20) NOT NULL CHECK (channel IN ('push','whatsapp','sms','email')),
  title VARCHAR(300), body TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','delivered','failed')),
  attempts SMALLINT NOT NULL DEFAULT 0, error_msg TEXT, sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS timetable (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id), teacher_id UUID NOT NULL REFERENCES teachers(id),
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time TIME NOT NULL, end_time TIME NOT NULL, UNIQUE(class_id, day_of_week, start_time)
);
ALTER TABLE timetable ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON timetable;
CREATE POLICY school_isolation ON timetable USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGSERIAL PRIMARY KEY, school_id UUID, user_id UUID, user_type VARCHAR(20),
  action VARCHAR(50) NOT NULL, table_name VARCHAR(100) NOT NULL, record_id UUID,
  old_data JSONB, new_data JSONB, ip_address INET, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_school ON audit_logs(school_id, created_at DESC);

CREATE TABLE IF NOT EXISTS school_timing_rules (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id  UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  label      VARCHAR(100),
  date_from  DATE NOT NULL,
  date_to    DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time   TIME NOT NULL,
  created_by UUID REFERENCES teachers(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT timing_dates_valid CHECK (date_to >= date_from)
);

CREATE TABLE IF NOT EXISTS student_marks (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id      UUID NOT NULL REFERENCES schools(id)  ON DELETE CASCADE,
  student_id     UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  subject_name   VARCHAR(100) NOT NULL,
  exam_name      VARCHAR(200) NOT NULL DEFAULT 'Unit Test',
  marks_obtained NUMERIC(5,2),
  max_marks      NUMERIC(5,2) NOT NULL DEFAULT 100,
  remarks        TEXT,
  entered_by     UUID REFERENCES teachers(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(student_id, subject_name, exam_name)
);

-- ── Grants ────────────────────────────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- ── Demo seed data ────────────────────────────────────────────────────────────

INSERT INTO schools (name, subdomain, plan) VALUES ('Demo School', 'demo', 'growth')
  ON CONFLICT (subdomain) DO NOTHING;
INSERT INTO academic_years (school_id, name, start_date, end_date, is_current)
  SELECT id, '2024-25', '2024-04-01', '2025-03-31', true FROM schools WHERE subdomain = 'demo'
  ON CONFLICT DO NOTHING;
INSERT INTO classes (school_id, academic_year_id, name, section)
  SELECT s.id, ay.id, '10', 'A' FROM schools s JOIN academic_years ay ON ay.school_id = s.id
  WHERE s.subdomain = 'demo' ON CONFLICT DO NOTHING;
INSERT INTO teachers (school_id, full_name, mobile, mobile_verified)
  SELECT id, 'Rajesh Kumar', '+919876543210', true FROM schools WHERE subdomain = 'demo'
  ON CONFLICT DO NOTHING;
INSERT INTO students (school_id, class_id, admission_no, full_name, gender)
  SELECT s.id, c.id, '2024-001', 'Arjun Sharma', 'male'
  FROM schools s JOIN classes c ON c.school_id = s.id WHERE s.subdomain = 'demo'
  ON CONFLICT DO NOTHING;
INSERT INTO parents (school_id, full_name, mobile, relation)
  SELECT id, 'Suresh Sharma', '+919876543211', 'parent' FROM schools WHERE subdomain = 'demo'
  ON CONFLICT DO NOTHING;
INSERT INTO parent_students (parent_id, student_id)
  SELECT p.id, st.id FROM parents p JOIN students st ON st.school_id = p.school_id
  WHERE p.mobile = '+919876543211' ON CONFLICT DO NOTHING;
