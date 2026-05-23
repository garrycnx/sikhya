-- Date-range school timing rules
-- Teacher sets different start/end times for a date range (e.g. exam week, winter schedule)
CREATE TABLE IF NOT EXISTS school_timing_rules (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id   UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  label       VARCHAR(100),
  date_from   DATE NOT NULL,
  date_to     DATE NOT NULL,
  start_time  TIME NOT NULL,
  end_time    TIME NOT NULL,
  created_by  UUID REFERENCES teachers(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT timing_dates_valid CHECK (date_to >= date_from)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON school_timing_rules TO app_user;

-- Simplified student marks (separate from complex exam/marks workflow)
-- Each row = one student + one subject + one exam name
CREATE TABLE IF NOT EXISTS student_marks (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id       UUID NOT NULL REFERENCES schools(id)  ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  subject_name    VARCHAR(100) NOT NULL,
  exam_name       VARCHAR(200) NOT NULL DEFAULT 'Unit Test',
  marks_obtained  NUMERIC(5,2),
  max_marks       NUMERIC(5,2) NOT NULL DEFAULT 100,
  remarks         TEXT,
  entered_by      UUID REFERENCES teachers(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(student_id, subject_name, exam_name)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON student_marks TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;
