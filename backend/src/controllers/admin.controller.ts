import { Request, Response } from 'express';
import { z } from 'zod';
import { adminPool, appPool } from '../config/database';
import { sendSuccess, sendError, sendCreated } from '../utils/response';

const createTeacherSchema = z.object({
  full_name: z.string().min(2),
  mobile: z.string().min(10).max(15),
  email: z.string().email().optional(),
  employee_id: z.string().optional(),
});

const createStudentSchema = z.object({
  full_name: z.string().min(2),
  admission_no: z.string().min(1),
  class_id: z.string().uuid(),
  roll_number: z.string().optional(),
  gender: z.enum(['male', 'female', 'other']).optional(),
  date_of_birth: z.string().optional(),
});

const createParentSchema = z.object({
  full_name: z.string().min(2),
  mobile: z.string().min(10).max(15),
  email: z.string().email().optional(),
  relation: z.string().optional(),
  student_id: z.string().uuid(),
});

export async function listTeachers(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT id, employee_id, full_name, email, mobile, mobile_verified, is_active, created_at
       FROM teachers ORDER BY full_name`
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function createTeacher(req: Request, res: Response) {
  const p = createTeacherSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `INSERT INTO teachers (school_id, full_name, mobile, email, employee_id, mobile_verified)
       VALUES ($1, $2, $3, $4, $5, true)
       RETURNING id, full_name, mobile, email, employee_id`,
      [schoolId, p.data.full_name, p.data.mobile, p.data.email ?? null, p.data.employee_id ?? null]
    );
    return sendCreated(res, r.rows[0]);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'Failed';
    if (msg.includes('unique')) return sendError(res, 'Mobile already registered for a teacher', 409);
    return sendError(res, msg);
  } finally { client.release(); }
}

export async function deleteTeacher(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query(`UPDATE teachers SET is_active = false WHERE id = $1`, [req.params.id]);
    return sendSuccess(res, { message: 'Teacher deactivated' });
  } finally { client.release(); }
}

const createClassSchema = z.object({
  name: z.string().min(1).max(50),
  section: z.string().min(1).max(10),
  room_number: z.string().optional(),
});

const DEFAULT_CLASSES = [
  { name: 'Pre-Nursery', sections: ['A', 'B', 'C', 'D'] },
  { name: 'Nursery',     sections: ['A', 'B', 'C', 'D'] },
  { name: 'KG',          sections: ['A', 'B', 'C'] },
  ...(Array.from({ length: 12 }, (_, i) => ({
    name: String(i + 1),
    sections: ['A', 'B', 'C', 'D', 'E'],
  }))),
];

export async function createClass(req: Request, res: Response) {
  const p = createClassSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const ayRes = await client.query(
      `SELECT id FROM academic_years WHERE school_id = $1 AND is_current = true`, [schoolId]
    );
    if (!ayRes.rows.length) return sendError(res, 'No active academic year', 400);
    const ayId = ayRes.rows[0].id;
    // Check duplicate
    const dup = await client.query(
      `SELECT id FROM classes WHERE school_id=$1 AND academic_year_id=$2 AND name=$3 AND section=$4`,
      [schoolId, ayId, p.data.name, p.data.section]
    );
    if (dup.rows.length) return sendError(res, 'Class already exists', 409);
    const r = await client.query(
      `INSERT INTO classes (school_id, academic_year_id, name, section, room_number)
       VALUES ($1,$2,$3,$4,$5) RETURNING id, name, section`,
      [schoolId, ayId, p.data.name, p.data.section, p.data.room_number ?? null]
    );
    return sendCreated(res, r.rows[0]);
  } catch (e: unknown) {
    return sendError(res, e instanceof Error ? e.message : 'Failed');
  } finally { client.release(); }
}

export async function seedDefaultClasses(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const ayRes = await client.query(
      `SELECT id FROM academic_years WHERE school_id = $1 AND is_current = true`, [schoolId]
    );
    if (!ayRes.rows.length) return sendError(res, 'No active academic year', 400);
    const ayId = ayRes.rows[0].id;
    let created = 0;
    for (const cls of DEFAULT_CLASSES) {
      for (const section of cls.sections) {
        const existing = await client.query(
          `SELECT id FROM classes WHERE school_id=$1 AND academic_year_id=$2 AND name=$3 AND section=$4`,
          [schoolId, ayId, cls.name, section]
        );
        if (!existing.rows.length) {
          await client.query(
            `INSERT INTO classes (school_id, academic_year_id, name, section) VALUES ($1,$2,$3,$4)`,
            [schoolId, ayId, cls.name, section]
          );
          created++;
        }
      }
    }
    return sendSuccess(res, { message: `${created} classes created`, total: DEFAULT_CLASSES.reduce((s, c) => s + c.sections.length, 0) });
  } catch (e: unknown) {
    return sendError(res, e instanceof Error ? e.message : 'Failed');
  } finally { client.release(); }
}

export async function listClasses(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT c.id, c.name, c.section, c.room_number,
              COUNT(s.id)::int AS student_count
       FROM classes c
       LEFT JOIN students s ON s.class_id = c.id AND s.is_active = true
       JOIN academic_years ay ON ay.id = c.academic_year_id AND ay.is_current = true
       WHERE c.school_id = $1
       GROUP BY c.id ORDER BY c.name, c.section`,
      [schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function listStudents(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const classId = req.query.class_id as string | undefined;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT s.id, s.admission_no, s.roll_number, s.full_name, s.gender,
              c.name AS class_name, c.section
       FROM students s JOIN classes c ON c.id = s.class_id
       WHERE s.school_id = $1 AND s.is_active = true
         ${classId ? 'AND s.class_id = $2' : ''}
       ORDER BY c.name, c.section, s.roll_number NULLS LAST, s.full_name`,
      classId ? [schoolId, classId] : [schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function createStudent(req: Request, res: Response) {
  const p = createStudentSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `INSERT INTO students (school_id, class_id, admission_no, full_name, roll_number, gender, date_of_birth)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, admission_no, full_name`,
      [schoolId, p.data.class_id, p.data.admission_no, p.data.full_name,
       p.data.roll_number ?? null, p.data.gender ?? null, p.data.date_of_birth ?? null]
    );
    return sendCreated(res, r.rows[0]);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'Failed';
    if (msg.includes('unique')) return sendError(res, 'Admission number already exists', 409);
    return sendError(res, msg);
  } finally { client.release(); }
}

export async function createParent(req: Request, res: Response) {
  const p = createParentSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query('BEGIN');
    const pr = await client.query(
      `INSERT INTO parents (school_id, full_name, mobile, email, relation)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (school_id, mobile) DO UPDATE SET full_name = EXCLUDED.full_name
       RETURNING id, full_name, mobile`,
      [schoolId, p.data.full_name, p.data.mobile, p.data.email ?? null, p.data.relation ?? 'parent']
    );
    await client.query(
      `INSERT INTO parent_students (parent_id, student_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [pr.rows[0].id, p.data.student_id]
    );
    await client.query('COMMIT');
    return sendCreated(res, pr.rows[0]);
  } catch (e: unknown) {
    await client.query('ROLLBACK');
    return sendError(res, e instanceof Error ? e.message : 'Failed');
  } finally { client.release(); }
}

export async function getSchoolStats(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const [schoolRes, statsRes] = await Promise.all([
    adminPool.query('SELECT name, plan, subdomain FROM schools WHERE id = $1', [schoolId]),
    appPool.connect().then(async client => {
      await client.query(`SET app.current_school_id = '${schoolId}'`);
      try {
        return client.query(
          `SELECT
            (SELECT COUNT(*) FROM teachers  WHERE school_id = $1 AND is_active = true)::int AS teachers,
            (SELECT COUNT(*) FROM students  WHERE school_id = $1 AND is_active = true)::int AS students,
            (SELECT COUNT(*) FROM parents   WHERE school_id = $1 AND is_active = true)::int AS parents,
            (SELECT COUNT(*) FROM classes   WHERE school_id = $1)::int AS classes`,
          [schoolId]
        );
      } finally { client.release(); }
    }),
  ]);
  return sendSuccess(res, { school: schoolRes.rows[0], stats: statsRes.rows[0] });
}
