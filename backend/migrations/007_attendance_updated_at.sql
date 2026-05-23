-- Fix: attendance table was missing updated_at, causing ON CONFLICT upserts to fail
ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Re-grant so app_user can UPDATE the new column
GRANT SELECT, INSERT, UPDATE, DELETE ON attendance TO app_user;
