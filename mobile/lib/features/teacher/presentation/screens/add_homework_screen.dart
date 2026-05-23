import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

const _subjectList = [
  'Mathematics',
  'English',
  'Punjabi',
  'Hindi',
  'Social Science',
  'Science',
  'Computer Science',
  'Physical Education',
  'Art & Craft',
  'General Knowledge',
];

final _classesProvider = FutureProvider<List>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherAllClasses);
  return r.data['data'] as List;
});

class AddHomeworkScreen extends ConsumerStatefulWidget {
  const AddHomeworkScreen({super.key});
  @override ConsumerState<AddHomeworkScreen> createState() => _State();
}

class _State extends ConsumerState<AddHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String? _classId, _subjectName;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;
  String? _error;

  @override void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null)     { setState(() => _error = 'Select a class');   return; }
    if (_subjectName == null) { setState(() => _error = 'Select a subject'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final desc = _descCtrl.text.trim();
      await ApiClient.instance.post(ApiConstants.teacherHomework, data: {
        'class_id':     _classId,
        'subject_name': _subjectName,
        'title':        _titleCtrl.text.trim(),
        if (desc.isNotEmpty) 'description': desc,
        'due_date':     '${_dueDate.year}-${_dueDate.month.toString().padLeft(2,'0')}-${_dueDate.day.toString().padLeft(2,'0')}',
      });
      if (mounted) { Navigator.pop(context); }
    } on DioException catch (e) {
      setState(() { _saving = false; _error = e.response?.data?['error'] ?? 'Failed'; });
    } catch (_) {
      setState(() { _saving = false; _error = 'Network error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(_classesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add Homework', style: TextStyle(fontWeight: FontWeight.w700))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class dropdown
          const Text('Class', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          classes.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (list) => DropdownButtonFormField<String>(
              value: _classId,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
              dropdownColor: Colors.white,
              iconEnabledColor: AppColors.textSecondary,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.white),
              hint: const Text('Select class'),
              items: list.map((c) => DropdownMenuItem(
                value: c['id'] as String,
                child: Text('Class ${c['name']} - ${c['section']}'),
              )).toList(),
              onChanged: (v) => setState(() => _classId = v),
            ),
          ),
          const SizedBox(height: 16),
          // Subject dropdown (static list)
          const Text('Subject', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _subjectName,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
            dropdownColor: Colors.white,
            iconEnabledColor: AppColors.textSecondary,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white),
            hint: const Text('Select subject'),
            items: _subjectList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _subjectName = v),
          ),
          const SizedBox(height: 16),
          // Title
          const Text('Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
            decoration: InputDecoration(hintText: 'e.g. Chapter 5 Exercise 3',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          // Description
          const Text('Description (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descCtrl, maxLines: 3,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
            decoration: InputDecoration(hintText: 'Additional instructions...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white),
          ),
          const SizedBox(height: 16),
          // Due date
          const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context,
                initialDate: _dueDate, firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _dueDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A))),
              ]),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Assign Homework', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ))),
    );
  }
}
