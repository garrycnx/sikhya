import { Request, Response } from 'express';
import { z } from 'zod';
import { appPool } from '../config/database';
import { sendSuccess, sendError } from '../utils/response';

const addMarksSchema = z.object({
  exam_id: z.string().uuid(),
  entries: z.array(z.object({
    student_id: z.string().uuid(),
    marks_obtained: z.number().min(0).nullable(),
    is_absent: z.boolean().default(false),
    grade: z.string().max(5).optional(),
    remarks: z.string().optional(),
  })).min(1),
});

const createHomeworkSchema = z.object({
  class_id: z.string().uuid(),
  subject_id: z.string().uuid().optional(),
  subject_name: z.string().min(1).max(100).optional(),
  title: z.string().min(3).max(300),
  description: z.string().nullish(),
  due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
}).refine(d => d.subject_id || d.subject_name, { message: 'subject_id or subject_name required' });

const createExamSchema = z.object({
  class_id: z.string().uuid(),
  subject_id: z.string().uuid(),
  exam_type_id: z.string().uuid(),
  name: z.string().min(2).max(200),
  max_marks: z.number().min(1),
  pass_marks: z.number().min(0).optional(),
  exam_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

const addStudentSchema = z.object({
  class_id: z.string().uuid(),
  full_name: z.string().min(2).max(200),
  admission_no: z.string().min(1).max(50),
  roll_number: z.string().optional(),
  gender: z.enum(['male', 'female', 'other']).optional(),
  date_of_birth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  profile_photo: z.string().optional(),
  address: z.string().optional(),
  emergency_contact: z.string().max(20).optional(),
});

const updateStudentSchema = z.object({
  full_name: z.string().min(2).max(200).optional(),
  admission_no: z.string().min(1).max(50).optional(),
  roll_number: z.string().optional(),
  gender: z.enum(['male', 'female', 'other']).optional(),
  date_of_birth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  profile_photo: z.string().optional(),
  address: z.string().optional(),
  emergency_contact: z.string().max(20).optional(),
});

const transferStudentSchema = z.object({
  student_id: z.string().uuid(),
  to_class_id: z.string().uuid(),
});

const updateTeacherProfileSchema = z.object({
  full_name: z.string().min(2).max(200).optional(),
  email: z.string().email().optional().or(z.literal('')),
});

const tagParentSchema = z.object({
  mobile:   z.string().min(10).max(15),
  name:     z.string().min(1).max(200),
  relation: z.string().max(30).optional(),
});

const markAttendanceSchema = z.object({
  class_id: z.string().uuid(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  entries: z.array(z.object({
    student_id: z.string().uuid(),
    status: z.enum(['present', 'absent', 'late', 'half_day']),
    remarks: z.string().optional(),
  })).min(1),
});

export async function updateTeacherProfile(req: Request, res: Response) {
  const p = updateTeacherProfileSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const teacherId = req.user!.id;
  const schoolId  = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const fields: string[] = [];
    const values: unknown[] = [];
    let idx = 1;
    if (p.data.full_name) { fields.push(`full_name = $${idx++}`); values.push(p.data.full_name); }
    if (p.data.email !== undefined) { fields.push(`email = $${idx++}`); values.push(p.data.email || null); }
    if (!fields.length) return sendError(res, 'No fields to update', 422);
    values.push(teacherId);
    const r = await client.query(
      `UPDATE teachers SET ${fields.join(', ')}, updated_at = NOW()
       WHERE id = $${idx} RETURNING id, full_name, email, mobile`,
      values
    );
    if (!r.rows.length) return sendError(res, 'Teacher not found', 404);
    return sendSuccess(res, r.rows[0]);
  } finally { client.release(); }
}

export async function getMyDashboard(req: Request, res: Response) {
  const teacherId = req.user!.id;
  const schoolId  = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);

    const teacherRes = await client.query(
      `SELECT full_name, email, mobile, employee_id FROM teachers WHERE id = $1`, [teacherId]
    );
    if (!teacherRes.rows.length) return sendError(res, 'Teacher not found', 404);

    const classesRes = await client.query(
      `SELECT c.id, c.name, c.section, COUNT(s.id)::int AS student_count
       FROM classes c
       JOIN academic_years ay ON ay.id = c.academic_year_id AND ay.is_current = true
       LEFT JOIN students s ON s.class_id = c.id AND s.is_active = true
       WHERE c.school_id = $1
       GROUP BY c.id, c.name, c.section ORDER BY c.name, c.section`,
      [schoolId]
    );

    let hwCount = 0;
    try {
      const hwRes = await client.query(
        `SELECT COUNT(*)::int AS count FROM homework
         WHERE teacher_id = $1 AND due_date >= CURRENT_DATE AND is_active = true`,
        [teacherId]
      );
      hwCount = hwRes.rows[0].count;
    } catch (_) { /* homework table may not be accessible yet */ }

    return sendSuccess(res, {
      teacher: teacherRes.rows[0],
      my_classes: classesRes.rows,
      pending_homework_count: hwCount,
    });
  } catch (e: unknown) {
    return sendError(res, e instanceof Error ? e.message : 'Failed to load dashboard', 500);
  } finally { client.release(); }
}

