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
      {super.key,
      required this.studentId,
      required this.studentName,
      this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marksAsync = ref.watch(_parentMarksProvider(studentId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('$studentName — Marks',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: !embedded,
        leading: embedded
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
      ),
      body: marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (marks) {
          if (marks.isEmpty) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
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

          // Compute overall % per exam for sorting (best/recent first)
          final entries = byExam.entries.toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Summary banner ────────────────────────────────────────
              _OverallBanner(byExam: byExam),
              const SizedBox(height: 16),

              // ── Per-exam expandable cards ─────────────────────────────
              ...entries.map((e) => _ExamCard(
                    examName: e.key,
                    subjects: e.value,
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ── Overall summary banner ────────────────────────────────────────────────────

class _OverallBanner extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> byExam;
  const _OverallBanner({required this.byExam});

  @override
  Widget build(BuildContext context) {
    double totalObtained = 0;
    double totalMax = 0;
    int subjectCount = 0;

    for (final subjects in byExam.values) {
      for (final m in subjects) {
        final ob = m['marks_obtained'] as num?;
        final mx = (m['max_marks'] as num?)?.toDouble() ?? 0;
        if (ob != null) {
          totalObtained += ob.toDouble();
          totalMax += mx;
          subjectCount++;
        }
      }
    }

    final pct = totalMax > 0 ? (totalObtained / totalMax * 100) : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E7D32).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Overall Performance',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              pct != null ? '${pct.toStringAsFixed(1)}%' : 'No marks yet',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${byExam.length} exam${byExam.length != 1 ? 's' : ''}  ·  $subjectCount subject${subjectCount != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ]),
        ),
        if (pct != null)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                pct >= 75
                    ? Icons.emoji_events_rounded
                    : pct >= 50
                        ? Icons.thumb_up_rounded
                        : Icons.trending_up_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Expandable exam card ──────────────────────────────────────────────────────

class _ExamCard extends StatefulWidget {
  final String examName;
  final List<Map<String, dynamic>> subjects;
  const _ExamCard({required this.examName, required this.subjects});

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _rot = Tween<double>(begin: 0, end: 0.5).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  Color _pctColor(double pct) {
    if (pct >= 75) return const Color(0xFF43A047);
    if (pct >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final obtained = widget.subjects
        .where((m) => m['marks_obtained'] != null)
        .fold<double>(0, (s, m) => s + (m['marks_obtained'] as num).toDouble());
    final maxTotal = widget.subjects
        .where((m) => m['marks_obtained'] != null)
        .fold<double>(0, (s, m) => s + (m['max_marks'] as num).toDouble());
    final pct = maxTotal > 0 ? (obtained / maxTotal * 100) : null;
    final grade = pct == null
        ? null
        : pct >= 90
            ? 'A+'
            : pct >= 80
                ? 'A'
                : pct >= 70
                    ? 'B+'
                    : pct >= 60
                        ? 'B'
                        : pct >= 50
                            ? 'C'
                            : 'D';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // ── Header (always visible) ───────────────────────────────────
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              // Exam icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pct != null
                      ? _pctColor(pct).withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.article_rounded,
                    color: pct != null ? _pctColor(pct) : Colors.grey.shade400,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(widget.examName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    '${widget.subjects.length} subject${widget.subjects.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ])),
              const SizedBox(width: 8),
              // Overall %
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (pct != null)
                  Text('${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _pctColor(pct))),
                if (grade != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: _pctColor(pct!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(grade,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _pctColor(pct))),
                  ),
              ]),
              const SizedBox(width: 6),
              RotationTransition(
                turns: _rot,
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary, size: 22),
              ),
            ]),
          ),
        ),

        // ── Progress bar ──────────────────────────────────────────────
        if (pct != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: _pctColor(pct).withOpacity(0.12),
                valueColor:
                    AlwaysStoppedAnimation<Color>(_pctColor(pct)),
                minHeight: 5,
              ),
            ),
          ),

        // ── Expandable subject rows ───────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: [
            Divider(height: 1, color: Colors.grey.shade100),
            // Column headers
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade50,
              child: Row(children: const [
                Expanded(
                    child: Text('Subject',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary))),
                SizedBox(width: 8),
                Text('Score',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
                SizedBox(width: 8),
                SizedBox(
                    width: 44,
                    child: Text('%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary))),
              ]),
            ),
            // Subject rows
            ...widget.subjects.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final ob = m['marks_obtained'] as num?;
              final mx = (m['max_marks'] as num).toDouble();
              final subPct = ob != null ? (ob.toDouble() / mx * 100) : null;
              final isLast = i == widget.subjects.length - 1;
              return Column(children: [
                if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(m['subject_name'] as String,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          if ((m['remarks'] as String?)?.isNotEmpty ==
                              true)
                            Text(m['remarks'] as String,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic)),
                        ])),
                    const SizedBox(width: 8),
                    Text(
                      ob != null
                          ? '${ob.toStringAsFixed(ob % 1 == 0 ? 0 : 1)}/${mx.toStringAsFixed(mx % 1 == 0 ? 0 : 1)}'
                          : 'Absent',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ob != null
                              ? _pctColor(subPct!)
                              : Colors.grey.shade400),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        subPct != null
                            ? '${subPct.toStringAsFixed(0)}%'
                            : '—',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            color: subPct != null
                                ? _pctColor(subPct)
                                : Colors.grey.shade400),
                      ),
                    ),
                  ]),
                ),
                if (isLast)
                  const SizedBox(height: 6),
              ]);
            }),
          ]),
        ),
      ]),
    );
  }
}
