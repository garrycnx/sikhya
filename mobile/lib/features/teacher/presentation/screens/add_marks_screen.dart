import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

const _defaultSubjects = [
  'Mathematics', 'English', 'Hindi', 'Punjabi',
  'Science', 'Social Science', 'Computer Science',
  'Physical Education', 'Art & Craft', 'General Knowledge',
];

final _allStudentsProvider = FutureProvider<List>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherAllStudents);
  return r.data['data'] as List;
});

class AddMarksScreen extends ConsumerStatefulWidget {
  const AddMarksScreen({super.key});
  @override ConsumerState<AddMarksScreen> createState() => _State();
}

class _State extends ConsumerState<AddMarksScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(_allStudentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Marks', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) {
          // Group students by class
          final Map<String, List<Map>> byClass = {};
          for (final s in students) {
            final key = 'Class ${s['class_name']} - ${s['section']}';
            byClass.putIfAbsent(key, () => []).add(s as Map);
          }

          final query = _search.toLowerCase();
          final filtered = query.isEmpty
              ? students
              : students.where((s) =>
                  (s['full_name'] as String).toLowerCase().contains(query) ||
                  (s['admission_no'] as String).toLowerCase().contains(query)).toList();

          return Column(children: [
            // Search bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search student by name or admission no.',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true, fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                ),
              ),
            ),

            Expanded(child: query.isNotEmpty
              // Flat search results
              ? ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _StudentTile(
                    student: filtered[i] as Map,
                    onTap: () => _openMarksSheet(filtered[i] as Map),
                  ),
                )
              // Grouped by class
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: byClass.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(entry.key,
                          style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                      ),
                      ...entry.value.map((s) => _StudentTile(
                        student: s,
                        onTap: () => _openMarksSheet(s),
                      )),
                      const SizedBox(height: 4),
                    ],
                  )).toList(),
                ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _openMarksSheet(Map student) async {
    // Load existing marks for this student
    List existingMarks = [];
    try {
      final r = await ApiClient.instance.get(
        ApiConstants.teacherStudentSimpleMarks(student['id'] as String));
      existingMarks = r.data['data'] as List;
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MarksEntrySheet(
        student: student,
        existingMarks: existingMarks,
        onSaved: () => ref.invalidate(_allStudentsProvider),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Map student;
  final VoidCallback onTap;
  const _StudentTile({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5)]),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(student['full_name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text('${student['admission_no']}  ·  Class ${student['class_name']} - ${student['section']}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
      ]),
    ),
  );
}

// ─── Marks entry bottom sheet ─────────────────────────────────────────────────

class _MarksEntrySheet extends ConsumerStatefulWidget {
  final Map student;
  final List existingMarks;
  final VoidCallback onSaved;
  const _MarksEntrySheet({
    required this.student, required this.existingMarks, required this.onSaved});
  @override
  ConsumerState<_MarksEntrySheet> createState() => _MarksEntrySheetState();
}

class _MarksEntrySheetState extends ConsumerState<_MarksEntrySheet> {
  late String _examName;
  final _examNameCtrl = TextEditingController(text: 'Unit Test');
  // subject -> {marks, maxMarks, remarks}
  late Map<String, Map<String, dynamic>> _entries;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _examName = 'Unit Test';
    _entries = {
      for (final sub in _defaultSubjects)
        sub: {'marks': '', 'maxMarks': '100', 'remarks': ''}
    };
    // Pre-fill from existing marks (same exam name)
    _prefill();
  }

  void _prefill() {
    for (final m in widget.existingMarks) {
      final sub  = m['subject_name'] as String;
      final exam = m['exam_name']    as String;
      if (_entries.containsKey(sub)) {
        _entries[sub] = {
          'marks':    m['marks_obtained']?.toString() ?? '',
          'maxMarks': m['max_marks']?.toString() ?? '100',
          'remarks':  m['remarks'] ?? '',
          'exam':     exam,
        };
      }
    }
    if (widget.existingMarks.isNotEmpty) {
      final firstExam = widget.existingMarks[0]['exam_name'] as String?;
      if (firstExam != null) {
        _examName = firstExam;
        _examNameCtrl.text = firstExam;
      }
    }
  }

  @override
  void dispose() {
    _examNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_examNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter exam name'); return;
    }
    setState(() { _saving = true; _error = null; });
    final entries = _entries.entries.map((e) {
      final marks = double.tryParse(e.value['marks'] as String);
      final max   = double.tryParse(e.value['maxMarks'] as String) ?? 100;
      final rem   = (e.value['remarks'] as String).trim();
      return {
        'subject_name':   e.key,
        'marks_obtained': marks,
        'max_marks':      max,
        'remarks':        rem.isEmpty ? null : rem,
      };
    }).where((e) => e['marks_obtained'] != null || (e['remarks'] != null)).toList();

    if (entries.isEmpty) {
      setState(() { _saving = false; _error = 'Enter at least one mark'; }); return;
    }
    try {
      await ApiClient.instance.post(
        ApiConstants.teacherStudentSimpleMarks(widget.student['id'] as String),
        data: { 'exam_name': _examNameCtrl.text.trim(), 'entries': entries },
      );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Marks saved'),
          backgroundColor: AppColors.success));
      }
    } on DioException catch (e) {
      setState(() { _saving = false; _error = e.response?.data?['error'] ?? 'Failed'; });
    } catch (_) {
      setState(() { _saving = false; _error = 'Network error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Column(children: [
        // Handle + header
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.person_rounded, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.student['full_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Class ${widget.student['class_name']} - ${widget.student['section']}  ·  ${widget.student['admission_no']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // Exam name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _examNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Exam / Term Name',
                  hintText: 'e.g. Unit Test 1, Mid Term, Final',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                onChanged: (v) => _examName = v,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
            const SizedBox(height: 10),
            // Column headers
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                const Expanded(child: Text('Subject',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary))),
                const SizedBox(width: 6),
                const SizedBox(width: 68, child: Text('Marks',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary))),
                const SizedBox(width: 4),
                const SizedBox(width: 50, child: Text('/ Max',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary))),
                const SizedBox(width: 6),
                const Expanded(child: Text('Remarks',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary))),
              ]),
            ),
            const Divider(height: 1),
          ]),
        ),
        // Subject rows
        Expanded(child: ListView.builder(
          controller: scrollCtrl,
          itemCount: _defaultSubjects.length,
          itemBuilder: (_, i) {
            final sub = _defaultSubjects[i];
            final data = _entries[sub]!;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(sub,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 6),
                  // Marks obtained
                  SizedBox(width: 68, child: TextFormField(
                    initialValue: data['marks'] as String,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    onChanged: (v) => setState(() => _entries[sub]!['marks'] = v),
                  )),
                  const SizedBox(width: 4),
                  const Text('/', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 4),
                  // Max marks
                  SizedBox(width: 50, child: TextFormField(
                    initialValue: data['maxMarks'] as String,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '100',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    onChanged: (v) => setState(() => _entries[sub]!['maxMarks'] = v),
                  )),
                  const SizedBox(width: 6),
                  // Remarks
                  Expanded(child: TextFormField(
                    initialValue: data['remarks'] as String,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Remarks',
                      hintStyle: const TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    onChanged: (v) => setState(() => _entries[sub]!['remarks'] = v),
                  )),
                ]),
              ]),
            );
          },
        )),
      ]),
    );
  }
}
