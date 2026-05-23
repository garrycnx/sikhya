import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;
  const AttendanceScreen({super.key, required this.classId, required this.className});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _date = DateTime.now();
  List<dynamic> _students = [];
  // status per student_id: 'present' | 'absent' | 'late'
  final Map<String, String> _statuses = {};
  bool _loading = true;
  bool _saving  = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadStudents(); }

  Future<void> _loadStudents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final studentsR = await ApiClient.instance
          .get(ApiConstants.classStudents(widget.classId));
      final students = studentsR.data['data'] as List<dynamic>;

      Map<String, String> existing = {};
      try {
        final attR = await ApiClient.instance.get(
          ApiConstants.classAttendance(widget.classId),
          queryParameters: {'date': DateFormat('yyyy-MM-dd').format(_date)},
        );
        for (final a in (attR.data['data'] as List? ?? [])) {
          existing[a['student_id'] as String] = a['status'] as String;
        }
      } catch (_) {}

      setState(() {
        _students = students;
        _statuses.clear();
        for (final s in students) {
          _statuses[s['id'] as String] = existing[s['id'] as String] ?? 'present';
        }
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _save() async {
    if (_students.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiClient.instance.post(ApiConstants.teacherAttendance, data: {
        'class_id': widget.classId,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'entries': _statuses.entries
            .map((e) => {'student_id': e.key, 'status': e.value})
            .toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance saved')));
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['error'] ?? 'Failed to save'),
        backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _markAll(String status) =>
      setState(() { for (final k in _statuses.keys) _statuses[k] = status; });

  @override
  Widget build(BuildContext context) {
    final present = _statuses.values.where((v) => v == 'present').length;
    final absent  = _statuses.values.where((v) => v == 'absent').length;
    final late    = _statuses.values.where((v) => v == 'late').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.className,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_loading && _students.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('SAVE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: 15)),
            ),
        ],
      ),
      body: Column(children: [
        // Date + counters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null && d != _date) {
                  setState(() => _date = d);
                  _loadStudents();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(DateFormat('dd MMM yyyy').format(_date),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
                ]),
              ),
            ),
            const Spacer(),
            _Badge('P $present', Colors.green),
            const SizedBox(width: 6),
            _Badge('A $absent', Colors.red),
            if (late > 0) ...[
              const SizedBox(width: 6),
              _Badge('L $late', Colors.orange),
            ],
          ]),
        ),

        // Mark-all row
        if (!_loading && _students.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              const Text('Mark all:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              _MarkAllBtn('All Present', Colors.green,  () => _markAll('present')),
              const SizedBox(width: 6),
              _MarkAllBtn('All Absent',  Colors.red,    () => _markAll('absent')),
            ]),
          ),

        const Divider(height: 1),

        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
        if (_error != null) Expanded(child: Center(child: Text('Error: $_error'))),
        if (!_loading && _error == null && _students.isEmpty)
          const Expanded(child: Center(child: Text('No students in this class'))),
        if (!_loading && _error == null && _students.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _students.length,
              itemBuilder: (_, i) {
                final s   = _students[i] as Map<String, dynamic>;
                final id  = s['id'] as String;
                return _AttendanceTile(
                  student:   s,
                  status:    _statuses[id] ?? 'present',
                  onChanged: (v) => setState(() => _statuses[id] = v),
                );
              },
            ),
          ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
    child: Text(label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
  );
}

class _MarkAllBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MarkAllBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

class _AttendanceTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final String status;
  final ValueChanged<String> onChanged;
  const _AttendanceTile(
      {required this.student, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final name   = student['full_name'] as String;
    final roll   = student['roll_number'] ?? '-';
    final admNo  = student['admission_no'] as String;
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Color borderColor = switch (status) {
      'present' => Colors.green,
      'absent'  => Colors.red,
      'late'    => Colors.orange,
      _         => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03), blurRadius: 4)],
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: borderColor.withOpacity(0.15),
          child: Text(initials,
              style: TextStyle(color: borderColor, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        // Name + meta
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('Roll $roll · $admNo',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        // P / A / L buttons
        _StatusBtn('P', status == 'present', Colors.green,
            () => onChanged('present')),
        const SizedBox(width: 6),
        _StatusBtn('A', status == 'absent', Colors.red,
            () => onChanged('absent')),
        const SizedBox(width: 6),
        _StatusBtn('L', status == 'late', Colors.orange,
            () => onChanged('late')),
      ]),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _StatusBtn(this.label, this.active, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: active ? color : Colors.transparent,
        border: Border.all(color: active ? color : color.withOpacity(0.4), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : color.withOpacity(0.7),
          fontWeight: FontWeight.w800, fontSize: 13,
        )),
      ),
    ),
  );
}
