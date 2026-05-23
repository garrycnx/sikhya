import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'teacher_dashboard_screen.dart';

class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty && p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(teacherDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final teacher = data['teacher'] as Map<String, dynamic>;
          final name    = teacher['full_name'] as String? ?? 'Teacher';
          final mobile  = teacher['mobile']    as String? ?? '—';
          final email   = teacher['email']     as String? ?? '—';
          final classes = (data['my_classes'] as List?) ?? [];
          final totalStudents = classes.fold<int>(
              0, (s, c) => s + ((c as Map)['student_count'] as int? ?? 0));

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: const Color(0xFF0A2472),
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0A2472), Color(0xFF1565C0), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(children: [
                      Positioned(right: -40, top: -30,
                        child: Container(width: 200, height: 200,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05)))),
                      SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 84, height: 84,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD54F),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 16, offset: const Offset(0, 4))],
                              ),
                              child: Center(child: Text(_initials(name),
                                style: const TextStyle(
                                  color: Color(0xFF0D47A1),
                                  fontSize: 30, fontWeight: FontWeight.w900))),
                            ),
                            const SizedBox(height: 12),
                            Text(name,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Teacher',
                                style: TextStyle(
                                  color: Colors.white70, fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                            ),
                            const SizedBox(height: 16),
                            // Stats chips
                            Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              _chip(Icons.class_rounded,
                                  '${classes.length} ${classes.length == 1 ? 'Class' : 'Classes'}'),
                              const SizedBox(width: 8),
                              _chip(Icons.people_rounded, '$totalStudents Students'),
                            ]),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              // ── Contact info ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _sectionLabel('Contact Information'),
                    const SizedBox(height: 10),
                    _InfoCard(children: [
                      _InfoRow(Icons.phone_rounded, 'Mobile', mobile),
                      if (email.isNotEmpty && email != '—') ...[
                        const Divider(height: 1),
                        _InfoRow(Icons.email_rounded, 'Email', email),
                      ],
                    ]),
                  ]),
                ),
              ),

              // ── Classes ──────────────────────────────────────────────────
              if (classes.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      _sectionLabel('My Classes'),
                      const SizedBox(height: 10),
                      _InfoCard(children: classes.asMap().entries.map((e) {
                        final c = e.value as Map<String, dynamic>;
                        final isLast = e.key == classes.length - 1;
                        return Column(children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A2472).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.class_rounded,
                                  color: Color(0xFF0A2472), size: 20),
                            ),
                            title: Text('Class ${c['name']} – ${c['section']}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Text('${c['student_count'] ?? 0} students',
                              style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                          ),
                          if (!isLast) const Divider(height: 1),
                        ]);
                      }).toList()),
                    ]),
                  ),
                ),

              // ── Sign out ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authNotifierProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                    label: const Text('Sign Out',
                      style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 0),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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

  Widget _sectionLabel(String t) => Text(t,
    style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: AppColors.textSecondary, letterSpacing: 0.5));
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2472).withOpacity(0.08),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: const Color(0xFF0A2472), size: 17),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}
