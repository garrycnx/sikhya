import { Router } from 'express';
import { authenticate, requireRole } from '../middleware/auth';
import * as Teacher from '../controllers/teacher.controller';

const router = Router();
router.use(authenticate, requireRole('teacher'));

router.get('/dashboard',                          Teacher.getMyDashboard);
router.put('/profile',                            Teacher.updateTeacherProfile);
router.get('/classes',                            Teacher.getMyClasses);
router.get('/all-classes',                        Teacher.getAllClasses);
router.get('/subjects',                           Teacher.getSubjects);
router.get('/exam-types',                         Teacher.getExamTypes);
router.get('/exams',                              Teacher.getExams);
router.post('/exams',                             Teacher.createExam);
router.post('/marks',                             Teacher.addMarks);
router.get('/homework',                           Teacher.getHomework);
router.post('/homework',                          Teacher.addHomework);
router.delete('/homework/:homeworkId',            Teacher.deleteHomework);

// Student management
router.get('/classes/:classId/students',          Teacher.getClassStudents);
router.post('/students',                          Teacher.addStudent);
router.put('/students/:studentId',                Teacher.updateStudent);
router.get('/students/:studentId/profile',        Teacher.getStudentProfile);
router.post('/students/transfer',                 Teacher.transferStudent);
router.delete('/students/:studentId',             Teacher.removeStudentFromClass);

// Attendance
router.post('/attendance',                        Teacher.markAttendance);
router.get('/classes/:classId/attendance',        Teacher.getAttendance);

// School timing
router.get('/school-timing',                      Teacher.getSchoolTiming);
router.put('/school-timing',                      Teacher.updateSchoolTiming);

// Timetable
router.get('/classes/:classId/timetable',         Teacher.getTimetable);
router.post('/classes/:classId/timetable',        Teacher.addTimetableEntry);
router.delete('/timetable/:entryId',              Teacher.deleteTimetableEntry);

// Announcements / Notifications to parents
router.get('/announcements',                      Teacher.getAnnouncements);
router.post('/announcements',                     Teacher.createAnnouncement);
router.put('/announcements/:announcementId',      Teacher.updateAnnouncement);
router.delete('/announcements/:announcementId',   Teacher.deleteAnnouncement);

// Timing rules (date-range overrides for school hours)
router.get('/timing-rules',                       Teacher.getTimingRules);
router.post('/timing-rules',                      Teacher.createTimingRule);
router.put('/timing-rules/:ruleId',               Teacher.updateTimingRule);
router.delete('/timing-rules/:ruleId',            Teacher.deleteTimingRule);

// Parent tagging
router.get('/students/:studentId/parents',        Teacher.getStudentParents);
router.post('/students/:studentId/tag-parent',    Teacher.tagParent);
router.delete('/students/:studentId/parents/:parentId', Teacher.removeStudentParent);

// All students across all classes (for marks entry)
router.get('/all-students',                       Teacher.getAllStudents);
router.get('/students/:studentId/simple-marks',   Teacher.getStudentSimpleMarks);
router.post('/students/:studentId/simple-marks',  Teacher.saveStudentSimpleMarks);

export default router;
