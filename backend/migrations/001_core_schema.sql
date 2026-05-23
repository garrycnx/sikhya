CREATE EXTENSION IF NOT EXISTS ""uuid-ossp"";
CREATE EXTENSION IF NOT EXISTS ""pgcrypto"";
CREATE EXTENSION IF NOT EXISTS ""pg_trgm"";

CREATE TABLE schools (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL, subdomain VARCHAR(100) UNIQUE NOT NULL,
  address TEXT, phone VARCHAR(20), email VARCHAR(150), logo_url TEXT,
  plan VARCHAR(30) NOT NULL DEFAULT 'starter' CHECK (plan IN ('starter','growth','enterprise')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE, settings JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE academic_years (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(20) NOT NULL, start_date DATE NOT NULL, end_date DATE NOT NULL,
  is_current BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_one_current_year ON academic_years(school_id) WHERE is_current = TRUE;

CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  academic_year_id UUID NOT NULL REFERENCES academic_years(id),
  name VARCHAR(20) NOT NULL, section VARCHAR(10) NOT NULL, room_number VARCHAR(20),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, academic_year_id, name, section)
);

CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL, code VARCHAR(20), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, code)
);

CREATE TABLE teachers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  employee_id VARCHAR(50), full_name VARCHAR(200) NOT NULL,
  email VARCHAR(150), mobile VARCHAR(20) NOT NULL, mobile_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, mobile)
);

CREATE TABLE students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id),
  admission_no VARCHAR(50) NOT NULL, roll_number VARCHAR(20), full_name VARCHAR(200) NOT NULL,
  date_of_birth DATE, gender VARCHAR(10) CHECK (gender IN ('male','female','other')),
  blood_group VARCHAR(5), profile_photo TEXT, address TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE, custom_fields JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, admission_no)
);
CREATE INDEX idx_students_school ON students(school_id);
CREATE INDEX idx_students_class  ON students(class_id);
CREATE INDEX idx_students_name   ON students USING GIN(full_name gin_trgm_ops);

CREATE TABLE parents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  full_name VARCHAR(200) NOT NULL, mobile VARCHAR(20) NOT NULL, email VARCHAR(150),
  relation VARCHAR(30) DEFAULT 'parent', is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(school_id, mobile)
);

CREATE TABLE parent_students (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID NOT NULL REFERENCES parents(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  is_primary BOOLEAN NOT NULL DEFAULT TRUE, UNIQUE(parent_id, student_id)
);
CREATE INDEX idx_parent_students_parent  ON parent_students(parent_id);
CREATE INDEX idx_parent_students_student ON parent_students(student_id);

CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL, user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('parent','teacher','admin')),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL, platform VARCHAR(10) NOT NULL CHECK (platform IN ('android','ios')),
  last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(fcm_token)
);
CREATE INDEX idx_device_tokens_user ON device_tokens(user_id, user_type);

CREATE TABLE admin_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
  full_name VARCHAR(200) NOT NULL, email VARCHAR(150) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role VARCHAR(30) NOT NULL DEFAULT 'school_admin' CHECK (role IN ('super_admin','school_admin','staff')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE, last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE classes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE students        ENABLE ROW LEVEL SECURITY;
ALTER TABLE parents         ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens   ENABLE ROW LEVEL SECURITY;

DO  BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
  CREATE ROLE app_user LOGIN PASSWORD 'app_user_pass_change_me'; END IF; END;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

CREATE POLICY school_isolation ON students      USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON teachers      USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON parents       USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON classes       USING (school_id = current_setting('app.current_school_id')::UUID);
CREATE POLICY school_isolation ON parent_students USING (
  parent_id IN (SELECT id FROM parents WHERE school_id = current_setting('app.current_school_id')::UUID));
CREATE POLICY school_isolation ON device_tokens USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE OR REPLACE FUNCTION update_updated_at() RETURNS TRIGGER AS 
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;  LANGUAGE plpgsql;
CREATE TRIGGER trg_schools_upd  BEFORE UPDATE ON schools  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_teachers_upd BEFORE UPDATE ON teachers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_students_upd BEFORE UPDATE ON students FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_parents_upd  BEFORE UPDATE ON parents  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Demo seed data
INSERT INTO schools (name, subdomain, plan) VALUES ('Demo School', 'demo', 'growth');
INSERT INTO academic_years (school_id, name, start_date, end_date, is_current)
  SELECT id, '2024-25', '2024-04-01', '2025-03-31', true FROM schools WHERE subdomain = 'demo';
INSERT INTO classes (school_id, academic_year_id, name, section)
  SELECT s.id, ay.id, '10', 'A' FROM schools s JOIN academic_years ay ON ay.school_id = s.id WHERE s.subdomain = 'demo';
INSERT INTO teachers (school_id, full_name, mobile, mobile_verified)
  SELECT id, 'Rajesh Kumar', '+919876543210', true FROM schools WHERE subdomain = 'demo';
INSERT INTO students (school_id, class_id, admission_no, full_name, gender)
  SELECT s.id, c.id, '2024-001', 'Arjun Sharma', 'male'
  FROM schools s JOIN classes c ON c.school_id = s.id WHERE s.subdomain = 'demo';
INSERT INTO parents (school_id, full_name, mobile, relation)
  SELECT id, 'Suresh Sharma', '+919876543211', 'parent' FROM schools WHERE subdomain = 'demo';
INSERT INTO parent_students (parent_id, student_id)
  SELECT p.id, st.id FROM parents p
  JOIN students st ON st.school_id = p.school_id
  WHERE p.mobile = '+919876543211';