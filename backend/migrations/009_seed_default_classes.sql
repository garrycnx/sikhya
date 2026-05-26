-- Seed default class sections for all schools that have a current academic year
-- Run once: inserts Pre-Nursery/Nursery/KG/Class 1-12 with sections A-E
-- Safe to re-run: skips existing (name, section) combinations

DO $$
DECLARE
  r RECORD;
  ay_id UUID;
  cls_name TEXT;
  cls_section TEXT;
  cls_names TEXT[] := ARRAY['Pre-Nursery','Nursery','KG','1','2','3','4','5','6','7','8','9','10','11','12'];
  cls_sections TEXT[];
BEGIN
  FOR r IN SELECT id FROM schools LOOP
    BEGIN
      SELECT id INTO ay_id
      FROM academic_years
      WHERE school_id = r.id AND is_current = TRUE
      LIMIT 1;

      IF ay_id IS NULL THEN CONTINUE; END IF;

      FOREACH cls_name IN ARRAY cls_names LOOP
        -- Pre-Nursery/Nursery: A-D, KG: A-C, rest: A-E
        IF cls_name = 'KG' THEN
          cls_sections := ARRAY['A','B','C'];
        ELSIF cls_name IN ('Pre-Nursery','Nursery') THEN
          cls_sections := ARRAY['A','B','C','D'];
        ELSE
          cls_sections := ARRAY['A','B','C','D','E'];
        END IF;

        FOREACH cls_section IN ARRAY cls_sections LOOP
          IF NOT EXISTS (
            SELECT 1 FROM classes
            WHERE school_id = r.id
              AND academic_year_id = ay_id
              AND name = cls_name
              AND section = cls_section
          ) THEN
            INSERT INTO classes (school_id, academic_year_id, name, section)
            VALUES (r.id, ay_id, cls_name, cls_section);
          END IF;
        END LOOP;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Skipped school %: %', r.id, SQLERRM;
    END;
  END LOOP;
END; $$;
