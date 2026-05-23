import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _parentMarksProvider =
    FutureProvider.family<List, String>((ref, studentId) async {
  final r = await ApiClient.instance.get(
    ApiConstants.parentMarks,
    queryParameters: {'student_id': studentId},
  );
  return r.data['data'] as List;
});

class ParentMarksScreen extends ConsumerWidget {
  final String studentId;
  final String studentName;
  final bool embedded;
  const ParentMarksScreen(
      {super.key, required this.studentId, required this.studentName, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marksAsync = ref.watch(_parentMarksProvider(studentId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$studentName — Marks',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: !embedded,
      ),
      body: marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (marks) {
          if (marks.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.grade_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No marks entered yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ]));
          }

          // Group by exam_name
          final Map<String, List<Map<String, dynamic>>> byExam = {};
          for (final m in marks) {
            final exam = m['exam_name'] as String;
            byExam.putIfAbsent(exam, () => []).add(m as Map<String, dynamic>);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: byExam.entries.map((entry) {
              final examMarks = entry.value;
              final obtained = examMarks
                  .where((m) => m['marks_obtained'] != null)
                  .fold<double>(0, (s, m) => s + (m['marks_obtained'] as num).toDouble());
              final maxTotal = examMarks
                  .where((m) => m['marks_obtained'] != null)
                  .fold<double>(0, (s, m) => s + (m['max_marks'] as num).toDouble());
              final pct = maxTotal > 0 ? (obtained / maxTotal * 100) : null;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Exam header with overall percentage
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(children: [
                    Expanded(child: Text(entry.key,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700))),
                    if (pct != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _pctColor(pct).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _pctColor(pct))),
                      ),
                  ]),
                ),

                // Subject rows
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                  child: Column(
                    children: examMarks.asMap().entries.map((e) {
                      final i = e.key;
                      final m = e.value;
                      final ob  = m['marks_obtained'] as num?;
                      final max = (m['max_marks'] as num).toDouble();
                      final subPct = ob != null ? (ob.toDouble() / max * 100) : null;
                      final remarks = m['remarks'] as String?;
                      return Column(children: [
                        if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(children: [
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m['subject_name'] as String,
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (remarks != null && remarks.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(remarks,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontStyle: FontStyle.italic)),
                                  ],
                                ])),
                            const SizedBox(width: 12),
                            // Score
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(
                                ob != null ? '${ob.toStringAsFixed(ob % 1 == 0 ? 0 : 1)} / ${max.toStringAsFixed(max % 1 == 0 ? 0 : 1)}' : 'Absent',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700,
                                    color: ob != null
                                        ? _pctColor(subPct!)
                                        : Colors.grey.shade400)),
                              if (subPct != null)
                                Text('${subPct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _pctColor(subPct),
                                        fontWeight: FontWeight.w500)),
                            ]),
                          ]),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ]);
            }).toList(),
          );
        },
      ),
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 75) return const Color(0xFF43A047);
    if (pct >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }
}
