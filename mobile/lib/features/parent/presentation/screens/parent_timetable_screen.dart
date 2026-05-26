import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _parentTimetableProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, classId) async {
  final r = await ApiClient.instance
      .get(ApiConstants.parentTimetable, queryParameters: {'class_id': classId});
  return r.data['data'] as Map<String, dynamic>;
});

class ParentTimetableScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;
  const ParentTimetableScreen(
      {super.key, required this.classId, required this.className});

  @override
  ConsumerState<ParentTimetableScreen> createState() => _State();
}

class _State extends ConsumerState<ParentTimetableScreen> {
  late int _year;
  late int _month;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year  = now.year;
    _month = now.month;
  }

  String get _monthStr => '$_year-${_month.toString().padLeft(2, '0')}';

  void _prevMonth() => setState(() {
    if (_month == 1) { _month = 12; _year--; } else _month--;
    _selectedDay = null;
  });

  void _nextMonth() => setState(() {
    if (_month == 12) { _month = 1; _year++; } else _month++;
    _selectedDay = null;
  });

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _fmt12(String? t) {
    if (t == null || t.isEmpty) return '--';
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
    final ttAsync = ref.watch(_parentTimetableProvider(widget.classId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Timetable · ${widget.className}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ttAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _buildBody(data),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final periods     = (data['periods']      as List?) ?? [];
    final schoolStart = data['school_start_time'] as String?;
    final schoolEnd   = data['school_end_time']   as String?;
    final timingRules = (data['timing_rules'] as List?) ?? [];

    // Build map day_of_week → periods
    final Map<int, List<Map>> periodsByDay = {};
    for (final p in periods) {
      final day = (p['day_of_week'] as num).toInt();
      periodsByDay.putIfAbsent(day, () => []).add(p as Map);
    }

    // Find timing rule for a date
    Map<String, dynamic>? ruleFor(DateTime date) {
      for (final r in timingRules) {
        final rule = r as Map<String, dynamic>;
        final from = DateTime.parse(rule['date_from'] as String);
        final to   = DateTime.parse(rule['date_to']   as String);
        if (!date.isBefore(from) && !date.isAfter(to)) return rule;
      }
      return null;
    }

    final today        = DateTime.now();
    final firstDay     = DateTime(_year, _month, 1);
    final startOffset  = firstDay.weekday % 7; // Sun=0, Mon=1…Sat=6
    final daysInMonth  = DateTime(_year, _month + 1, 0).day;
    final isThisMonth  = _year == today.year && _month == today.month;

    return SingleChildScrollView(
        child: Column(children: [
          // ── School hours banner ─────────────────────────────────────────
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _timeCol(Icons.login_rounded, 'Start', _fmt12(schoolStart)),
              Container(width: 1, height: 36, color: Colors.white38),
              _timeCol(Icons.logout_rounded, 'End', _fmt12(schoolEnd)),
              Container(width: 1, height: 36, color: Colors.white38),
              _timeCol(Icons.class_rounded, 'Class', widget.className.replaceFirst('Class ', '')),
            ]),
          ),

          const SizedBox(height: 8),

          // ── Calendar card ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(children: [

              // Month nav
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _prevMonth,
                ),
                Expanded(
                  child: Center(
                    child: Text('${_monthNames[_month]}, $_year',
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _nextMonth,
                ),
              ]),

              const Divider(height: 16),

              // Weekday headers — Sun highlighted
              Row(
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .asMap()
                    .entries
                    .map((e) => Expanded(
                          child: Center(
                            child: Text(e.value,
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: e.key == 0
                                    ? const Color(0xFFE65100)
                                    : AppColors.textSecondary)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),

              // Calendar grid
              Column(children: [
                  LayoutBuilder(builder: (ctx3, constraints) {
                    const spacing = 4.0;
                    final cellSize = (constraints.maxWidth - 6 * spacing) / 7;
                    final cellCount = startOffset + daysInMonth;
                    final rows = (cellCount / 7).ceil();

                    return SizedBox(
                      width: constraints.maxWidth,
                      height: rows * (cellSize + spacing) - spacing,
                      child: Stack(
                        children: List.generate(rows * 7, (i) {
                          final col = i % 7;
                          final row = i ~/ 7;
                          final x = col * (cellSize + spacing);
                          final y = row * (cellSize + spacing);

                          if (i < startOffset || i >= startOffset + daysInMonth) {
                            return Positioned(
                              left: x, top: y, width: cellSize, height: cellSize,
                              child: const SizedBox.shrink(),
                            );
                          }

                          final day    = i - startOffset + 1;
                          final date   = DateTime(_year, _month, day);
                          final isSun  = date.weekday == DateTime.sunday;
                          final isToday = isThisMonth && day == today.day;
                          final rule   = isSun ? null : ruleFor(date);
                          final start  = rule != null
                              ? rule['start_time'] as String?
                              : schoolStart;
                          final end    = rule != null
                              ? rule['end_time'] as String?
                              : schoolEnd;
                          final isSelected = _selectedDay == day;

                          return Positioned(
                            left: x, top: y, width: cellSize, height: cellSize,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedDay = (_selectedDay == day) ? null : day;
                              }),
                              child: _TimetableCell(
                                day: day,
                                isSunday: isSun,
                                isToday: isToday,
                                isSelected: isSelected,
                                schoolStart: isSun ? null : start,
                                schoolEnd:   isSun ? null : end,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),

                  // ── Expanded day detail ────────────────────────────────
                  if (_selectedDay != null) ...[
                    const SizedBox(height: 16),
                    _DayDetail(
                      date: DateTime(_year, _month, _selectedDay!),
                      periods: periodsByDay[
                        DateTime(_year, _month, _selectedDay!).weekday
                      ] ?? [],
                      schoolStart: schoolStart,
                      schoolEnd: schoolEnd,
                      rule: ruleFor(DateTime(_year, _month, _selectedDay!)),
                    ),
                  ],
                ]),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Legend ───────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Wrap(
              spacing: 20, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _LegendItem(color: Color(0xFF1565C0), label: 'Today'),
                _LegendItem(color: Color(0xFFFFF3E0), label: 'Sunday (Closed)', textColor: Color(0xFFE65100)),
                _LegendItem(color: Color(0xFFE8F5E9), label: 'School Day', textColor: Color(0xFF2E7D32)),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ]),
      );
  }

  Widget _timeCol(IconData icon, String label, String val) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ]);
}

// ── Timetable cell ────────────────────────────────────────────────────────────

class _TimetableCell extends StatelessWidget {
  final int day;
  final bool isSunday, isToday, isSelected;
  final String? schoolStart, schoolEnd;

  const _TimetableCell({
    required this.day,
    required this.isSunday,
    required this.isToday,
    required this.isSelected,
    this.schoolStart,
    this.schoolEnd,
  });

  static String _short(String? t) {
    if (t == null) return '';
    final parts = t.split(':');
    if (parts.length < 2) return '';
    final h = int.tryParse(parts[0]) ?? 0;
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12${h < 12 ? 'a' : 'p'}';
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    Border? border;

    if (isToday) {
      bg = const Color(0xFF1565C0);
      textColor = Colors.white;
    } else if (isSunday) {
      bg = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
    } else {
      bg = isSelected
          ? AppColors.primary.withOpacity(0.12)
          : const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
    }

    if (isSelected && !isToday) {
      border = Border.all(color: AppColors.primary, width: 1.5);
    }

    final timeStr = isSunday
        ? 'X'
        : (schoolStart != null ? _short(schoolStart) : '');

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? Colors.white : textColor,
            )),
          if (timeStr.isNotEmpty)
            Text(timeStr,
              style: TextStyle(
                fontSize: 7,
                color: isToday ? Colors.white70 : textColor.withOpacity(0.7),
              )),
        ],
      ),
    );
  }
}