export async function getMyClasses(req: Request, res: Response) {
  const teacherId = req.user!.id;
  const schoolId  = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT DISTINCT c.id, c.name, c.section,
              array_agg(DISTINCT sub.name ORDER BY sub.name) AS subjects
       FROM timetable tt
       JOIN classes c ON c.id = tt.class_id
       JOIN subjects sub ON sub.id = tt.subject_id
       WHERE tt.teacher_id = $1
       GROUP BY c.id, c.name, c.section ORDER BY c.name, c.section`,
      [teacherId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function getAllClasses(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT c.id, c.name, c.section,
              COUNT(s.id)::int AS student_count
       FROM classes c
       JOIN academic_years ay ON ay.id = c.academic_year_id AND ay.is_current = true
       LEFT JOIN students s ON s.class_id = c.id AND s.is_active = true
       WHERE c.school_id = $1
       GROUP BY c.id, c.name, c.section
       ORDER BY c.name, c.section`,
      [schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function getClassStudents(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT id, admission_no, roll_number, full_name, gender, profile_photo
       FROM students WHERE class_id = $1 AND is_active = true
       ORDER BY roll_number NULLS LAST, full_name`,
      [req.params.classId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function addStudent(req: Request, res: Response) {
  const p = addStudentSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `INSERT INTO students (school_id, class_id, full_name, admission_no, roll_number, gender, date_of_birth, profile_photo, address, emergency_contact)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING id, admission_no, full_name, gender, profile_photo`,
      [
        schoolId, p.data.class_id, p.data.full_name, p.data.admission_no,
        p.data.roll_number ?? null, p.data.gender ?? null,
        p.data.date_of_birth ?? null, p.data.profile_photo ?? null,
        p.data.address ?? null, p.data.emergency_contact ?? null,
      ]
    );
    return sendSuccess(res, r.rows[0], 201);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'Failed to add student';
    if (msg.includes('unique') || msg.includes('duplicate')) {
      return sendError(res, 'Admission number already exists', 409);
    }
    return sendError(res, msg, 500);
  } finally { client.release(); }
}

export async function updateStudent(req: Request, res: Response) {
  const p = updateStudentSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const studentId = req.params.studentId;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const fields: string[] = [];
    const values: unknown[] = [];
    let idx = 1;
    for (const [k, v] of Object.entries(p.data)) {
      if (v !== undefined) { fields.push(`${k} = $${idx++}`); values.push(v); }
    }
    if (!fields.length) return sendError(res, 'No fields to update', 422);
    values.push(studentId, schoolId);
    const r = await client.query(
      `UPDATE students SET ${fields.join(', ')}, updated_at = NOW()
       WHERE id = $${idx} AND school_id = $${idx + 1} AND is_active = true
       RETURNING id, full_name, admission_no, roll_number, gender, date_of_birth, profile_photo`,
      values
    );
    if (!r.rows.length) return sendError(res, 'Student not found', 404);
    return sendSuccess(res, r.rows[0]);
  } finally { client.release(); }
}

export async function getStudentProfile(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const studentId = req.params.studentId;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);

    const studentRes = await client.query(
      `SELECT s.id, s.full_name, s.admission_no, s.roll_number, s.gender,
              s.date_of_birth, s.profile_photo, s.is_active,
              s.address, s.emergency_contact,
              c.id AS class_id, c.name AS class_name, c.section
       FROM students s
       JOIN classes c ON c.id = s.class_id
       WHERE s.id = $1 AND s.school_id = $2`,
      [studentId, schoolId]
    );
    if (!studentRes.rows.length) return sendError(res, 'Student not found', 404);

    const parentsRes = await client.query(
      `SELECT p.id, p.full_name, p.mobile, p.email, p.relation
       FROM parents p
       JOIN parent_students ps ON ps.parent_id = p.id
       WHERE ps.student_id = $1`,
      [studentId]
    );

    const marksRes = await client.query(
      `SELECT e.name AS exam_name, e.max_marks, e.pass_marks, e.exam_date,
              sub.name AS subject_name, et.name AS exam_type,
              m.marks_obtained, m.is_absent, m.grade, m.remarks
       FROM marks m
       JOIN exams e ON e.id = m.exam_id
       JOIN subjects sub ON sub.id = e.subject_id
       JOIN exam_types et ON et.id = e.exam_type_id
       WHERE m.student_id = $1 AND m.school_id = $2
       ORDER BY e.exam_date DESC NULLS LAST`,
      [studentId, schoolId]
    );

    let attendanceSummary = { present: 0, absent: 0, late: 0, half_day: 0, total: 0 };
    let recentAttendance: unknown[] = [];
    try {
      const attSumRes = await client.query(
        `SELECT status, COUNT(*)::int AS count
         FROM attendance WHERE student_id = $1 AND school_id = $2
         GROUP BY status`,
        [studentId, schoolId]
      );
      for (const row of attSumRes.rows) {
        attendanceSummary[row.status as keyof typeof attendanceSummary] = row.count;
        attendanceSummary.total += row.count;
      }
      const recentAttRes = await client.query(
        `SELECT date, status, remarks FROM attendance
         WHERE student_id = $1 AND school_id = $2
         ORDER BY date DESC LIMIT 30`,
        [studentId, schoolId]
      );
      recentAttendance = recentAttRes.rows;
    } catch (_) {}

    let recentHomework: unknown[] = [];
    try {
      const hwRes = await client.query(
        `SELECT h.title, h.due_date, sub.name AS subject_name
         FROM homework h
         JOIN subjects sub ON sub.id = h.subject_id
         WHERE h.class_id = (SELECT class_id FROM students WHERE id = $1)
           AND h.school_id = $2 AND h.is_active = true
         ORDER BY h.due_date DESC LIMIT 20`,
        [studentId, schoolId]
      );
      recentHomework = hwRes.rows;
    } catch (_) {}

    return sendSuccess(res, {
      student: studentRes.rows[0],
      parents: parentsRes.rows,
      marks: marksRes.rows,
      attendance_summary: attendanceSummary,
      recent_attendance: recentAttendance,
      recent_homework: recentHomework,
    });
  } finally { client.release(); }
}

export async function transferStudent(req: Request, res: Response) {
  const p = transferStudentSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `UPDATE students SET class_id = $1, updated_at = NOW()
       WHERE id = $2 AND school_id = $3 AND is_active = true
       RETURNING id, full_name, class_id`,
      [p.data.to_class_id, p.data.student_id, schoolId]
    );
    if (!r.rows.length) return sendError(res, 'Student not found', 404);
    return sendSuccess(res, r.rows[0]);
  } finally { client.release(); }
}

export async function removeStudentFromClass(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const studentId = req.params.studentId;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `UPDATE students SET is_active = false, updated_at = NOW()
       WHERE id = $1 AND school_id = $2
       RETURNING id, full_name`,
      [studentId, schoolId]
    );
    if (!r.rows.length) return sendError(res, 'Student not found', 404);
    return sendSuccess(res, { message: 'Student removed from class' });
  } finally { client.release(); }
}

export async function markAttendance(req: Request, res: Response) {
  const p = markAttendanceSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const teacherId = req.user!.id;
  const schoolId  = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query('BEGIN');
    for (const entry of p.data.entries) {
      await client.query(
        `INSERT INTO attendance (school_id, class_id, student_id, date, status, remarks, marked_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT (student_id, date) DO UPDATE SET
           status = EXCLUDED.status, remarks = EXCLUDED.remarks,
           marked_by = EXCLUDED.marked_by, updated_at = NOW()`,
        [schoolId, p.data.class_id, entry.student_id, p.data.date,
         entry.status, entry.remarks ?? null, teacherId]
      );
    }
    await client.query('COMMIT');
    return sendSuccess(res, { message: `${p.data.entries.length} attendance records saved` });
  } catch (e: unknown) {
    await client.query('ROLLBACK');
    return sendError(res, e instanceof Error ? e.message : 'Failed to save attendance');
  } finally { client.release(); }
}

export async function getAttendance(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const { classId } = req.params;
  const date = req.query.date as string | undefined;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT a.student_id, s.full_name, s.roll_number, a.date, a.status, a.remarks
       FROM attendance a
       JOIN students s ON s.id = a.student_id
       WHERE a.class_id = $1 AND a.school_id = $2
         ${date ? 'AND a.date = $3' : ''}
       ORDER BY s.roll_number NULLS LAST, s.full_name`,
      date ? [classId, schoolId, date] : [classId, schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

const DEFAULT_SUBJECTS = [
  { name: 'Mathematics',         code: 'MATH' },
  { name: 'English',             code: 'ENG'  },
  { name: 'Punjabi',             code: 'PUN'  },
  { name: 'Hindi',               code: 'HIN'  },
  { name: 'Social Science',      code: 'SST'  },
  { name: 'Science',             code: 'SCI'  },
  { name: 'Computer Science',    code: 'CS'   },
  { name: 'Physical Education',  code: 'PE'   },
  { name: 'Art & Craft',         code: 'ART'  },
  { name: 'General Knowledge',   code: 'GK'   },
];

export async function getSubjects(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    let r = await client.query(
      `SELECT id, name, code FROM subjects WHERE school_id = $1 ORDER BY name`, [schoolId]
    );
    if (r.rows.length === 0) {
      for (const s of DEFAULT_SUBJECTS) {
        await client.query(
          `INSERT INTO subjects (school_id, name, code) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
          [schoolId, s.name, s.code]
        );
      }
      r = await client.query(
        `SELECT id, name, code FROM subjects WHERE school_id = $1 ORDER BY name`, [schoolId]
      );
    }
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

const DEFAULT_EXAM_TYPES = [
  { name: 'Unit Test',  weight: 5  },
  { name: 'Class Test', weight: 10 },
  { name: 'Mid Term',   weight: 30 },
  { name: 'Pre-Final',  weight: 20 },
  { name: 'Final',      weight: 40 },
];

export async function getExamTypes(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    let r = await client.query(
      `SELECT id, name, weight FROM exam_types WHERE school_id = $1 ORDER BY weight`, [schoolId]
    );
    if (r.rows.length === 0) {
      for (const et of DEFAULT_EXAM_TYPES) {
        await client.query(
          `INSERT INTO exam_types (school_id, name, weight) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
          [schoolId, et.name, et.weight]
        );
      }
      r = await client.query(
        `SELECT id, name, weight FROM exam_types WHERE school_id = $1 ORDER BY weight`, [schoolId]
      );
    }
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function createExam(req: Request, res: Response) {
  const p = createExamSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const ayRes = await client.query(
      `SELECT id FROM academic_years WHERE school_id = $1 AND is_current = true`, [schoolId]
    );
    if (!ayRes.rows.length) return sendError(res, 'No active academic year', 400);
    const r = await client.query(
      `INSERT INTO exams (school_id, academic_year_id, exam_type_id, class_id, subject_id, name, max_marks, pass_marks, exam_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id, name, max_marks, exam_date`,
      [schoolId, ayRes.rows[0].id, p.data.exam_type_id, p.data.class_id, p.data.subject_id,
       p.data.name, p.data.max_marks, p.data.pass_marks ?? null, p.data.exam_date ?? null]
    );
    return sendSuccess(res, r.rows[0], 201);
  } finally { client.release(); }
}

export async function addMarks(req: Request, res: Response) {
  const p = addMarksSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const teacherId = req.user!.id;
  const schoolId  = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query('BEGIN');
    for (const entry of p.data.entries) {
      await client.query(
        `INSERT INTO marks (school_id, exam_id, student_id, marks_obtained, is_absent, grade, remarks, entered_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT (exam_id, student_id) DO UPDATE SET
           marks_obtained = EXCLUDED.marks_obtained, is_absent = EXCLUDED.is_absent,
           grade = EXCLUDED.grade, remarks = EXCLUDED.remarks, entered_by = EXCLUDED.entered_by,
           updated_at = NOW()`,
        [schoolId, p.data.exam_id, entry.student_id, entry.marks_obtained ?? null,
         entry.is_absent, entry.grade ?? null, entry.remarks ?? null, teacherId]
      );
    }
    await client.query('COMMIT');
    return sendSuccess(res, { message: `${p.data.entries.length} marks saved` });
  } catch (e: unknown) {
    await client.query('ROLLBACK');
    return sendError(res, e instanceof Error ? e.message : 'Failed to save marks');
  } finally { client.release(); }
}

export async function getExams(req: Request, res: Response) {
  const schoolId    = req.user!.school_id;
  const classId     = req.query.class_id     as string | undefined;
  const examTypeId  = req.query.exam_type_id as string | undefined;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const conditions: string[] = ['e.school_id = $1'];
    const params: unknown[] = [schoolId];
    if (classId)    { params.push(classId);    conditions.push(`e.class_id = $${params.length}`); }
    if (examTypeId) { params.push(examTypeId); conditions.push(`e.exam_type_id = $${params.length}`); }
    const r = await client.query(
      `SELECT e.id, e.name, e.max_marks, e.pass_marks, e.exam_date, e.is_published,
              sub.id AS subject_id, sub.name AS subject_name,
              et.id AS exam_type_id, et.name AS exam_type,
              c.name AS class_name, c.section
       FROM exams e
       JOIN subjects sub ON sub.id = e.subject_id
       JOIN exam_types et ON et.id = e.exam_type_id
       JOIN classes c ON c.id = e.class_id
       WHERE ${conditions.join(' AND ')}
       ORDER BY sub.name, e.exam_date DESC NULLS LAST`,
      params
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function addHomework(req: Request, res: Response) {
  const p = createHomeworkSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const teacherId = req.user!.id;
  const schoolId  = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    let subjectId = p.data.subject_id;
    if (!subjectId && p.data.subject_name) {
      const existing = await client.query(
        `SELECT id FROM subjects WHERE school_id = $1 AND LOWER(name) = LOWER($2)`,
        [schoolId, p.data.subject_name]
      );
      if (existing.rows.length > 0) {
        subjectId = existing.rows[0].id;
      } else {
        const created = await client.query(
          `INSERT INTO subjects (school_id, name) VALUES ($1, $2) RETURNING id`,
          [schoolId, p.data.subject_name]
        );
        subjectId = created.rows[0].id;
      }
    }
    const r = await client.query(
      `INSERT INTO homework (school_id, class_id, subject_id, teacher_id, title, description, due_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING id, title, due_date`,
      [schoolId, p.data.class_id, subjectId, teacherId,
       p.data.title, p.data.description ?? null, p.data.due_date]
    );
    return sendSuccess(res, r.rows[0], 201);
  } finally { client.release(); }
}

export async function getHomework(req: Request, res: Response) {
  const teacherId = req.user!.id;
  const schoolId  = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT h.id, h.title, h.description, h.due_date, h.is_active,
              sub.name AS subject_name, c.name AS class_name, c.section
       FROM homework h
       JOIN subjects sub ON sub.id = h.subject_id
       JOIN classes c ON c.id = h.class_id
       WHERE h.teacher_id = $1
       ORDER BY h.created_at DESC`,
      [teacherId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function deleteHomework(req: Request, res: Response) {
  const teacherId  = req.user!.id;
  const schoolId   = req.user!.school_id;
  const homeworkId = req.params.homeworkId;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `DELETE FROM homework
       WHERE id = $1 AND teacher_id = $2 AND school_id = $3
       RETURNING id`,
      [homeworkId, teacherId, schoolId]
    );
    if (!r.rows.length) return sendError(res, 'Homework not found or not yours', 404);
    return sendSuccess(res, { deleted: true });
  } finally { client.release(); }
}

// ─── Timetable ────────────────────────────────────────────────────────────────
const timetableEntrySchema = z.object({
  subject_id:  z.string().uuid(),
  day_of_week: z.number().int().min(1).max(7),
  start_time:  z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/),
  end_time:    z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/),
});

export async function getTimetable(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const { classId } = req.params;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT tt.id, tt.day_of_week, tt.start_time::text, tt.end_time::text,
              sub.id AS subject_id, sub.name AS subject_name
       FROM timetable tt
       JOIN subjects sub ON sub.id = tt.subject_id
       WHERE tt.class_id = $1 AND tt.school_id = $2
       ORDER BY tt.day_of_week, tt.start_time`,
      [classId, schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function addTimetableEntry(req: Request, res: Response) {
  const p = timetableEntrySchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId  = req.user!.school_id;
  const teacherId = req.user!.id;
  const { classId } = req.params;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `INSERT INTO timetable (school_id, class_id, subject_id, teacher_id, day_of_week, start_time, end_time)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT (class_id, day_of_week, start_time) DO UPDATE SET
         subject_id = EXCLUDED.subject_id, teacher_id = EXCLUDED.teacher_id, end_time = EXCLUDED.end_time
       RETURNING id`,
      [schoolId, classId, p.data.subject_id, teacherId,
       p.data.day_of_week, p.data.start_time, p.data.end_time]
    );
    return sendSuccess(res, r.rows[0], 201);
  } catch (e: unknown) {
    return sendError(res, e instanceof Error ? e.message : 'Failed', 500);
  } finally { client.release(); }
}

export async function deleteTimetableEntry(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query(
      `DELETE FROM timetable WHERE id = $1 AND school_id = $2`,
      [req.params.entryId, schoolId]
    );
    return sendSuccess(res, { deleted: true });
  } finally { client.release(); }
}

// ─── School Timing ────────────────────────────────────────────────────────────
const schoolTimingSchema = z.object({
  school_start_time: z.string().regex(/^\d{2}:\d{2}$/),
  school_end_time:   z.string().regex(/^\d{2}:\d{2}$/),
});

export async function getSchoolTiming(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    const r = await client.query(
      `SELECT school_start_time::text, school_end_time::text FROM schools WHERE id = $1`,
      [schoolId]
    );
    return sendSuccess(res, r.rows[0] ?? { school_start_time: null, school_end_time: null });
  } finally { client.release(); }
}

export async function updateSchoolTiming(req: Request, res: Response) {
  const p = schoolTimingSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(
      `UPDATE schools SET school_start_time = $1, school_end_time = $2, updated_at = NOW() WHERE id = $3`,
      [p.data.school_start_time, p.data.school_end_time, schoolId]
    );
    return sendSuccess(res, { school_start_time: p.data.school_start_time, school_end_time: p.data.school_end_time });
  } finally { client.release(); }
}

// ─── Announcements ────────────────────────────────────────────────────────────
const createAnnouncementSchema = z.object({
  title:           z.string().min(2).max(300),
  body:            z.string().min(2),
  type:            z.enum(['general','holiday','emergency','exam','fee']).default('general'),
  target:          z.enum(['all','parents','class']).default('parents'),
  target_class_id: z.string().uuid().optional(),
  show_from:       z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  show_until:      z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

export async function createAnnouncement(req: Request, res: Response) {
  const p = createAnnouncementSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId  = req.user!.school_id;
  const teacherId = req.user!.id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `INSERT INTO announcements
         (school_id, title, body, type, target, target_class_id,
          show_from, show_until, is_published, published_at, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,NOW(),$9)
       RETURNING id, title, body, type, target, show_from, show_until, created_at`,
      [schoolId, p.data.title, p.data.body, p.data.type, p.data.target,
       p.data.target_class_id ?? null,
       p.data.show_from ?? null, p.data.show_until ?? null,
       teacherId]
    );
    return sendSuccess(res, r.rows[0], 201);
  } catch (e: unknown) {
    return sendError(res, e instanceof Error ? e.message : 'Failed to create announcement', 500);
  } finally { client.release(); }
}

export async function getAnnouncements(req: Request, res: Response) {
  const schoolId  = req.user!.school_id;
  const teacherId = req.user!.id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    // Returns only this teacher's announcements, hides expired ones
    const r = await client.query(
      `SELECT a.id, a.title, a.body, a.type, a.target,
              a.show_from::text, a.show_until::text, a.created_at,
              c.name AS class_name, c.section
       FROM announcements a
       LEFT JOIN classes c ON c.id = a.target_class_id
       WHERE a.school_id = $1 AND a.created_by = $2
         AND (a.show_until IS NULL OR a.show_until >= CURRENT_DATE)
       ORDER BY a.created_at DESC`,
      [schoolId, teacherId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

const updateAnnouncementSchema = z.object({
  title:           z.string().min(2).max(300).optional(),
  body:            z.string().min(2).optional(),
  type:            z.enum(['general','holiday','emergency','exam','fee']).optional(),
  target:          z.enum(['all','parents','class']).optional(),
  target_class_id: z.string().uuid().nullable().optional(),
  show_from:       z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
  show_until:      z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
});

export async function updateAnnouncement(req: Request, res: Response) {
  const p = updateAnnouncementSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId  = req.user!.school_id;
  const teacherId = req.user!.id;
  const { announcementId } = req.params;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const fields: string[] = [];
    const values: unknown[] = [];
    let idx = 1;
    for (const [k, v] of Object.entries(p.data)) {
      if (v !== undefined) { fields.push(`${k} = $${idx++}`); values.push(v); }
    }
    if (!fields.length) return sendError(res, 'No fields to update', 422);
    values.push(announcementId, schoolId, teacherId);
    const r = await client.query(
      `UPDATE announcements SET ${fields.join(', ')}
       WHERE id = $${idx} AND school_id = $${idx+1} AND created_by = $${idx+2}
       RETURNING id, title, body, type, target, show_from, show_until, created_at`,
      values
    );
    if (!r.rows.length) return sendError(res, 'Announcement not found', 404);
    return sendSuccess(res, r.rows[0]);
  } finally { client.release(); }
}

export async function deleteAnnouncement(req: Request, res: Response) {
  const schoolId  = req.user!.school_id;
  const teacherId = req.user!.id;
  const { announcementId } = req.params;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `DELETE FROM announcements WHERE id = $1 AND school_id = $2 AND created_by = $3
       RETURNING id`,
      [announcementId, schoolId, teacherId]
    );
    if (!r.rows.length) return sendError(res, 'Announcement not found', 404);
    return sendSuccess(res, { deleted: true });
  } finally { client.release(); }
}

// ─── Timing Rules ─────────────────────────────────────────────────────────────
const timingRuleSchema = z.object({
  label:      z.string().max(100).optional(),
  date_from:  z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  date_to:    z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  start_time: z.string().regex(/^\d{2}:\d{2}$/),
  end_time:   z.string().regex(/^\d{2}:\d{2}$/),
});

export async function getTimingRules(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const [rulesRes, defaultRes] = await Promise.all([
      client.query(
        `SELECT id, label, date_from::text, date_to::text,
                start_time::text, end_time::text, created_at
         FROM school_timing_rules WHERE school_id = $1
         ORDER BY date_from`,
        [schoolId]
      ),
      client.query(
        `SELECT school_start_time::text, school_end_time::text FROM schools WHERE id = $1`,
        [schoolId]
      ),
    ]);
    return sendSuccess(res, {
      default_start: defaultRes.rows[0]?.school_start_time ?? null,
      default_end:   defaultRes.rows[0]?.school_end_time   ?? null,
      rules: rulesRes.rows,
    });
  } finally { client.release(); }
}

export async function createTimingRule(req: Request, res: Response) {
  const p = timingRuleSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  if (p.data.date_to < p.data.date_from) return sendError(res, 'date_to must be on or after date_from', 422);
  const schoolId  = req.user!.school_id;
  const teacherId = req.user!.id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `INSERT INTO school_timing_rules (school_id, label, date_from, date_to, start_time, end_time, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING id, label, date_from::text, date_to::text, start_time::text, end_time::text`,
      [schoolId, p.data.label ?? null, p.data.date_from, p.data.date_to,
       p.data.start_time, p.data.end_time, teacherId]
    );
    return sendSuccess(res, r.rows[0], 201);
  } catch (e: unknown) {
    return sendError(res, e instanceof Error ? e.message : 'Failed', 500);
  } finally { client.release(); }
}

