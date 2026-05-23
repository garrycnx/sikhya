import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _parentTimetableProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, classId) async {
  final r = await ApiClient.instance
      .get(ApiConstants.parentTimetable, queryParameters: {'class_id': classId});
  return r.data['data'] as Map<String, dynamic>;
});

class ParentTimetableScreen extends ConsumerWidget {
  final String classId;
  final String className;
  const ParentTimetableScreen(
      {super.key, required this.classId, required this.className});

  static const _dayNames = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _shortDay = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttAsync = ref.watch(_parentTimetableProvider(classId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Timetable · $className',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ttAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final periods      = (data['periods']      as List?) ?? [];
          final schoolStart  = data['school_start_time'] as String?;
          final schoolEnd    = data['school_end_time']   as String?;
          final timingRules  = (data['timing_rules'] as List?) ?? [];

          // Build map of day_of_week -> list of periods
          final Map<int, List<Map>> periodsByDay = {};
          for (final p in periods) {
            final day = (p['day_of_week'] as num).toInt();
            periodsByDay.putIfAbsent(day, () => []).add(p as Map);
          }

          // Find applicable timing rule for a date (first match wins)
          Map<String, dynamic>? _ruleFor(DateTime date) {
            for (final r in timingRules) {
              final rule = r as Map<String, dynamic>;
              final from = DateTime.parse(rule['date_from'] as String);
              final to   = DateTime.parse(rule['date_to']   as String);
              if (!date.isBefore(from) && !date.isAfter(to)) return rule;
            }
            return null;
          }

          // Generate upcoming dates for next 3 months (90 days), include ALL (even Sundays)
          final now = DateTime.now();
          final upcoming = <DateTime>[];
          for (int i = 0; i <= 90; i++) {
            upcoming.add(now.add(Duration(days: i)));
          }

          // Group by month
          final Map<String, List<DateTime>> byMonth = {};
          for (final d in upcoming) {
            final key = '${_months[d.month]} ${d.year}';
            byMonth.putIfAbsent(key, () => []).add(d);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // School hours header
              if (schoolStart != null || schoolEnd != null)
                _SchoolHoursCard(start: schoolStart, end: schoolEnd),
              const SizedBox(height: 16),

              // Month-grouped date list
              ...byMonth.entries.map((entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 4),
                    child: Text(entry.key,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                  ...entry.value.map((date) {
                    final isToday = date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day;
                    final isSunday = date.weekday == DateTime.sunday;
                    final rule     = isSunday ? null : _ruleFor(date);
                    final dayPeriods = isSunday ? <Map>[] : (periodsByDay[date.weekday] ?? []);
                    final effectiveStart = rule != null
                        ? rule['start_time'] as String?
                        : schoolStart;
                    final effectiveEnd = rule != null
                        ? rule['end_time'] as String?
                        : schoolEnd;
                    return _DayCard(
                      date: date,
                      isToday: isToday,
                      isSunday: isSunday,
                      dayName: _dayNames[date.weekday],
                      shortDay: _shortDay[date.weekday],
                      periods: dayPeriods,
                      schoolStart: effectiveStart,
                      schoolEnd: effectiveEnd,
                      ruleLabel: rule?['label'] as String?,
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              )),
            ],
          );
        },
      ),
    );
  }
}

class _SchoolHoursCard extends StatelessWidget {
  final String? start;
  final String? end;
  const _SchoolHoursCard({this.start, this.end});

  String _fmt12(String? t) {
    if (t == null) return '--';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1].padLeft(2, '0');
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _timeCol(Icons.login_rounded, 'School Start', _fmt12(start)),
        Container(width: 1, height: 40, color: Colors.white38),
        _timeCol(Icons.logout_rounded, 'School End', _fmt12(end)),
      ]),
    );
  }

  Widget _timeCol(IconData icon, String label, String time) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(time,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ]);
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSunday;
  final String dayName;
  final String shortDay;
  final List<Map> periods;
  final String? schoolStart;
  final String? schoolEnd;
  final String? ruleLabel;

  const _DayCard({
    required this.date,
    required this.isToday,
    required this.isSunday,
    required this.dayName,
    required this.shortDay,
    required this.periods,
    this.schoolStart,
    this.schoolEnd,
    this.ruleLabel,
  });

  String _fmt12(String t) {
    final parts = t.split(':');
    if (parts.length < 2) return t;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1].padLeft(2, '0');
    final p = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = isToday ? AppColors.primary
        : isSunday ? Colors.grey.shade400
        : Colors.grey.shade600;
    final badgeBg = isToday ? AppColors.primary
        : isSunday ? Colors.grey.shade200
        : Colors.grey.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSunday ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: AppColors.primary, width: 1.5)
            : Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5)
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date badge
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(shortDay,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isToday ? Colors.white70
                        : isSunday ? Colors.grey.shade400
                        : Colors.grey)),
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isToday ? Colors.white
                        : isSunday ? Colors.grey.shade400
                        : Colors.black87)),
          ]),
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isSunday
                // Sunday: always holiday
                ? Row(children: [
                    Icon(Icons.beach_access_rounded,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text('Holiday', style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Timing rule label
                    if (ruleLabel != null && ruleLabel!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(ruleLabel!,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    // School hours — always shown
                    Row(children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        (schoolStart != null && schoolEnd != null)
                            ? '${_fmt12(schoolStart!)} – ${_fmt12(schoolEnd!)}'
                            : 'School Day',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ]),
                    // Subject periods — shown below when present
                    if (periods.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: periods.map((p) {
                          final start = (p['start_time'] as String).substring(0, 5);
                          final end   = (p['end_time']   as String).substring(0, 5);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8)),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['subject_name'] as String,
                                      style: TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w700, color: accent)),
                                  Text('$start – $end',
                                      style: TextStyle(fontSize: 10,
                                          color: accent.withOpacity(0.7))),
                                ]),
                          );
                        }).toList(),
                      ),
                    ],
                  ]),
          ),
        ),
      ]),
    );
  }
}
