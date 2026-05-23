import { Router } from 'express';
import authRoutes    from './auth.routes';
import adminRoutes   from './admin.routes';
import teacherRoutes from './teacher.routes';
import {
  getParentDashboard, getParentTimetable,
  dismissAnnouncement, getParentHomework, getParentMarks,
  getParentAttendance, getParentAnnouncementsList,
} from '../controllers/parent.controller';
import { authenticate } from '../middleware/auth';

const router = Router();
router.use('/auth',    authRoutes);
router.use('/admin',   adminRoutes);
router.use('/teacher', teacherRoutes);
router.get('/parent/dashboard',                             authenticate, getParentDashboard);
router.get('/parent/timetable',                             authenticate, getParentTimetable);
router.get('/parent/homework',                              authenticate, getParentHomework);
router.delete('/parent/announcements/:announcementId',      authenticate, dismissAnnouncement);
router.get('/parent/marks',                                 authenticate, getParentMarks);
router.get('/parent/attendance',                            authenticate, getParentAttendance);
router.get('/parent/announcements',                         authenticate, getParentAnnouncementsList);
router.get('/health', (_req, res) => res.json({ success: true, data: { status: 'ok', ts: new Date().toISOString() } }));
export default router;
