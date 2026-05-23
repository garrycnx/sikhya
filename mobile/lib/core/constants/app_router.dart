import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/pin_setup_screen.dart';
import '../../features/parent/presentation/screens/parent_app_shell.dart';
import '../../features/teacher/presentation/screens/teacher_app_shell.dart';
import '../../features/parent/presentation/screens/parent_homework_screen.dart';
import '../../features/parent/presentation/screens/parent_timetable_screen.dart';
import '../../features/parent/presentation/screens/parent_marks_screen.dart';
import '../../features/parent/presentation/screens/parent_attendance_screen.dart';
import '../../features/parent/presentation/screens/parent_announcements_screen.dart';

const _publicRoutes = {'/login', '/otp', '/pin-setup', '/pin-login'};

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isPublic = _publicRoutes.any((r) => loc == r || loc.startsWith('$r?'));
      if (!ApiClient.hasToken && !isPublic) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login',     builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/otp',       builder: (c, s) => OtpScreen(
        mobile:          s.uri.queryParameters['mobile'] ?? '',
        schoolSubdomain: s.uri.queryParameters['school'] ?? '',
        admissionNo:     s.uri.queryParameters['admissionNo'],
      )),
      GoRoute(path: '/pin-setup', builder: (c, s) => const PinSetupScreen()),
      GoRoute(path: '/pin-login', builder: (c, s) => PinLoginScreen(
        mobile:          s.uri.queryParameters['mobile'] ?? '',
        schoolSubdomain: s.uri.queryParameters['school'] ?? '',
        admissionNo:     s.uri.queryParameters['admissionNo']?.isNotEmpty == true
                           ? s.uri.queryParameters['admissionNo'] : null,
      )),

      // ── Parent shell ──────────────────────────────────────────────────
      GoRoute(path: '/dashboard', builder: (c, s) => const ParentAppShell()),

      // ── Teacher shell ─────────────────────────────────────────────────
      GoRoute(path: '/teacher-dashboard', builder: (c, s) => const TeacherAppShell()),

      // ── Standalone parent screens ─────────────────────────────────────
      GoRoute(
        path: '/parent/homework',
        builder: (c, s) => ParentHomeworkScreen(
          classId:   s.uri.queryParameters['class_id']   ?? '',
          className: Uri.decodeComponent(s.uri.queryParameters['class_name'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/parent/timetable',
        builder: (c, s) => ParentTimetableScreen(
          classId:   s.uri.queryParameters['class_id']   ?? '',
          className: Uri.decodeComponent(s.uri.queryParameters['class_name'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/parent/marks',
        builder: (c, s) => ParentMarksScreen(
          studentId:   s.uri.queryParameters['student_id']   ?? '',
          studentName: Uri.decodeComponent(s.uri.queryParameters['student_name'] ?? 'Student'),
        ),
      ),
      GoRoute(
        path: '/parent/attendance',
        builder: (c, s) => ParentAttendanceScreen(
          studentId:   s.uri.queryParameters['student_id']   ?? '',
          studentName: Uri.decodeComponent(s.uri.queryParameters['student_name'] ?? 'Student'),
        ),
      ),
      GoRoute(
        path: '/parent/announcements',
        builder: (c, s) => const ParentAnnouncementsScreen(),
      ),
    ],
  );
});
