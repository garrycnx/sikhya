class ApiConstants {
  static const baseUrl       = 'https://sikhya-production.up.railway.app/api/v1';
  static const requestOtp    = '/auth/request-otp';
  static const verifyOtp     = '/auth/verify-otp';
  static const loginPin      = '/auth/login-pin';
  static const setPin        = '/auth/set-pin';
  static const refreshToken  = '/auth/refresh';
  static const logout        = '/auth/logout';
  static const me            = '/auth/me';
  // parent
  static const parentDashboard  = '/parent/dashboard';
  static const parentTimetable  = '/parent/timetable';
  static const parentHomework   = '/parent/homework';
  static String parentDismissAnnouncement(String id) => '/parent/announcements/$id';
  // teacher
  static const teacherDashboard  = '/teacher/dashboard';
  static const teacherClasses    = '/teacher/classes';
  static const teacherAllClasses = '/teacher/all-classes';
  static const teacherSubjects   = '/teacher/subjects';
  static const teacherExamTypes  = '/teacher/exam-types';
  static const teacherExams      = '/teacher/exams';
  static const teacherMarks      = '/teacher/marks';
  static const teacherHomework   = '/teacher/homework';
  static String teacherDeleteHomework(String id) => '/teacher/homework/$id';
  static const teacherStudents   = '/teacher/students';
  static const teacherTransfer   = '/teacher/students/transfer';
  static const teacherAttendance = '/teacher/attendance';
  static const teacherAnnouncements = '/teacher/announcements';
  static const schoolTiming         = '/teacher/school-timing';
  static const teacherTimingRules   = '/teacher/timing-rules';
  static const teacherAllStudents   = '/teacher/all-students';
  static String teacherStudentSimpleMarks(String studentId) => '/teacher/students/$studentId/simple-marks';
  static String teacherAnnouncementById(String id) => '/teacher/announcements/$id';
  static String teacherTimingRuleById(String id)   => '/teacher/timing-rules/$id';
  static String studentParents(String studentId)   => '/teacher/students/$studentId/parents';
  static String tagParent(String studentId)        => '/teacher/students/$studentId/tag-parent';
  static String removeStudentParent(String studentId, String parentId) => '/teacher/students/$studentId/parents/$parentId';
  // parent marks
  static const parentMarks          = '/parent/marks';
  static const parentAttendance     = '/parent/attendance';
  static const parentAnnouncements  = '/parent/announcements';
  static String teacherCreateExam()                  => '/teacher/exams';
  static String classStudents(String classId)        => '/teacher/classes/$classId/students';
  static String classAttendance(String classId)      => '/teacher/classes/$classId/attendance';
  static String classTimetable(String classId)       => '/teacher/classes/$classId/timetable';
  static String timetableEntry(String entryId)       => '/teacher/timetable/$entryId';
  static String studentProfile(String studentId)     => '/teacher/students/$studentId/profile';
  static String studentUpdate(String studentId)      => '/teacher/students/$studentId';
  static String studentRemove(String studentId)      => '/teacher/students/$studentId';
  // teacher profile
  static const teacherUpdateProfile = '/teacher/profile';
  // admin
  static const adminStats              = '/admin/stats';
  static const adminTeachers           = '/admin/teachers';
  static const adminStudents           = '/admin/students';
  static const adminClasses            = '/admin/classes';
  static const adminParents            = '/admin/parents';
  static const adminSeedDefaultClasses = '/admin/classes/seed-defaults';
}
