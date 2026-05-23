ALTER TABLE announcements
  ADD COLUMN IF NOT EXISTS show_from  DATE,
  ADD COLUMN IF NOT EXISTS show_until DATE;

CREATE TABLE IF NOT EXISTS announcement_dismissals (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id       UUID NOT NULL REFERENCES parents(id)       ON DELETE CASCADE,
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  dismissed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(parent_id, announcement_id)
);

GRANT SELECT, INSERT, DELETE ON announcement_dismissals TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;
