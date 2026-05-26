ALTER TABLE announcements DROP CONSTRAINT IF EXISTS announcements_type_check;
ALTER TABLE announcements ADD CONSTRAINT announcements_type_check
  CHECK (type IN ('general','holiday','emergency','exam','fee','birthday'));
