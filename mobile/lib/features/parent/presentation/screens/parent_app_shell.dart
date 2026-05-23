import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'parent_attendance_screen.dart';
import 'parent_homework_screen.dart';
import 'parent_marks_screen.dart';
import 'parent_announcements_screen.dart';
import 'parent_timetable_screen.dart';
import 'parent_profile_screen.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final parentDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.parentDashboard);
  return r.data['data'] as Map<String, dynamic>;
});

// ── Theme ──────────────────────────────────────────────────────────────────────

const _kNavy = Color(0xFF1A237E);

// ── Shell ─────────────────────────────────────────────────────────────────────

class ParentAppShell extends ConsumerStatefulWidget {
  const ParentAppShell({super.key});

  @override
  ConsumerState<ParentAppShell> createState() => _ParentAppShellState();
}

class _ParentAppShellState extends ConsumerState<ParentAppShell> {
  int _tab = 0;

  String? _firstStudentId;
  String? _firstStudentName;
  String? _firstClassId;
  String? _firstClassName;

  void _resolveStudent(Map<String, dynamic> data) {
    if (_firstStudentId != null) return;
    final students = (data['students'] as List?)
            ?.where((s) => s != null && s['full_name'] != null)
            .toList() ?? [];
    if (students.isEmpty) return;
    final s = students[0] as Map<String, dynamic>;
    _firstStudentId = s['id'] as String?;
    _firstStudentName = s['full_name'] as String?;
    _firstClassId = s['class_id'] as String?;
    _firstClassName = 'Class ${s['class_name']} - ${s['section']}';
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(parentDashboardProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: dashAsync.when(
        loading: () => const _ShellSkeleton(),
        error: (e, _) => Scaffold(
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Could not connect', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('$e', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => ref.invalidate(parentDashboardProvider),
                child: const Text('Retry')),
          ])),
        ),
        data: (data) {
          _resolveStudent(data);
          return IndexedStack(
            index: _tab,
            children: [
              _HomeTab(data: data, onTabChange: (i) => setState(() => _tab = i)),
              _firstStudentId != null
                  ? ParentAttendanceScreen(studentId: _firstStudentId!,
                      studentName: _firstStudentName ?? 'Student', embedded: true)
                  : const _NoStudentPlaceholder(feature: 'Attendance'),
              _firstClassId != null
                  ? ParentHomeworkScreen(classId: _firstClassId!,
                      className: _firstClassName ?? '', embedded: true)
                  : const _NoStudentPlaceholder(feature: 'Homework'),
              _firstStudentId != null
                  ? ParentMarksScreen(studentId: _firstStudentId!,
                      studentName: _firstStudentName ?? 'Student', embedded: true)
                  : const _NoStudentPlaceholder(feature: 'Marks'),
              _MoreTab(data: data),
            ],
          );
        },
      ),
      bottomNavigationBar: _BottomNav(
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int current;
  final void Function(int) onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(children: [
            _NavBtn(icon: Icons.home_rounded,         label: 'Home',       idx: 0, cur: current, onTap: onTap),
            _NavBtn(icon: Icons.how_to_reg_rounded,   label: 'Attendance', idx: 1, cur: current, onTap: onTap),
            _NavBtn(icon: Icons.assignment_rounded,   label: 'Homework',   idx: 2, cur: current, onTap: onTap),
            _NavBtn(icon: Icons.grade_rounded,        label: 'Marks',      idx: 3, cur: current, onTap: onTap),
            _NavBtn(icon: Icons.more_horiz_rounded,   label: 'More',       idx: 4, cur: current, onTap: onTap),
          ]),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx, cur;
  final void Function(int) onTap;
  const _NavBtn({required this.icon, required this.label,
      required this.idx, required this.cur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = idx == cur;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(idx),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: active ? _kNavy.withOpacity(0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: active ? _kNavy : const Color(0xFFAAAAAA)),
          ),
          Text(label,
            style: TextStyle(fontSize: 9.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _kNavy : const Color(0xFFAAAAAA))),
        ]),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  final Map<String, dynamic> data;
  final void Function(int) onTabChange;
  const _HomeTab({required this.data, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentName  = data['full_name']   as String? ?? 'Parent';
    final schoolName  = data['school_name'] as String? ?? 'School App';
    final students    = (data['students'] as List?)
        ?.where((s) => s != null && s['full_name'] != null).toList() ?? [];
    final announcements = (data['announcements'] as List?) ?? [];

    final firstStudent = students.isNotEmpty ? students[0] as Map<String, dynamic> : null;
    final firstClassId  = firstStudent?['class_id'] as String?;
    final firstClassName = firstStudent != null
        ? 'Class ${firstStudent['class_name']} - ${firstStudent['section']}' : '';

    Future<void> dismissAnn(String id) async {
      try {
        await ApiClient.instance.delete(ApiConstants.parentDismissAnnouncement(id));
        ref.invalidate(parentDashboardProvider);
      } on DioException catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),

      // ── App Bar (matches reference: dark navy, school name, bell + power) ──
      appBar: AppBar(
        backgroundColor: _kNavy,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(schoolName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white),
              overflow: TextOverflow.ellipsis),
          ),
        ]),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () => onTabChange(4),
              ),
              if (announcements.isNotEmpty)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5252), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),

      body: ListView(
        padding: EdgeInsets.zero,
        children: [

          // ── Child info strip ─────────────────────────────────────────
          if (firstStudent != null)
            _ChildStrip(student: firstStudent, parentName: parentName),

          const SizedBox(height: 8),

          // ── Announcement ticker ──────────────────────────────────────
          if (announcements.isNotEmpty)
            _AnnouncementTicker(
              ann: announcements[0] as Map<String, dynamic>,
              total: announcements.length,
              onDismiss: () => dismissAnn((announcements[0] as Map)['id'] as String),
              onViewAll: () => onTabChange(4),
            ),

          if (announcements.isNotEmpty) const SizedBox(height: 8),

          // ── Quick Links ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(children: [
              const Text('Quick Links',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E))),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _CircleLink(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Fee\nPayment',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fees module coming soon'))),
                ),
                _CircleLink(
                  icon: Icons.campaign_rounded,
                  label: 'Notices',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ParentAnnouncementsScreen())),
                ),
                _CircleLink(
                  icon: Icons.assignment_rounded,
                  label: 'Daily\nHomework',
                  onTap: () => onTabChange(2),
                ),
                _CircleLink(
                  icon: Icons.schedule_rounded,
                  label: 'Timetable',
                  onTap: () {
                    if (firstClassId == null) return;
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ParentTimetableScreen(
                        classId: firstClassId, className: firstClassName)));
                  },
                ),
              ]),
            ]),
          ),

          // ── Quick Actions (gradient cards — same design as teacher) ────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Quick Actions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E))),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  _ActionCard(
                    icon: Icons.how_to_reg_rounded,
                    label: 'Attendance',
                    subtitle: 'Monthly report',
                    gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    onTap: () => onTabChange(1),
                  ),
                  _ActionCard(
                    icon: Icons.grade_rounded,
                    label: 'Marks',
                    subtitle: 'Exam scores',
                    gradient: const [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    onTap: () => onTabChange(3),
                  ),
                  _ActionCard(
                    icon: Icons.assignment_rounded,
                    label: 'Homework',
                    subtitle: 'Daily assignments',
                    gradient: const [Color(0xFFBF360C), Color(0xFFE64A19)],
                    onTap: () => onTabChange(2),
                  ),
                  _ActionCard(
                    icon: Icons.schedule_rounded,
                    label: 'Timetable',
                    subtitle: 'Class schedule',
                    gradient: const [Color(0xFF4A148C), Color(0xFF6A1B9A)],
                    onTap: () {
                      if (firstClassId == null) return;
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ParentTimetableScreen(
                          classId: firstClassId, className: firstClassName)));
                    },
                  ),
                  _ActionCard(
                    icon: Icons.campaign_rounded,
                    label: 'Announcements',
                    subtitle: 'School notices',
                    gradient: const [Color(0xFF006064), Color(0xFF00838F)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ParentAnnouncementsScreen())),
                  ),
                  _ActionCard(
                    icon: Icons.person_rounded,
                    label: 'My Profile',
                    subtitle: 'Account details',
                    gradient: const [Color(0xFF1A237E), Color(0xFF283593)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ParentProfileScreen())),
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Child info strip ──────────────────────────────────────────────────────────

