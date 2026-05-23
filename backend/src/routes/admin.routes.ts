import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import * as Admin from '../controllers/admin.controller';

const router = Router();
router.use(authenticate, requireRole('school_admin', 'super_admin'));

router.get('/stats',            Admin.getSchoolStats);
router.get('/teachers',         Admin.listTeachers);
router.post('/teachers',        Admin.createTeacher);
router.delete('/teachers/:id',  Admin.deleteTeacher);
router.get('/classes',          Admin.listClasses);
router.get('/students',         Admin.listStudents);
router.post('/students',        Admin.createStudent);
router.post('/parents',         Admin.createParent);

export default router;
