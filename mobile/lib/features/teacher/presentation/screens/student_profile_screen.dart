import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'add_edit_student_screen.dart';

final studentProfileProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await ApiClient.instance.get(ApiConstants.studentProfile(id));
  return r.data['data'] as Map<String, dynamic>;
});

class StudentProfileScreen extends ConsumerWidget {
  final String studentId;
  final String studentName;
  const StudentProfileScreen({super.key, required this.studentId, required this.studentName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentProfileProvider(studentId));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final student    = data['student'] as Map<String, dynamic>;
          final parents    = (data['parents'] as List?) ?? [];
          final marks      = (data['marks'] as List?) ?? [];
          final attSummary = data['attendance_summary'] as Map<String, dynamic>? ?? {};
          final recentAtt  = (data['recent_attendance'] as List?) ?? [];
          final recentHw   = (data['recent_homework'] as List?) ?? [];
          final photoBytes = _decodePhoto(student['profile_photo'] as String?);

          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: const Color(0xFF1565C0),
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddEditStudentScreen(
                      classId: '', existing: student),
                  )).then((_) => ref.invalidate(studentProfileProvider(studentId))),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, color: Colors.white),
                  tooltip: 'Transfer Class',
                  onPressed: () => _showTransferDialog(context, ref, student),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) {
                    if (v == 'remove') _confirmRemove(context, ref, student);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'remove',
                      child: Row(children: [
                        Icon(Icons.person_remove, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Remove from class', style: TextStyle(color: Colors.red)),
                      ])),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 56),
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: photoBytes == null
                        ? Text(
                            student['full_name'].isNotEmpty
                              ? student['full_name'][0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                        : null,
                    ),
                    const SizedBox(height: 10),
                    Text(student['full_name'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('${student['class_name']} - ${student['section']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ),
              ),
            ),

            // Info chips
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                _chip(Icons.badge_outlined, 'Adm: ${student['admission_no']}'),
                if (student['roll_number'] != null)
                  _chip(Icons.numbers, 'Roll: ${student['roll_number']}'),
                if (student['gender'] != null)
                  _chip(Icons.person_outline, student['gender'] as String),
                if (student['date_of_birth'] != null)
                  _chip(Icons.cake_outlined, student['date_of_birth'] as String),
              ]),
            )),

            // Contact information
            SliverToBoxAdapter(child: _sectionCard(
              title: 'Contact Information',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (student['address'] != null && (student['address'] as String).isNotEmpty) ...[
                  _contactRow(Icons.home_outlined, 'Address', student['address'] as String),
                  const SizedBox(height: 10),
                ],
                if (student['emergency_contact'] != null && (student['emergency_contact'] as String).isNotEmpty) ...[
                  _contactRow(Icons.emergency_outlined, 'Emergency Contact', student['emergency_contact'] as String),
                  const SizedBox(height: 10),
                ],
                if ((student['address'] == null || (student['address'] as String).isEmpty) &&
                    (student['emergency_contact'] == null || (student['emergency_contact'] as String).isEmpty) &&
                    parents.isEmpty)
                  const Text('No contact information available',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            )),

            // Parents / Guardian section
            SliverToBoxAdapter(child: _sectionCard(
              title: 'Parents / Guardians',
              trailing: IconButton(
                icon: const Icon(Icons.person_add_alt_1_rounded,
                    color: AppColors.primary, size: 22),
                tooltip: 'Tag parent',
                onPressed: () => _showTagParentDialog(context, ref, studentId),
              ),
              child: parents.isEmpty
                  ? const Text('No parents tagged yet. Tap + to add.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
                  : Column(children: parents.map((p) => _ParentTile(
                      parent: p as Map<String, dynamic>,
                      studentId: studentId,
                      onRemoved: () => ref.invalidate(studentProfileProvider(studentId)),
                    )).toList()),
            )),

            // Attendance summary
            SliverToBoxAdapter(child: _sectionCard(
              title: 'Attendance',
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _attStat('Present', attSummary['present'] ?? 0, Colors.green),
                _attStat('Absent',  attSummary['absent']  ?? 0, Colors.red),
                _attStat('Late',    attSummary['late']    ?? 0, Colors.orange),
                _attStat('Total',   attSummary['total']   ?? 0, AppColors.primary),
              ]),
            )),

            // Marks table
            if (marks.isNotEmpty) SliverToBoxAdapter(child: _sectionCard(
              title: 'Exam Marks',
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                border: TableBorder.all(color: const Color(0xFFEEEEEE), width: 1),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
                    children: ['Exam', 'Subject', 'Marks', 'Max']
                      .map((h) => _th(h)).toList(),
                  ),
                  ...marks.map((m) => TableRow(children: [
                    _td('${m['exam_type']}: ${m['exam_name']}'),
                    _td(m['subject_name'] as String),
                    _td(m['is_absent'] == true ? 'Absent' : '${m['marks_obtained'] ?? '-'}'),
                    _td('${m['max_marks']}'),
                  ])),
                ],
              ),
            )),

            // Recent homework
            if (recentHw.isNotEmpty) SliverToBoxAdapter(child: _sectionCard(
              title: 'Recent Homework',
              child: Column(children: recentHw.map((h) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.assignment_outlined, size: 20, color: AppColors.primary),
                title: Text(h['title'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text('${h['subject_name']} • Due: ${h['due_date']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              )).toList()),
            )),

            // Recent attendance log
            if (recentAtt.isNotEmpty) SliverToBoxAdapter(child: _sectionCard(
              title: 'Recent Attendance (last 30 days)',
              child: Column(children: recentAtt.take(10).map((a) {
                final status = a['status'] as String;
                final color = status == 'present' ? Colors.green
                  : status == 'absent' ? Colors.red
                  : status == 'late' ? Colors.orange : Colors.blue;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  title: Text(a['date'] as String,
                    style: const TextStyle(fontSize: 13)),
                  subtitle: a['remarks'] != null
                    ? Text(a['remarks'] as String,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                    : null,
                );
              }).toList()),
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]);
        },
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]),
  );

  Widget _contactRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ])),
    ],
  );

  Widget _sectionCard({required String title, required Widget child, Widget? trailing}) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        if (trailing != null) trailing,
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  );

  Widget _attStat(String label, int value, Color color) => Column(children: [
    Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  ]);

  Widget _th(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _td(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Text(t, style: const TextStyle(fontSize: 11)),
  );

  void _showTransferDialog(BuildContext context, WidgetRef ref,
      Map<String, dynamic> student) async {
    List<dynamic> classes = [];
    try {
      final r = await ApiClient.instance.get(ApiConstants.teacherAllClasses);
      classes = r.data['data'] as List<dynamic>;
      classes.removeWhere((c) => c['id'] == student['id']);
    } catch (_) {}
    if (!context.mounted) return;
    String? selected;
    await showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Transfer to Class'),
        content: DropdownButtonFormField<String>(
          hint: const Text('Select class'),
          value: selected,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
          dropdownColor: Colors.white,
          iconEnabledColor: Color(0xFF64748B),
          items: classes.map((c) => DropdownMenuItem<String>(
            value: c['id'] as String,
            child: Text('${c['name']} - ${c['section']}'),
          )).toList(),
          onChanged: (v) => setState(() => selected = v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: selected == null ? null : () async {
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.post(ApiConstants.teacherTransfer, data: {
                  'student_id': student['id'],
                  'to_class_id': selected,
                });
                ref.invalidate(studentProfileProvider(studentId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student transferred successfully')));
                }
              } on DioException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.response?.data?['error'] ?? 'Transfer failed'),
                    backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    ));
  }

  void _confirmRemove(BuildContext context, WidgetRef ref,
      Map<String, dynamic> student) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Remove Student'),
      content: Text('Remove ${student['full_name']} from class? This will deactivate the student.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiClient.instance.delete(ApiConstants.studentRemove(student['id'] as String));
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student removed')));
      }
    } on DioException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['error'] ?? 'Failed to remove student'),
        backgroundColor: Colors.red));
    }
  }

  void _showTagParentDialog(BuildContext context, WidgetRef ref, String studentId) {
    final nameCtrl   = TextEditingController();
    final mobileCtrl = TextEditingController();
    final relCtrl    = TextEditingController(text: 'parent');
    final formKey    = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tag Parent / Guardian'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Parent Name *'),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number *', prefixText: '+91 '),
              validator: (v) => (v?.length ?? 0) < 10 ? 'Enter 10-digit number' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: relCtrl,
              decoration: const InputDecoration(labelText: 'Relation (parent/guardian/etc)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              try {
                await ApiClient.instance.post(
                  ApiConstants.tagParent(studentId),
                  data: {
                    'name':     nameCtrl.text.trim(),
                    'mobile':   '+91${mobileCtrl.text.trim()}',
                    'relation': relCtrl.text.trim(),
                  },
                );
                ref.invalidate(studentProfileProvider(studentId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Parent tagged successfully')));
                }
              } on DioException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.response?.data?['error'] ?? 'Failed to tag parent'),
                    backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Tag Parent'),
          ),
        ],
      ),
    );
  }

  static Uint8List? _decodePhoto(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    try {
      final data = photo.contains(',') ? photo.split(',').last : photo;
      return base64Decode(data);
    } catch (_) { return null; }
  }
}

// ── Parent Tile ───────────────────────────────────────────────────────────────

class _ParentTile extends StatelessWidget {
  final Map<String, dynamic> parent;
  final String studentId;
  final VoidCallback onRemoved;
  const _ParentTile({required this.parent, required this.studentId, required this.onRemoved});

  @override
  Widget build(BuildContext context) {
    final relation = (parent['relation'] as String? ?? 'parent');
    final relLabel = relation[0].toUpperCase() + relation.substring(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Text(
            (parent['full_name'] as String).isNotEmpty
                ? (parent['full_name'] as String)[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(parent['full_name'] as String,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$relLabel  •  ${parent['mobile'] as String}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        IconButton(
          icon: const Icon(Icons.link_off_rounded, size: 18, color: Colors.red),
          tooltip: 'Remove',
          onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
              title: const Text('Remove Parent'),
              content: Text('Remove ${parent['full_name']} from this student?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Remove', style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
            if (ok != true) return;
            try {
              await ApiClient.instance.delete(
                  ApiConstants.removeStudentParent(studentId, parent['id'] as String));
              onRemoved();
            } catch (_) {}
          },
        ),
      ]),
    );
  }
}
