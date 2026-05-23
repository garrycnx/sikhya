-- Re-grant permissions for all tables created in migration 002
-- (GRANT in migration 001 only covered tables that existed at that time)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Add RLS to exam_types and exams (missing from migration 002)
ALTER TABLE exam_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON exam_types;
CREATE POLICY school_isolation ON exam_types
  USING (school_id = current_setting('app.current_school_id')::UUID);

ALTER TABLE exams ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS school_isolation ON exams;
CREATE POLICY school_isolation ON exams
  USING (school_id = current_setting('app.current_school_id')::UUID);

-- Ensure unique subject names per school (prevent duplicates)
ALTER TABLE subjects DROP CONSTRAINT IF EXISTS uq_subjects_school_name;
ALTER TABLE subjects ADD CONSTRAINT uq_subjects_school_name UNIQUE (school_id, name);