class _ChildStrip extends StatelessWidget {
  final Map<String, dynamic> student;
  final String parentName;
  const _ChildStrip({required this.student, required this.parentName});

  Color get _statusColor {
    switch (student['today_status'] as String?) {
      case 'present':  return const Color(0xFF2E7D32);
      case 'absent':   return const Color(0xFFC62828);
      case 'late':     return const Color(0xFFE65100);
      default:         return const Color(0xFF757575);
    }
  }

  String get _statusLabel {
    switch (student['today_status'] as String?) {
      case 'present':  return 'Present Today';
      case 'absent':   return 'Absent Today';
      case 'late':     return 'Late Today';
      default:         return 'Status Not Marked';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name   = student['full_name']    as String? ?? '';
    final cls    = 'Class ${student['class_name']} - ${student['section']}';
    final admNo  = 'Adm: ${student['admission_no'] ?? ''}';
    final pct    = student['month_attendance_pct'] as int? ?? 0;
    final hwCnt  = student['active_hw_count'] as int? ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        // Avatar
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person_rounded, color: _kNavy, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                color: Color(0xFF1A1A2E))),
          const SizedBox(height: 2),
          Text('$cls  ·  $admNo',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(_statusLabel,
              style: TextStyle(fontSize: 11, color: _statusColor,
                  fontWeight: FontWeight.w600)),
          ]),
        ])),
        // Stats mini
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _MiniStat(value: '$pct%', label: 'Attendance',
            color: pct >= 75 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
          const SizedBox(height: 4),
          _MiniStat(value: '$hwCnt', label: 'Active HW',
            color: const Color(0xFFE65100)),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MiniStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(value,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      Text(label,
        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
    ]);
  }
}

