import { Request, Response } from 'express';
import { appPool } from '../config/database';
import { sendSuccess, sendError } from '../utils/response';

export async function getParentDashboard(req: Request, res: Response) {
  const parentId = req.user!.id;
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);

    const parentRes = await client.query(
      `SELECT p.full_name, p.mobile, p.email,
              (SELECT s.name FROM schools s WHERE s.id = $1) AS school_name,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id',                   s.id,
                    'full_name',            s.full_name,
                    'admission_no',         s.admission_no,
                    'date_of_birth',        s.date_of_birth,
                    'address',              s.address,
                    'emergency_contact',    s.emergency_contact,
                    'class_id',             c.id,
                    'class_name',           c.name,
                    'section',              c.section,
                    'today_status',         COALESCE(att_today.status, 'not_marked'),
                    'month_attendance_pct', CASE
                      WHEN COALESCE(att_month.total, 0) > 0
                      THEN ROUND(COALESCE(att_month.present, 0)::numeric * 100 / att_month.total)::int
                      ELSE 0 END,
                    'active_hw_count',      COALESCE(hw.hw_count, 0)
                  )
                ) FILTER (WHERE s.id IS NOT NULL),
                '[]'::json
              ) AS students
       FROM parents p
       LEFT JOIN parent_students ps ON ps.parent_id = p.id
       LEFT JOIN students s         ON s.id = ps.student_id
       LEFT JOIN classes c          ON c.id = s.class_id
       LEFT JOIN LATERAL (
         SELECT status FROM attendance
         WHERE student_id = s.id AND date = CURRENT_DATE LIMIT 1
       ) att_today ON s.id IS NOT NULL
       LEFT JOIN LATERAL (
         SELECT
           COUNT(*) FILTER (WHERE status IN ('present','late'))                                     AS present,
           COUNT(*) FILTER (WHERE EXTRACT(DOW FROM date) <> 0)                                     AS total
         FROM attendance
         WHERE student_id = s.id
           AND date >= DATE_TRUNC('month', CURRENT_DATE)
           AND date <= CURRENT_DATE
       ) att_month ON s.id IS NOT NULL
       LEFT JOIN LATERAL (
         SELECT COUNT(*)::int AS hw_count FROM homework
         WHERE class_id = c.id AND due_date >= CURRENT_DATE AND school_id = $1
       ) hw ON c.id IS NOT NULL
       WHERE p.id = $2
       GROUP BY p.id`,
      [schoolId, parentId]
    );
    if (!parentRes.rows.length) return sendError(res, 'Parent not found', 404);

    let announcements: unknown[] = [];
    try {
      const annRes = await client.query(
        `SELECT a.id, a.title, a.body, a.type, a.target, a.created_at,
                c.name AS class_name, c.section
         FROM announcements a
         LEFT JOIN classes c ON c.id = a.target_class_id
         WHERE a.school_id = $1 AND a.is_published = true
           AND a.target IN ('all','parents')
           AND (a.show_from IS NULL  OR a.show_from  <= CURRENT_DATE)
           AND (a.show_until IS NULL OR a.show_until >= CURRENT_DATE)
           AND a.id NOT IN (
             SELECT announcement_id FROM announcement_dismissals WHERE parent_id = $2
           )
         ORDER BY a.created_at DESC LIMIT 10`,
        [schoolId, parentId]
      );
      announcements = annRes.rows;
    } catch (_) {}

    return sendSuccess(res, { ...parentRes.rows[0], announcements });
  } catch (e) {
    return sendError(res, e instanceof Error ? e.message : 'Failed');
  } finally {
    client.release();
  }
}

