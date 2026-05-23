import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'add_homework_screen.dart';

final teacherHomeworkListProvider = FutureProvider<List>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherHomework);
  return r.data['data'] as List;
});

class TeacherHomeworkListScreen extends ConsumerWidget {
  const TeacherHomeworkListScreen({super.key});

  static String _todayStr() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherHomeworkListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Homework', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Homework',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddHomeworkScreen()))
            .then((_) => ref.invalidate(teacherHomeworkListProvider)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No homework assigned yet',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                const Text('Tap "Add Homework" to create one.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            );
          }

          // Group by due_date (YYYY-MM-DD)
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final item in list) {
            final hw = item as Map<String, dynamic>;
            final raw = (hw['due_date'] as String?) ?? '';
            final dateKey = raw.length >= 10 ? raw.substring(0, 10) : raw;
            grouped.putIfAbsent(dateKey, () => []).add(hw);
          }

          final today = DateTime.now();
          final todayStr = _todayStr();

          // Sort: today first → future ascending → past descending
          final sortedDates = grouped.keys.toList()
            ..sort((a, b) {
              final ad = DateTime.tryParse(a);
              final bd = DateTime.tryParse(b);
              if (ad == null || bd == null) return a.compareTo(b);
              final aIsToday = a == todayStr;
              final bIsToday = b == todayStr;
              if (aIsToday) return -1;
              if (bIsToday) return 1;
              final todayMidnight = DateTime(today.year, today.month, today.day);
              final aIsPast = ad.isBefore(todayMidnight);
              final bIsPast = bd.isBefore(todayMidnight);
              if (!aIsPast && !bIsPast) return a.compareTo(b); // future: ascending
              if (aIsPast && bIsPast) return b.compareTo(a);   // past: most recent first
              return aIsPast ? 1 : -1; // future before past
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: sortedDates.length,
            itemBuilder: (_, i) {
              final dateStr = sortedDates[i];
              return _DateTable(
                dateStr: dateStr,
                items: grouped[dateStr]!,
                todayStr: todayStr,
                onAdd: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddHomeworkScreen()))
                    .then((_) => ref.invalidate(teacherHomeworkListProvider)),
                onDelete: () => ref.invalidate(teacherHomeworkListProvider),
              );
            },
          );
        },
      ),
    );
  }
}

class _DateTable extends StatelessWidget {
  final String dateStr;
  final List<Map<String, dynamic>> items;
  final String todayStr;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  const _DateTable({
    required this.dateStr,
    required this.items,
    required this.todayStr,
    required this.onAdd,
    required this.onDelete,
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
                      _badge('TODAY', AppColors.primary),
                    ],
                    if (_isOverdue) ...[
                      const SizedBox(width: 6),
                      _badge('OVERDUE', AppColors.danger),
                    ],
                  ]),
                  Text(
                    '${items.length} assignment${items.length > 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 11, color: color.withOpacity(0.65)),
                  ),
                ]),
              ),
              // Add more for this date
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text('Add',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Column headers ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.symmetric(
                  horizontal: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              const SizedBox(
                width: 22,
                child: Text('#',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 10),
              const SizedBox(
                width: 86,
                child: Text('Subject',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Assignment / Notes',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 60,
                child: Text('Class',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 32), // space for delete icon
            ]),
          ),

          // ── Data rows ────────────────────────────────────────
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return _DataRow(
              index: entry.key + 1,
              hw: entry.value,
              isLast: isLast,
              accentColor: color,
              onDelete: onDelete,
            );
          }),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      );
}

class _DataRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> hw;
  final bool isLast;
  final Color accentColor;
  final VoidCallback onDelete;

  const _DataRow({
    required this.index,
    required this.hw,
    required this.isLast,
    required this.accentColor,
    required this.onDelete,
  });

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Homework'),
        content: Text(
            'Delete "${hw['title']}" for ${hw['subject_name'] ?? 'this subject'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ApiClient.instance.delete(
                      ApiConstants.teacherDeleteHomework(hw['id'] as String));
                  onDelete();
                } on DioException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(e.response?.data?['error'] ?? 'Failed to delete'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final className = hw['class_name'] != null
        ? 'Cl.${hw['class_name']}${hw['section'] != null ? '-${hw['section']}' : ''}'
        : '—';
    final subject = hw['subject_name'] as String? ?? '—';
    final title = hw['title'] as String? ?? '';
    final desc = hw['description'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.grey.shade50.withOpacity(0.5) : Colors.white,
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        const SizedBox(width: 8),
        // Class
        SizedBox(
          width: 60,
          child: Text(className,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
        // Delete button
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: Colors.red.shade300,
          tooltip: 'Delete',
          splashRadius: 18,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          onPressed: () => _confirmDelete(context),
        ),
      ]),
    );
  }
}