// ── Announcement ticker ───────────────────────────────────────────────────────

class _AnnouncementTicker extends StatelessWidget {
  final Map<String, dynamic> ann;
  final int total;
  final VoidCallback onDismiss, onViewAll;
  const _AnnouncementTicker({required this.ann, required this.total,
      required this.onDismiss, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onViewAll,
      child: Container(
        color: const Color(0xFFE8EAF6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kNavy, borderRadius: BorderRadius.circular(4)),
            child: Text('$total',
              style: const TextStyle(color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.campaign_rounded, color: _kNavy, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(ann['title'] as String? ?? '',
              style: const TextStyle(fontSize: 12, color: _kNavy,
                  fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.chevron_right_rounded, color: _kNavy, size: 16),
          IconButton(
            icon: const Icon(Icons.close, size: 14, color: _kNavy),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            onPressed: onDismiss,
          ),
        ]),
      ),
    );
  }
}

// ── Circle link (Quick Links style) ──────────────────────────────────────────

class _CircleLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CircleLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC5CAE9), width: 1.5),
            ),
            child: Icon(icon, color: _kNavy, size: 26),
          ),
          const SizedBox(height: 7),
          Text(label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF333333),
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Do More tile ──────────────────────────────────────────────────────────────

// ── Action card (matches teacher dashboard gradient cards exactly) ─────────────

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
              gradient: LinearGradient(colors: gradient,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(children: [
              Positioned(right: -18, top: -18,
                child: Container(width: 90, height: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.09)))),
              Positioned(left: -10, bottom: -20,
                child: Container(width: 60, height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(13)),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── More tab ──────────────────────────────────────────────────────────────────

class _MoreTab extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _MoreTab({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = (data['students'] as List?)
        ?.where((s) => s != null && s['full_name'] != null).toList() ?? [];
    final firstClassId = students.isNotEmpty ? students[0]['class_id'] as String? : null;
    final firstClassName = students.isNotEmpty
        ? 'Class ${students[0]['class_name']} - ${students[0]['section']}' : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: _kNavy,
        automaticallyImplyLeading: false,
        title: const Text('More'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MoreTile(icon: Icons.person_rounded, label: 'My Profile', color: _kNavy,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ParentProfileScreen()))),
          _MoreTile(icon: Icons.announcement_rounded, label: 'All Announcements',
            color: _kNavy,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ParentAnnouncementsScreen()))),
          if (firstClassId != null)
            _MoreTile(icon: Icons.schedule_rounded, label: 'Timetable', color: _kNavy,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ParentTimetableScreen(
                  classId: firstClassId, className: firstClassName)))),
          _MoreTile(icon: Icons.account_balance_wallet_rounded, label: 'Fees',
            color: _kNavy,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fees module coming soon')))),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('Sign Out',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MoreTile({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textMuted, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Shell skeleton ─────────────────────────────────────────────────────────────

class _ShellSkeleton extends StatelessWidget {
  const _ShellSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: _kNavy, title: const Text('Loading...')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SkeletonCard(child: Row(children: [
            SkeletonLoader(width: 46, height: 46, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonLoader(width: 140, height: 14),
              const SizedBox(height: 6),
              SkeletonLoader(width: 100, height: 11),
            ])),
          ])),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (_) => Column(children: [
              SkeletonLoader(width: 56, height: 56, borderRadius: 28),
              const SizedBox(height: 6),
              SkeletonLoader(width: 44, height: 10),
            ]))),
        ]),
      ),
    );
  }
}

// ── No student placeholder ─────────────────────────────────────────────────────

class _NoStudentPlaceholder extends StatelessWidget {
  final String feature;
  const _NoStudentPlaceholder({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: _kNavy, title: Text(feature),
          automaticallyImplyLeading: false),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_off_rounded, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 16),
        const Text('No students linked',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Contact your school to link your child.',
          style: TextStyle(color: AppColors.textSecondary)),
      ])),
    );
  }
}