export async function dismissAnnouncement(req: Request, res: Response) {
  const parentId = req.user!.id;
  const { announcementId } = req.params;
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    await client.query(
      `INSERT INTO announcement_dismissals (parent_id, announcement_id)
       VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [parentId, announcementId]
    );
    return sendSuccess(res, { dismissed: true });
  } finally { client.release(); }
}

export async function getParentHomework(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const classId  = req.query.class_id as string;
  if (!classId) return sendError(res, 'class_id required', 422);
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT h.id, h.title, h.description, h.due_date,
              h.created_at, sub.name AS subject_name
       FROM homework h
       JOIN subjects sub ON sub.id = h.subject_id
       WHERE h.class_id = $1 AND h.school_id = $2 AND h.is_active = true
         AND h.due_date >= CURRENT_DATE - INTERVAL '1 day'
       ORDER BY h.due_date DESC`,
      [classId, schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}

export async function getParentTimetable(req: Request, res: Response) {
  const schoolId = req.user!.school_id;
  const classId  = req.query.class_id as string;
  if (!classId) return sendError(res, 'class_id required', 422);
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const [periodsRes, timingRes, rulesRes] = await Promise.all([
      client.query(
        `SELECT tt.id, tt.day_of_week, tt.start_time::text, tt.end_time::text,
                sub.name AS subject_name
         FROM timetable tt
         JOIN subjects sub ON sub.id = tt.subject_id
         WHERE tt.class_id = $1 AND tt.school_id = $2
         ORDER BY tt.day_of_week, tt.start_time`,
        [classId, schoolId]
      ),
      client.query(
        `SELECT school_start_time::text, school_end_time::text FROM schools WHERE id = $1`,
        [schoolId]
      ),
      client.query(
        `SELECT id, label, date_from::text, date_to::text,
                start_time::text, end_time::text
         FROM school_timing_rules WHERE school_id = $1
         AND date_to >= CURRENT_DATE
         ORDER BY date_from`,
        [schoolId]
      ),
    ]);
    return sendSuccess(res, {
      periods: periodsRes.rows,
      school_start_time: timingRes.rows[0]?.school_start_time ?? null,
      school_end_time:   timingRes.rows[0]?.school_end_time   ?? null,
      timing_rules: rulesRes.rows,
    });
  } finally { client.release(); }
}

export async function getParentAttendance(req: Request, res: Response) {
  const parentId  = req.user!.id;
  const schoolId  = req.user!.school_id;
  const studentId = req.query.student_id as string;
  const month     = req.query.month     as string; // YYYY-MM
  if (!studentId)                               return sendError(res, 'student_id required', 422);
  if (!month || !/^\d{4}-\d{2}$/.test(month))  return sendError(res, 'month required (YYYY-MM)', 422);

  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const ownsRes = await client.query(
      `SELECT 1 FROM parent_students WHERE parent_id = $1 AND student_id = $2`,
      [parentId, studentId]
    );
    if (!ownsRes.rows.length) return sendError(res, 'Student not found', 404);

    const [year, mon] = month.split('-').map(Number);
    const monthStart  = `${month}-01`;
    const daysInMonth = new Date(year, mon, 0).getDate(); // day-0 trick: last day of prior month
    const monthEnd    = `${month}-${String(daysInMonth).padStart(2, '0')}`;

    const attRes = await client.query(
      `SELECT date::text, status FROM attendance
       WHERE student_id = $1 AND school_id = $2 AND date >= $3 AND date <= $4
       ORDER BY date`,
      [studentId, schoolId, monthStart, monthEnd]
    );
    const records: Record<string, string> = {};
    for (const row of attRes.rows) records[row.date] = row.status;

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let presentCount = 0, absentCount = 0, totalSchoolDays = 0;
    const days: Array<{ date: string; status: string }> = [];

    for (let day = 1; day <= daysInMonth; day++) {
      const d       = new Date(year, mon - 1, day);
      const dateStr = `${year}-${String(mon).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      const isSunday = d.getDay() === 0;

      if (isSunday) {
        days.push({ date: dateStr, status: 'holiday' });
        continue;
      }

      const isPast = d < today;
      let status: string;
      if (records[dateStr])  status = records[dateStr];
      else if (isPast)       status = 'absent';   // auto-absent for unmarked past days
      else                   status = 'not_marked';

      if (['present', 'absent', 'late', 'half_day'].includes(status)) {
        totalSchoolDays++;
        if (status === 'absent') absentCount++;
        else                     presentCount++;
      }
      days.push({ date: dateStr, status });
    }

    return sendSuccess(res, {
      days,
      summary: {
        present:          presentCount,
        absent:           absentCount,
        total_school_days: totalSchoolDays,
        percentage: totalSchoolDays > 0
          ? Math.round((presentCount / totalSchoolDays) * 100)
          : 0,
      },
    });
  } finally { client.release(); }
}

export async function getParentAnnouncementsList(req: Request, res: Response) {
  const parentId = req.user!.id;
  const schoolId = req.user!.school_id;
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    const r = await client.query(
      `SELECT a.id, a.title, a.body, a.type, a.target, a.created_at,
              a.show_from, a.show_until,
              c.name AS class_name, c.section
       FROM announcements a
       LEFT JOIN classes c ON c.id = a.target_class_id
       WHERE a.school_id = $1 AND a.is_published = true
         AND a.target IN ('all','parents')
         AND (a.show_from IS NULL  OR a.show_from  <= CURRENT_DATE)
         AND (a.show_until IS NULL OR a.show_until >= CURRENT_DATE)
         AND a.id NOT IN (
           SELECT announcement_id FROM announcement_dismissals WHERE parent_id = $2
         )
       ORDER BY a.created_at DESC`,
      [schoolId, parentId]
    );
    return sendSuccess(res, r.rows);
  } catch (e) {
    return sendError(res, e instanceof Error ? e.message : 'Failed');
  } finally {
    client.release();
  }
}

export async function getParentMarks(req: Request, res: Response) {
  const parentId  = req.user!.id;
  const schoolId  = req.user!.school_id;
  const studentId = req.query.student_id as string;
  if (!studentId) return sendError(res, 'student_id required', 422);
  const client = await appPool.connect();
  try {
    await client.query(`SET app.current_school_id = '${schoolId}'`);
    // Verify parent owns this student
    const ownsRes = await client.query(
      `SELECT 1 FROM parent_students WHERE parent_id = $1 AND student_id = $2`,
      [parentId, studentId]
    );
    if (!ownsRes.rows.length) return sendError(res, 'Student not found', 404);

    const r = await client.query(
      `SELECT sm.subject_name, sm.exam_name,
              sm.marks_obtained::float, sm.max_marks::float, sm.remarks,
              sm.updated_at
       FROM student_marks sm
       WHERE sm.student_id = $1 AND sm.school_id = $2
       ORDER BY sm.exam_name, sm.subject_name`,
      [studentId, schoolId]
    );
    return sendSuccess(res, r.rows);
  } finally { client.release(); }
}
