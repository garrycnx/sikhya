-- Run this once on your database to add PIN support
ALTER TABLE teachers ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255);
ALTER TABLE parents  ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255);
