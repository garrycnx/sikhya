import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_homework_list_screen.dart';
import 'class_students_screen.dart';
import 'student_profile_screen.dart';
import 'teacher_profile_screen.dart';

final _allStudentsProvider = FutureProvider<List<dynamic>>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherAllStudents);
  return r.data['data'] as List<dynamic>;
});

class TeacherAppShell extends ConsumerStatefulWidget {
  const TeacherAppShell({super.key});

  @override
  ConsumerState<TeacherAppShell> createState() => _TeacherAppShellState();
}

class _TeacherAppShellState extends ConsumerState<TeacherAppShell> {
  int _tab = 0;

  // Cache class list from dashboard for the Classes tab
  List _classes = [];

  void updateClasses(List c) {
    if (_classes.isEmpty && c.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _classes = c);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tab,
        children: [
          // Tab 0 — Dashboard
          _DashboardTabWrapper(onClassesLoaded: updateClasses),
          // Tab 1 — Homework list
          const TeacherHomeworkListScreen(),
          // Tab 2 — Classes
          _ClassesTab(classes: _classes),
          // Tab 3 — Students
          const _AllStudentsTab(),
          // Tab 4 — Profile
          const TeacherProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(children: [
              _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard',
                  index: 0, current: _tab, onTap: (i) => setState(() => _tab = i)),
              _NavItem(icon: Icons.assignment_rounded, label: 'Homework',
                  index: 1, current: _tab, onTap: (i) => setState(() => _tab = i)),
              _NavItem(icon: Icons.class_rounded, label: 'Classes',
                  index: 2, current: _tab, onTap: (i) => setState(() => _tab = i)),
              _NavItem(icon: Icons.people_rounded, label: 'Students',
                  index: 3, current: _tab, onTap: (i) => setState(() => _tab = i)),
              _NavItem(icon: Icons.person_rounded, label: 'Profile',
                  index: 4, current: _tab, onTap: (i) => setState(() => _tab = i)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Nav item (same design as parent shell) ─────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF0A2472).withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon,
                color: active ? const Color(0xFF0A2472) : AppColors.textMuted,
                size: 22),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? const Color(0xFF0A2472) : AppColors.textMuted)),
        ]),
      ),
    );
  }
}

// ── Dashboard wrapper ──────────────────────────────────────────────────────────
// Wraps TeacherDashboardScreen and extracts class list when data loads

class _DashboardTabWrapper extends ConsumerWidget {
  final void Function(List) onClassesLoaded;
  const _DashboardTabWrapper({required this.onClassesLoaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(teacherDashboardProvider, (_, next) {
      next.whenData((d) {
        final c = (d['my_classes'] as List?) ?? [];
        if (c.isNotEmpty) onClassesLoaded(c);
      });
    });
    return const TeacherDashboardScreen();
  }
}

// ── All Students tab ───────────────────────────────────────────────────────────

class _AllStudentsTab extends ConsumerStatefulWidget {
  const _AllStudentsTab();

  @override
  ConsumerState<_AllStudentsTab> createState() => _AllStudentsTabState();
}

class _AllStudentsTabState extends ConsumerState<_AllStudentsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  static Uint8List? _decodePhoto(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    try {
      final d = photo.contains(',') ? photo.split(',').last : photo;
      return base64Decode(d);
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(_allStudentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('All Students'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_allStudentsProvider),
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) {
          // Filter
          final filtered = _query.isEmpty ? students : students.where((s) {
            final name = (s['full_name'] as String).toLowerCase();
            final adm  = (s['admission_no'] as String).toLowerCase();
            final cls  = '${s['class_name']} ${s['section']}'.toLowerCase();
            return name.contains(_query) || adm.contains(_query) || cls.contains(_query);
          }).toList();

          // Group by class
          final Map<String, List<dynamic>> grouped = {};
          for (final s in filtered) {
            final key = 'Class ${s['class_name']} – ${s['section']}';
            grouped.putIfAbsent(key, () => []).add(s);
          }
          final keys = grouped.keys.toList()..sort();

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, admission no, class...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${filtered.length} student${filtered.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                ? const Center(child: Text('No students found'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: keys.length,
                    itemBuilder: (_, gi) {
                      final className = keys[gi];
                      final classStudents = grouped[className]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                            child: Text(className,
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary, letterSpacing: 0.4)),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8)],
                            ),
                            child: Column(children: classStudents.asMap().entries.map((e) {
                              final idx = e.key;
                              final s = e.value as Map<String, dynamic>;
                              final photoBytes = _decodePhoto(s['profile_photo'] as String?);
                              final initials = (s['full_name'] as String).isNotEmpty
                                ? (s['full_name'] as String)[0].toUpperCase() : '?';
                              final isLast = idx == classStudents.length - 1;
                              return Column(children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 2),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: photoBytes != null
                                      ? MemoryImage(photoBytes) : null,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: photoBytes == null
                                      ? Text(initials, style: const TextStyle(
                                          color: AppColors.primary, fontWeight: FontWeight.bold))
                                      : null,
                                  ),
                                  title: Text(s['full_name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text(
                                    'Adm: ${s['admission_no']}  ·  Roll: ${s['roll_number'] ?? '-'}',
                                    style: const TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary)),
                                  trailing: const Icon(Icons.chevron_right,
                                    color: AppColors.textSecondary, size: 18),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => StudentProfileScreen(
                                      studentId: s['id'] as String,
                                      studentName: s['full_name'] as String,
                                    ),
                                  )),
                                ),
                                if (!isLast) const Divider(height: 1, indent: 54),
                              ]);
                            }).toList()),
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Classes tab ────────────────────────────────────────────────────────────────

class _ClassesTab extends ConsumerWidget {
  final List classes;
  const _ClassesTab({required this.classes});

  static const _palette = [
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF6A1B9A),
    Color(0xFFBF360C), Color(0xFF006064), Color(0xFF4527A0),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If classes not loaded yet, fall back to dashboard provider
    final dashAsync = ref.watch(teacherDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Classes'),
        automaticallyImplyLeading: false,
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final list = (data['my_classes'] as List?) ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.class_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No classes assigned',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Contact admin to assign a class.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final cls = list[i] as Map<String, dynamic>;
              final color = _palette[i % _palette.length];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05),
                        blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.class_rounded, color: Colors.white, size: 22),
                  ),
                  title: Text('Class ${cls['name']} – ${cls['section']}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text('${cls['student_count'] ?? 0} students',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(9)),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClassStudentsScreen(
                      classId: cls['id'] as String,
                      className: 'Class ${cls['name']} - ${cls['section']}',
                    ))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