export async function updateTimingRule(req: Request, res: Response) {
  const p = timingRuleSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `UPDATE school_timing_rules SET
         label = $1, date_from = $2, date_to = $3, start_time = $4, end_time = $5
       WHERE id = $6 AND school_id = $7
       RETURNING id, label, date_from::text, date_to::text, start_time::text, end_time::text`,
      [p.data.label ?? null, p.data.date_from, p.data.date_to,
       p.data.start_time, p.data.end_time, req.params.ruleId, schoolId]
    );
    if (!r.rows.length) return sendError(res, 'Rule not found', 404);
    return sendSuccess(res, r.rows[0]);
  } finally { client.release(); }
}

export async function deleteTimingRule(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query(
      `DELETE FROM school_timing_rules WHERE id = $1 AND school_id = $2`,
      [req.params.ruleId, schoolId]
    );
    return sendSuccess(res, { deleted: true });
  } finally { client.release(); }
}

// ─── Student Simple Marks ──────────────────────────────────────────────────────
const saveMarksSchema = z.object({
  exam_name: z.string().min(1).max(200),
  entries: z.array(z.object({
    subject_name:   z.string().min(1).max(100),
    marks_obtained: z.number().min(0).nullable(),
    max_marks:      z.number().min(1).default(100),
    remarks:        z.string().max(500).nullable().optional(),
  })).min(1),
});

