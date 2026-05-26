import cron from 'node-cron';
import { adminPool, appPool } from '../config/database';
import { sendOtpSms } from '../services/sms.service';

async function runBirthdayJob() {
  console.log('[Birthday Job] Running...');
  try {
    const schoolsRes = await adminPool.query(
      'SELECT id, name FROM schools WHERE is_active = true'
    );
    for (const school of schoolsRes.rows) {
      const client = await appPool.connect();
      try {
        await client.query(`SET app.current_school_id = '${school.id}'`);

        const birthdayRes = await client.query(`
          SELECT s.id, s.full_name,
                 COALESCE(json_agg(json_build_object('mobile', p.mobile, 'name', p.full_name))
                   FILTER (WHERE p.id IS NOT NULL), '[]') AS parents
          FROM students s
          LEFT JOIN parent_students ps ON ps.student_id = s.id
          LEFT JOIN parents p ON p.id = ps.parent_id AND p.is_active = true
          WHERE s.is_active = true
            AND s.date_of_birth IS NOT NULL
            AND EXTRACT(MONTH FROM s.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
            AND EXTRACT(DAY   FROM s.date_of_birth) = EXTRACT(DAY   FROM CURRENT_DATE)
          GROUP BY s.id, s.full_name
        `);

        if (!birthdayRes.rows.length) continue;

        const teacherRes = await client.query(
          `SELECT id FROM teachers WHERE school_id = $1 LIMIT 1`, [school.id]
        );
        if (!teacherRes.rows.length) continue;
        const createdBy = teacherRes.rows[0].id;

        for (const student of birthdayRes.rows) {
          const title = `Happy Birthday, ${student.full_name}! 🎂`;
          const body  = `Wishing ${student.full_name} a very Happy Birthday! 🎉 May this special day be filled with joy, laughter, and wonderful memories. The entire school family sends its warmest wishes to you and your family. Have a wonderful celebration! 🌟`;

          await client.query(`
            INSERT INTO announcements
              (school_id, title, body, type, target, is_published, published_at, created_by)
            VALUES ($1, $2, $3, 'birthday', 'parents', true, NOW(), $4)
          `, [school.id, title, body, createdBy]);

          if (process.env.SKIP_SMS !== 'true') {
            for (const parent of (student.parents as { mobile: string; name: string }[])) {
              if (!parent.mobile) continue;
              const sms = `Dear ${parent.name}, Wishing your child ${student.full_name} a very Happy Birthday! 🎂 Warm wishes from ${school.name}.`;
              try { await sendOtpSms(parent.mobile, sms); } catch (_) {}
            }
          }

          console.log(`[Birthday Job] Sent wishes for ${student.full_name} (school: ${school.name})`);
        }
      } finally { client.release(); }
    }
    console.log('[Birthday Job] Done.');
  } catch (err) {
    console.error('[Birthday Job] Error:', err);
  }
}

export function startBirthdayJob() {
  // Run at 8:00 AM IST = 2:30 AM UTC every day
  cron.schedule('30 2 * * *', runBirthdayJob, { timezone: 'UTC' });
  console.log('[Birthday Job] Scheduled (daily 8 AM IST)');
}
