import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'parent_app_shell.dart';

class ParentProfileScreen extends ConsumerWidget {
  const ParentProfileScreen({super.key});

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return p.isNotEmpty && p[0].isNotEmpty ? p[0][0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(parentDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final name   = data['full_name'] as String? ?? 'Parent';
          final mobile = data['mobile']    as String? ?? '—';
          final email  = data['email']     as String? ?? '—';
          final students = (data['students'] as List?)
              ?.where((s) => s != null && s['full_name'] != null)
              .toList() ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: const Color(0xFF0A2472),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0A2472), Color(0xFF1565C0), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Center(child: Text(_initials(name),
                              style: const TextStyle(
                                color: Color(0xFF0D47A1),
                                fontSize: 28, fontWeight: FontWeight.w900))),
                          ),
                          const SizedBox(height: 12),
                          Text(name,
                            style: const TextStyle(
                              color: Colors.white, fontSize: 20,
                              fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Parent / Guardian',
                              style: TextStyle(
                                color: Colors.white70, fontSize: 12,
                                fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Contact info ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

              // ── Linked children ──────────────────────────────────────────
              if (students.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final s = students[i] as Map<String, dynamic>;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(16, i == 0 ? 20 : 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (i == 0) ...[
                              _sectionLabel('Linked Children'),
                              const SizedBox(height: 10),
                            ],
                            _StudentDetailCard(student: s),
                          ],
                        ),
                      );
                    },
                    childCount: students.length,
                  ),
                ),

              // ── Actions ──────────────────────────────────────────────────
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
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: AppColors.primary, size: 17),
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

class _StudentDetailCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentDetailCard({required this.student});

  static int? _calcAge(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    try {
      final birth = DateTime.parse(dob);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) age--;
      return age;
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final name      = student['full_name'] as String? ?? '';
    final className = student['class_name'] as String? ?? '';
    final section   = student['section']    as String? ?? '';
    final admNo     = student['admission_no'] as String? ?? '';
    final address   = student['address']    as String?;
    final emergency = student['emergency_contact'] as String?;
    final dob       = student['date_of_birth'] as String?;
    final age       = _calcAge(dob);

    final initials  = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800, fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Class $className – $section  ·  Adm: $admNo',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
              ],
            )),
          ]),
        ),
        const Divider(height: 1),
        // Detail rows
        if (age != null) _DetailRow(
          Icons.cake_rounded, 'Age', '$age years old'),
        if (address != null && address.isNotEmpty) _DetailRow(
          Icons.home_rounded, 'Address', address),
        if (emergency != null && emergency.isNotEmpty) _DetailRow(
          Icons.emergency_rounded, 'Emergency Contact', emergency),
        if ((age == null) && (address == null || address.isEmpty) &&
            (emergency == null || emergency.isEmpty))
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Text('No additional details on file.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 4),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primary, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        )),
      ]),
    );
  }
}
