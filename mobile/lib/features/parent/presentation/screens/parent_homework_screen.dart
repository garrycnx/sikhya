import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _parentHomeworkProvider =
    FutureProvider.autoDispose.family<List, String>((ref, classId) async {
  final r = await ApiClient.instance
      .get(ApiConstants.parentHomework, queryParameters: {'class_id': classId});
  return r.data['data'] as List;
});

class ParentHomeworkScreen extends ConsumerWidget {
  final String classId;
  final String className;
  final bool embedded;
  const ParentHomeworkScreen({
    super.key,
    required this.classId,
    required this.className,
    this.embedded = false,
  });

  static String _todayStr() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hwAsync = ref.watch(_parentHomeworkProvider(classId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Homework · $className',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: !embedded,
      ),
      body: hwAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.assignment_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No homework assigned',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15)),
              ]),
            );
          }

          final todayStr = _todayStr();

          // Group by due_date
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final item in list) {
            final hw = item as Map<String, dynamic>;
            final raw = (hw['due_date'] as String?) ?? '';
            final dateKey = raw.length >= 10 ? raw.substring(0, 10) : raw;
            grouped.putIfAbsent(dateKey, () => []).add(hw);
          }

          // Sort: today first → future ascending → past descending
          final today = DateTime.now();
          final sortedDates = grouped.keys.toList()
            ..sort((a, b) {
              final ad = DateTime.tryParse(a);
              final bd = DateTime.tryParse(b);
              if (ad == null || bd == null) return a.compareTo(b);
              if (a == todayStr) return -1;
              if (b == todayStr) return 1;
              final midnight = DateTime(today.year, today.month, today.day);
              final aPast = ad.isBefore(midnight);
              final bPast = bd.isBefore(midnight);
              if (!aPast && !bPast) return a.compareTo(b);
              if (aPast && bPast) return b.compareTo(a);
              return aPast ? 1 : -1;
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: sortedDates.length,
            itemBuilder: (_, i) => _DateTable(
              dateStr: sortedDates[i],
              items: grouped[sortedDates[i]]!,
              todayStr: todayStr,
            ),
          );
        },
      ),
    );
  }
}

// ── Date-grouped table ────────────────────────────────────────────────────────

class _DateTable extends StatelessWidget {
  final String dateStr;
  final List<Map<String, dynamic>> items;
  final String todayStr;

  const _DateTable({
    required this.dateStr,
    required this.items,
    required this.todayStr,
  });

  bool get _isToday => dateStr == todayStr;

  bool get _isOverdue {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return false;
    final now = DateTime.now();
    return d.isBefore(DateTime(now.year, now.month, now.day)) && !_isToday;
  }

  String get _dateLabel {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dm = DateTime(d.year, d.month, d.day);
    if (_isToday) return 'Today';
    if (dm == tomorrow) return 'Tomorrow';
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  Color get _accentColor {
    if (_isOverdue) return AppColors.danger;
    if (_isToday) return AppColors.primary;
    return AppColors.homework;
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date header ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_today_rounded,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(_dateLabel,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: color)),
                      if (_isToday) ...[
                        const SizedBox(width: 6),
                        _Badge('TODAY', AppColors.primary),
                      ],
                      if (_isOverdue) ...[
                        const SizedBox(width: 6),
                        _Badge('OVERDUE', AppColors.danger),
                      ],
                    ]),
                    Text(
                      '${items.length} assignment${items.length > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: color.withOpacity(0.65)),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          // ── Column headers ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.symmetric(
                  horizontal: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: const [
              SizedBox(
                width: 22,
                child: Text('#',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 86,
                child: Text('Subject',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text('Assignment / Notes',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
            ]),
          ),

          // ── Data rows ─────────────────────────────────────────
          ...items.asMap().entries.map((entry) => _DataRow(
                index: entry.key + 1,
                hw: entry.value,
                isLast: entry.key == items.length - 1,
                accentColor: color,
              )),
        ],
      ),
    );
  }
}

// ── Table row ─────────────────────────────────────────────────────────────────

class _DataRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> hw;
  final bool isLast;
  final Color accentColor;

  const _DataRow({
    required this.index,
    required this.hw,
    required this.isLast,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final subject = hw['subject_name'] as String? ?? '—';
    final title   = hw['title']        as String? ?? '';
    final desc    = hw['description']  as String? ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.grey.shade50.withOpacity(0.5)
            : Colors.white,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(14))
            : null,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Row number
        SizedBox(
          width: 22,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text('$index',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accentColor)),
          ),
        ),
        const SizedBox(width: 10),
        // Subject
        SizedBox(
          width: 86,
          child: Text(subject,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(width: 8),
        // Title + description
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}
