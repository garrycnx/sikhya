import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'add_marks_screen.dart';
import 'attendance_screen.dart';
import 'class_students_screen.dart';
import 'timetable_screen.dart';
import 'send_notification_screen.dart';
import 'notifications_list_screen.dart';
import 'teacher_homework_list_screen.dart';

final teacherDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherDashboard);
  return r.data['data'] as Map<String, dynamic>;
});

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty && p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  static String _date() {
    final n = DateTime.now();
    const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d[n.weekday - 1]}, ${n.day} ${m[n.month]} ${n.year}';
  }

  void _pickClass(BuildContext context, List classes,
      void Function(Map<String, dynamic>) onPick) {
    if (classes.isEmpty) return;
    if (classes.length == 1) { onPick(classes[0] as Map<String, dynamic>); return; }
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text('Select Class',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        ...classes.map((c) {
          final cls = c as Map<String, dynamic>;
          return ListTile(
            leading: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.class_rounded,
                  color: AppColors.primary, size: 18)),
            title: Text('Class ${cls['name']} - ${cls['section']}'),
            subtitle: Text('${cls['student_count']} students'),
            onTap: () { Navigator.pop(context); onPick(cls); },
          );
        }),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(teacherDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: dash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final teacher = data['teacher'] as Map<String, dynamic>;
          final classes = (data['my_classes'] as List?) ?? [];
          final hwCount = data['pending_homework_count'] ?? 0;
          final fullName = teacher['full_name'] as String? ?? 'Teacher';
          final firstName = fullName.split(' ').first;
          final totalStudents = classes.fold<int>(
              0, (s, c) => s + ((c as Map)['student_count'] as int? ?? 0));

          return CustomScrollView(slivers: [

            // ── App Bar ─────────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              stretch: true,
              elevation: 0,
              backgroundColor: const Color(0xFF0A2472),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Logout',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.black, size: 20)),
                    onPressed: () async {
                      await ref.read(authNotifierProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _Header(
                  firstName: firstName,
                  initials: _initials(fullName),
                  classCount: classes.length,
                  hwCount: hwCount,
                  greeting: _greeting(),
                  dateStr: _date(),
                ),
              ),
            ),

            // ── Stats strip ─────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(children: [
                  _StatTile(
                    label: 'Classes',
                    value: '${classes.length}',
                    icon: Icons.class_rounded,
                    gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  ),
                  const SizedBox(width: 10),
                  _StatTile(
                    label: 'Active HW',
                    value: '$hwCount',
                    icon: Icons.assignment_rounded,
                    gradient: const [Color(0xFFE65100), Color(0xFFFFA726)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const TeacherHomeworkListScreen())),
                  ),
                  const SizedBox(width: 10),
                  _StatTile(
                    label: 'Students',
                    value: '$totalStudents',
                    icon: Icons.people_rounded,
                    gradient: const [Color(0xFF1B5E20), Color(0xFF43A047)],
                  ),
                ]),
              ),
            ),

            // ── Quick Actions ────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 14),
                child: Text('Quick Actions',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildListDelegate([
                  _ActionCard(
                    icon: Icons.how_to_reg_rounded,
                    label: 'Attendance',
                    subtitle: "Mark today's roll",
                    gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    onTap: () => _pickClass(context, classes, (cls) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AttendanceScreen(
                          classId: cls['id'] as String,
                          className: 'Class ${cls['name']} - ${cls['section']}',
                        )));
                    }),
                  ),
                  _ActionCard(
                    icon: Icons.grade_rounded,
                    label: 'Add Marks',
                    subtitle: 'Enter exam scores',
                    gradient: const [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddMarksScreen())),
                  ),
                  _ActionCard(
                    icon: Icons.assignment_rounded,
                    label: 'Homework',
                    subtitle: 'Assign & track work',
                    gradient: const [Color(0xFFBF360C), Color(0xFFE64A19)],
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TeacherHomeworkListScreen()))
                      .then((_) => ref.invalidate(teacherDashboardProvider)),
                  ),
                  _ActionCard(
                    icon: Icons.schedule_rounded,
                    label: 'Timetable',
                    subtitle: 'View class schedule',
                    gradient: const [Color(0xFF4A148C), Color(0xFF6A1B9A)],
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TimetableScreen())),
                  ),
                  _ActionCard(
                    icon: Icons.send_rounded,
                    label: 'Notify Parents',
                    subtitle: 'Send updates home',
                    gradient: const [Color(0xFF006064), Color(0xFF00838F)],
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SendNotificationScreen())),
                  ),
                  _ActionCard(
                    icon: Icons.campaign_rounded,
                    label: 'Notifications',
                    subtitle: 'View sent alerts',
                    gradient: const [Color(0xFF311B92), Color(0xFF4527A0)],
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const NotificationsListScreen())),
                  ),
                ]),
              ),
            ),

            // ── My Classes ───────────────────────────────────
            if (classes.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 14),
                  child: Text('My Classes',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final cls = classes[i] as Map<String, dynamic>;
                    return _ClassCard(
                      cls: cls,
                      index: i,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ClassStudentsScreen(
                          classId: cls['id'] as String,
                          className: 'Class ${cls['name']} - ${cls['section']}',
                        ))),
                    );
                  },
                  childCount: classes.length,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ]);
        },
      ),
    );
  }
}

// ── Header widget ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String firstName, initials, greeting, dateStr;
  final int classCount, hwCount;

  const _Header({
    required this.firstName,
    required this.initials,
    required this.greeting,
    required this.dateStr,
    required this.classCount,
    required this.hwCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2472), Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Decorative circles
        Positioned(right: -40, top: -30,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04)))),
        Positioned(right: 50, top: 80,
          child: Container(width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04)))),
        Positioned(left: -20, bottom: -30,
          child: Container(width: 130, height: 130,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.03)))),
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Avatar
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Text(initials,
                    style: const TextStyle(
                      color: Color(0xFF0D47A1),
                      fontSize: 20, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, $firstName! 👋',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 19,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 11, color: Colors.white54),
                      const SizedBox(width: 5),
                      Text(dateStr,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    ]),
                  ],
                )),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                _chip(Icons.class_rounded,
                    '$classCount ${classCount == 1 ? 'Class' : 'Classes'}'),
                const SizedBox(width: 8),
                _chip(Icons.assignment_rounded, '$hwCount Active HW'),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.22)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white70),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.15),
                blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            if (onTap != null) ...[
              const SizedBox(height: 5),
              Text('View all →',
                  style: TextStyle(
                      fontSize: 10,
                      color: gradient[0],
                      fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      ),
    ),
  );
}

// ── Action card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.42),
            blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.08),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(children: [
              // Top-right decorative circle
              Positioned(right: -18, top: -18,
                child: Container(width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.09)))),
              // Bottom-left decorative circle
              Positioned(left: -10, bottom: -20,
                child: Container(width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(13)),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const Spacer(),
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 11)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Class card ────────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> cls;
  final int index;
  final VoidCallback? onTap;

  const _ClassCard({required this.cls, required this.index, this.onTap});

  static const _palette = [
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF6A1B9A),
    Color(0xFFBF360C), Color(0xFF006064), Color(0xFF4527A0),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[index % _palette.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 72,
              child: Row(children: [
                // Colored left bar
                Container(
                  width: 5, height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.45)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16)),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.class_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class ${cls['name']} – ${cls['section']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.people_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${cls['student_count'] ?? 0} students',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: color),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