export async function getAllStudents(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT s.id, s.full_name, s.admission_no, s.roll_number,
              c.id AS class_id, c.name AS class_name, c.section
       FROM students s
       JOIN classes c ON c.id = s.class_id
       WHERE s.school_id = $1 AND s.is_active = true
       ORDER BY c.name, c.section, s.roll_number NULLS LAST, s.full_name`,
      [schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function getStudentSimpleMarks(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const { studentId } = req.params;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT id, subject_name, exam_name,
              marks_obtained::float, max_marks::float, remarks
       FROM student_marks
       WHERE student_id = $1 AND school_id = $2
       ORDER BY exam_name, subject_name`,
      [studentId, schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

// ─── Parent Tagging ───────────────────────────────────────────────────────────

export async function getStudentParents(req: Request, res: Response) {
  const { studentId } = req.params;
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT p.id, p.full_name, p.mobile, p.relation, p.email
       FROM parents p
       JOIN parent_students ps ON ps.parent_id = p.id
       WHERE ps.student_id = $1 AND p.is_active = true
       ORDER BY p.full_name`,
      [studentId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function tagParent(req: Request, res: Response) {
  const { studentId } = req.params;
  const p = tagParentSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const studentCheck = await client.query(
      `SELECT id FROM students WHERE id = $1`, [studentId]
    );
    if (!studentCheck.rows.length) return sendError(res, 'Student not found', 404);

    // Find or create parent by mobile within this school
    let parentId: string;
    const existing = await client.query(
      `SELECT id FROM parents WHERE REPLACE(mobile,'+','') = REPLACE($1,'+','')`,
      [p.data.mobile]
    );
    if (existing.rows.length) {
      parentId = existing.rows[0].id;
      // Update name/relation if provided
      await client.query(
        `UPDATE parents SET full_name=$1, relation=COALESCE($2,relation) WHERE id=$3`,
        [p.data.name, p.data.relation ?? null, parentId]
      );
    } else {
      const created = await client.query(
        `INSERT INTO parents (school_id, full_name, mobile, relation)
         VALUES ($1,$2,$3,$4) RETURNING id`,
        [schoolId, p.data.name, p.data.mobile, p.data.relation ?? 'parent']
      );
      parentId = created.rows[0].id;
    }

    await client.query(
      `INSERT INTO parent_students (parent_id, student_id)
       VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [parentId, studentId]
    );

    const row = await client.query(
      `SELECT id, full_name, mobile, relation FROM parents WHERE id=$1`, [parentId]
    );
    return sendSuccess(res, row.rows[0], 201);
  } catch (e: unknown) {
    return sendError(res, e instanceof Error ? e.message : 'Failed', 500);
  } finally { client.release(); }
}

