import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'add_edit_student_screen.dart';
import 'student_profile_screen.dart';
import 'attendance_screen.dart';

final classStudentsProvider = FutureProvider.family<List<dynamic>, String>((ref, classId) async {
  final r = await ApiClient.instance.get(ApiConstants.classStudents(classId));
  return r.data['data'] as List<dynamic>;
});

Uint8List? _decodePhoto(String? photo) {
  if (photo == null || photo.isEmpty) return null;
  try {
    final data = photo.contains(',') ? photo.split(',').last : photo;
    return base64Decode(data);
  } catch (_) { return null; }
}

class ClassStudentsScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;
  const ClassStudentsScreen({super.key, required this.classId, required this.className});

  @override
  ConsumerState<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends ConsumerState<ClassStudentsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _showTransferDialog(Map<String, dynamic> student) async {
    List<dynamic> classes = [];
    try {
      final r = await ApiClient.instance.get(ApiConstants.teacherAllClasses);
      classes = (r.data['data'] as List)
        .where((c) => c['id'] != widget.classId)
        .toList();
    } catch (_) {}
    if (!context.mounted) return;

    String? selected;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        title: Text('Transfer ${student['full_name']}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: DropdownButtonFormField<String>(
          hint: const Text('Select destination class'),
          value: selected,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
          dropdownColor: Colors.white,
          iconEnabledColor: Color(0xFF64748B),
          items: classes.map((c) => DropdownMenuItem<String>(
            value: c['id'] as String,
            child: Text('Class ${c['name']} - ${c['section']}'),
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
                  'student_id':  student['id'],
                  'to_class_id': selected,
                });
                ref.invalidate(classStudentsProvider(widget.classId));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Student transferred successfully')));
              } on DioException catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.response?.data?['error'] ?? 'Transfer failed'),
                  backgroundColor: Colors.red));
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(classStudentsProvider(widget.classId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.className, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.how_to_reg_rounded, color: Colors.white),
            tooltip: 'Mark Attendance',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AttendanceScreen(classId: widget.classId, className: widget.className),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.white),
            tooltip: 'Add Student',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AddEditStudentScreen(classId: widget.classId),
            )).then((_) => ref.invalidate(classStudentsProvider(widget.classId))),
          ),
        ],
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) {
          final filtered = _query.isEmpty
            ? students
            : students.where((s) {
                final name = (s['full_name'] as String).toLowerCase();
                final adm  = (s['admission_no'] as String).toLowerCase();
                return name.contains(_query) || adm.contains(_query);
              }).toList();

          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search by name or admission no...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i] as Map<String, dynamic>;
                      return _StudentTile(
                        student: s,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => StudentProfileScreen(
                            studentId: s['id'] as String,
                            studentName: s['full_name'] as String,
                          ),
                        )).then((_) => ref.invalidate(classStudentsProvider(widget.classId))),
                        onTransfer: () => _showTransferDialog(s),
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

class _StudentTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;
  final VoidCallback onTransfer;
  const _StudentTile({required this.student, required this.onTap, required this.onTransfer});

  @override
  Widget build(BuildContext context) {
    final photoBytes = _decodePhoto(student['profile_photo'] as String?);
    final initials = (student['full_name'] as String).isNotEmpty
      ? (student['full_name'] as String)[0].toUpperCase() : '?';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: photoBytes != null ? MemoryImage(photoBytes) : null,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: photoBytes == null
            ? Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
            : null,
        ),
        title: Text(student['full_name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Adm: ${student['admission_no']} • Roll: ${student['roll_number'] ?? '-'}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
            tooltip: 'Transfer Class',
            onPressed: onTransfer,
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ]),
        onTap: onTap,
      ),
    );
  }
}
