import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../auth/presentation/providers/auth_provider.dart';

final parentDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.parentDashboard);
  return r.data['data'] as Map<String, dynamic>;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(parentDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final parentName = data['full_name'] ?? 'Parent';
          final students = (data['students'] as List?)
              ?.where((s) => s != null && s['full_name'] != null)
              .toList() ?? [];
          final studentName = students.isNotEmpty
              ? (students[0]['full_name'] as String).split(' ').first
              : null;
          final firstClassId  = students.isNotEmpty ? students[0]['class_id']  as String? : null;
          final firstClassName = students.isNotEmpty
              ? 'Class ${students[0]['class_name']} - ${students[0]['section']}'
              : '';
          final announcements = (data['announcements'] as List?) ?? [];

          Future<void> dismissAnnouncement(String id) async {
            try {
              await ApiClient.instance
                  .delete(ApiConstants.parentDismissAnnouncement(id));
              ref.invalidate(parentDashboardProvider);
            } on DioException catch (_) {}
          }

          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        studentName != null
                            ? 'Welcome, ${studentName}\'s Parents! 👋'
                            : 'Welcome, $parentName! 👋',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(parentName,
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

            // Students
            if (students.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('My Children',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ...students.map((s) => _StudentCard(student: s)),
                  ]),
                ),
              ),

            // Announcements
            if (announcements.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(children: [
                    const Icon(Icons.campaign_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('Announcements',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final ann = announcements[i] as Map<String, dynamic>;
                    return _AnnouncementCard(
                      announcement: ann,
                      onDismiss: () => dismissAnnouncement(ann['id'] as String),
                    );
                  },
                  childCount: announcements.length,
                ),
              ),
            ],

            // Quick access grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: const Text('Quick Access',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate([
                  _ActionCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'Attendance',
                    color: const Color(0xFF42A5F5),
                    onTap: students.isNotEmpty
                        ? () => context.go(
                            '/parent/attendance?student_id=${students[0]['id']}&student_name=${Uri.encodeComponent(students[0]['full_name'] as String)}')
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No students linked to your account'))),
                  ),
                  _ActionCard(
                    icon: Icons.grade_rounded,
                    label: 'Marks',
                    color: const Color(0xFF66BB6A),
                    onTap: students.isNotEmpty
                        ? () => context.go(
                            '/parent/marks?student_id=${students[0]['id']}&student_name=${Uri.encodeComponent(students[0]['full_name'] as String)}')
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No students linked to your account'))),
                  ),
                  _ActionCard(
                    icon: Icons.assignment_rounded,
                    label: 'Homework',
                    color: const Color(0xFFFFA726),
                    onTap: firstClassId != null
                        ? () => context.go(
                            '/parent/homework?class_id=$firstClassId&class_name=${Uri.encodeComponent(firstClassName)}')
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No class assigned yet'))),
                  ),
                  _ActionCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Fees',
                    color: const Color(0xFFEF5350),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fees module coming soon'))),
                  ),
                  _ActionCard(
                    icon: Icons.schedule_rounded,
                    label: 'Timetable',
                    color: const Color(0xFFAB47BC),
                    onTap: firstClassId != null
                        ? () => context.go(
                            '/parent/timetable?class_id=$firstClassId&class_name=${Uri.encodeComponent(firstClassName)}')
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No class assigned yet'))),
                  ),
                  _ActionCard(
                    icon: Icons.campaign_rounded,
                    label: 'Announcements',
                    color: const Color(0xFF26C6DA),
                    onTap: () => context.go('/parent/announcements'),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(student['full_name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(
            '${student['class_name'] ?? ''} - ${student['section'] ?? ''} · ${student['admission_no'] ?? ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ])),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionCard(
      {required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final VoidCallback onDismiss;
  const _AnnouncementCard(
      {required this.announcement, required this.onDismiss});

  Color get _typeColor {
    switch (announcement['type'] as String?) {
      case 'exam':      return const Color(0xFF66BB6A);
      case 'holiday':   return const Color(0xFF42A5F5);
      case 'fee':       return const Color(0xFFEF5350);
      case 'emergency': return Colors.deepOrange;
      default:          return AppColors.primary;
    }
  }

  IconData get _typeIcon {
    switch (announcement['type'] as String?) {
      case 'exam':      return Icons.grade_rounded;
      case 'holiday':   return Icons.beach_access_rounded;
      case 'fee':       return Icons.payment_rounded;
      case 'emergency': return Icons.warning_amber_rounded;
      default:          return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final classTarget = announcement['class_name'] != null
        ? 'Class ${announcement['class_name']} - ${announcement['section']}'
        : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _typeColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_typeIcon, color: _typeColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(announcement['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(announcement['body'] as String,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            if (classTarget != null) ...[
              Icon(Icons.class_rounded, size: 11, color: _typeColor),
              const SizedBox(width: 3),
              Text(classTarget,
                  style: TextStyle(
                      fontSize: 11, color: _typeColor, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
            ],
            Icon(Icons.access_time_rounded, size: 11, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Text(_formatDate(announcement['created_at'] as String),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ])),
        // Dismiss button
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
          tooltip: 'Dismiss',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Remove Announcement'),
              content: const Text(
                  'Remove this announcement from your view?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDismiss();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text('Remove',
                        style: TextStyle(color: Colors.white))),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