export async function removeStudentParent(req: Request, res: Response) {
  const { studentId, parentId } = req.params;
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query(
      `DELETE FROM parent_students WHERE student_id=$1 AND parent_id=$2`,
      [studentId, parentId]
    );
    return sendSuccess(res, { removed: true });
  } finally { client.release(); }
}

export async function saveStudentSimpleMarks(req: Request, res: Response) {
  const p = saveMarksSchema.safeParse(req.body);
  if (!p.success) return sendError(res, p.error.errors[0].message, 422);
  const schoolId  = req.user!.school_id;
  const teacherId = req.user!.id;
  const { studentId } = req.params;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query('BEGIN');
    for (const entry of p.data.entries) {
      if (entry.marks_obtained === null && !entry.remarks) continue;
      await client.query(
        `INSERT INTO student_marks
           (school_id, student_id, subject_name, exam_name, marks_obtained, max_marks, remarks, entered_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
         ON CONFLICT (student_id, subject_name, exam_name) DO UPDATE SET
           marks_obtained = EXCLUDED.marks_obtained,
           max_marks      = EXCLUDED.max_marks,
           remarks        = EXCLUDED.remarks,
           entered_by     = EXCLUDED.entered_by,
           updated_at     = NOW()`,
        [schoolId, studentId, entry.subject_name, p.data.exam_name,
         entry.marks_obtained, entry.max_marks, entry.remarks ?? null, teacherId]
      );
    }
    await client.query('COMMIT');
    return sendSuccess(res, { saved: p.data.entries.length });
  } catch (e: unknown) {
    await client.query('ROLLBACK');
    return sendError(res, e instanceof Error ? e.message : 'Failed', 500);
  } finally { client.release(); }
}
