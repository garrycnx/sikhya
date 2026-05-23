CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id),
  date DATE NOT NULL,
  status VARCHAR(20) NOT NULL CHECK (status IN ('present','absent','late','holiday','half_day')),
  marked_by UUID NOT NULL REFERENCES teachers(id), remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(student_id, date)
);
CREATE INDEX idx_attendance_student   ON attendance(student_id, date DESC);
CREATE INDEX idx_attendance_class_dt  ON attendance(class_id, date);
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
CREATE POLICY school_isolation ON attendance USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE exam_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL, weight DECIMAL(5,2), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), UNIQUE(school_id, name)
);

CREATE TABLE exams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  academic_year_id UUID NOT NULL REFERENCES academic_years(id),
  exam_type_id UUID NOT NULL REFERENCES exam_types(id),
  class_id UUID NOT NULL REFERENCES classes(id), subject_id UUID NOT NULL REFERENCES subjects(id),
  name VARCHAR(200) NOT NULL, max_marks DECIMAL(6,2) NOT NULL, pass_marks DECIMAL(6,2),
  exam_date DATE, is_published BOOLEAN NOT NULL DEFAULT FALSE, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE marks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  marks_obtained DECIMAL(6,2), grade VARCHAR(5), is_absent BOOLEAN NOT NULL DEFAULT FALSE,
  remarks TEXT, entered_by UUID NOT NULL REFERENCES teachers(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(exam_id, student_id)
);
CREATE INDEX idx_marks_student ON marks(student_id);
ALTER TABLE marks ENABLE ROW LEVEL SECURITY;
CREATE POLICY school_isolation ON marks USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE homework (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id), subject_id UUID NOT NULL REFERENCES subjects(id),
  teacher_id UUID NOT NULL REFERENCES teachers(id), title VARCHAR(300) NOT NULL, description TEXT,
  due_date DATE NOT NULL, attachment_urls TEXT[], is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_homework_class ON homework(class_id, due_date DESC);
ALTER TABLE homework ENABLE ROW LEVEL SECURITY;
CREATE POLICY school_isolation ON homework USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE fee_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL, description TEXT, UNIQUE(school_id, name)
);

CREATE TABLE fee_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL, academic_year_id UUID NOT NULL REFERENCES academic_years(id),
  class_id UUID REFERENCES classes(id), amount DECIMAL(10,2) NOT NULL, due_date DATE NOT NULL,
  fee_category_id UUID NOT NULL REFERENCES fee_categories(id), is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE fee_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  fee_plan_id UUID NOT NULL REFERENCES fee_plans(id),
  amount_due DECIMAL(10,2) NOT NULL, amount_paid DECIMAL(10,2) NOT NULL DEFAULT 0,
  due_date DATE NOT NULL, paid_date DATE,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','partial','paid','overdue','waived')),
  payment_method VARCHAR(30), payment_ref JSONB, receipt_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_fee_records_student ON fee_records(student_id, status);
ALTER TABLE fee_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY school_isolation ON fee_records USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  title VARCHAR(300) NOT NULL, body TEXT NOT NULL,
  type VARCHAR(30) NOT NULL DEFAULT 'general' CHECK (type IN ('general','holiday','emergency','exam','fee')),
  target VARCHAR(20) NOT NULL DEFAULT 'all' CHECK (target IN ('all','parents','teachers','class')),
  target_class_id UUID REFERENCES classes(id), attachment_urls TEXT[],
  is_published BOOLEAN NOT NULL DEFAULT FALSE, published_at TIMESTAMPTZ, created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
CREATE POLICY school_isolation ON announcements USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE notification_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  user_id UUID NOT NULL, user_type VARCHAR(20) NOT NULL,
  channel VARCHAR(20) NOT NULL CHECK (channel IN ('push','whatsapp','sms','email')),
  title VARCHAR(300), body TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','delivered','failed')),
  attempts SMALLINT NOT NULL DEFAULT 0, error_msg TEXT, sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE timetable (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES subjects(id), teacher_id UUID NOT NULL REFERENCES teachers(id),
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time TIME NOT NULL, end_time TIME NOT NULL, UNIQUE(class_id, day_of_week, start_time)
);
ALTER TABLE timetable ENABLE ROW LEVEL SECURITY;
CREATE POLICY school_isolation ON timetable USING (school_id = current_setting('app.current_school_id')::UUID);

CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY, school_id UUID, user_id UUID, user_type VARCHAR(20),
  action VARCHAR(50) NOT NULL, table_name VARCHAR(100) NOT NULL, record_id UUID,
  old_data JSONB, new_data JSONB, ip_address INET, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_school ON audit_logs(school_id, created_at DESC);