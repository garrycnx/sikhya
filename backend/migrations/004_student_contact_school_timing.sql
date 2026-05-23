ALTER TABLE students ADD COLUMN IF NOT EXISTS emergency_contact VARCHAR(20);

ALTER TABLE schools ADD COLUMN IF NOT EXISTS school_start_time TIME;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS school_end_time   TIME;