// ── Day detail card ───────────────────────────────────────────────────────────

class _DayDetail extends StatelessWidget {
  final DateTime date;
  final List<Map> periods;
  final String? schoolStart, schoolEnd;
  final Map<String, dynamic>? rule;

  const _DayDetail({
    required this.date,
    required this.periods,
    this.schoolStart,
    this.schoolEnd,
    this.rule,
  });

  static const _dayNames = ['', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months   = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _fmt12(String? t) {
    if (t == null || t.isEmpty) return '--';
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
    final isSunday  = date.weekday == DateTime.sunday;
    final dayName   = _dayNames[date.weekday];
    final dateLabel = '${date.day} ${_months[date.month]}, ${date.year}';
    final start     = rule != null ? rule!['start_time'] as String? : schoolStart;
    final end       = rule != null ? rule!['end_time']   as String? : schoolEnd;
    final label     = rule?['label'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSunday ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSunday
              ? const Color(0xFFFFCC80)
              : AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            isSunday ? Icons.beach_access_rounded : Icons.calendar_today_rounded,
            color: isSunday ? const Color(0xFFE65100) : AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dayName,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: isSunday ? const Color(0xFFE65100) : AppColors.primary)),
            Text(dateLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          if (isSunday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC80),
                borderRadius: BorderRadius.circular(8)),
              child: const Text('HOLIDAY',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: Color(0xFFE65100))),
            ),
        ]),

        if (!isSunday) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          if (label != null && label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(label,
                style: const TextStyle(fontSize: 11,
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),

          Row(children: [
            _timeChip(Icons.login_rounded, 'Start', _fmt12(start), Colors.green),
            const SizedBox(width: 10),
            _timeChip(Icons.logout_rounded, 'End', _fmt12(end), Colors.red),
          ]),

          if (periods.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Periods',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: periods.map((p) {
                final s = (p['start_time'] as String).substring(0, 5);
                final e = (p['end_time']   as String).substring(0, 5);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: Column(mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['subject_name'] as String,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                    Text('$s – $e',
                      style: TextStyle(fontSize: 10,
                          color: AppColors.primary.withOpacity(0.65))),
                  ]),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              periods.isEmpty ? 'No specific periods on this day' : '',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _timeChip(IconData icon, String label, String val, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
            Text(val, style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: color)),
          ]),
        ]),
      );
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;
  const _LegendItem({required this.color, required this.label,
      this.textColor = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 14, height: 14,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.grey.shade200))),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(fontSize: 11, color: textColor)),
  ]);
}
