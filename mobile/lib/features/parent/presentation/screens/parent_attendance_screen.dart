import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

// key format: "studentId|YYYY-MM"
final _attendanceProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final parts = key.split('|');
  final r = await ApiClient.instance.get(
    ApiConstants.parentAttendance,
    queryParameters: {'student_id': parts[0], 'month': parts[1]},
  );
  return r.data['data'] as Map<String, dynamic>;
});

class ParentAttendanceScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final bool embedded;
  const ParentAttendanceScreen(
      {super.key, required this.studentId, required this.studentName, this.embedded = false});

  @override
  ConsumerState<ParentAttendanceScreen> createState() => _State();
}

class _State extends ConsumerState<ParentAttendanceScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year  = now.year;
    _month = now.month;
  }

  String get _monthStr => '$_year-${_month.toString().padLeft(2, '0')}';
  String get _providerKey => '${widget.studentId}|$_monthStr';

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _year == now.year && _month == now.month;
  }

  void _prevMonth() => setState(() {
    if (_month == 1) { _month = 12; _year--; } else _month--;
  });

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      if (_month == 12) { _month = 1; _year++; } else _month++;
    });
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_attendanceProvider(_providerKey));
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.studentName),
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (d) => _buildBody(d),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> d) {
    final summary = d['summary'] as Map<String, dynamic>;
    final days    = (d['days'] as List).cast<Map<String, dynamic>>();
    final pct     = summary['percentage']       as int;
    final present = summary['present']           as int;
    final absent  = summary['absent']            as int;
    final total   = summary['total_school_days'] as int;

    // status map: day number → status
    final statusMap = <int, String>{};
    for (final day in days) {
      final dayNum = int.parse((day['date'] as String).split('-')[2]);
      statusMap[dayNum] = day['status'] as String;
    }

    final firstDay    = DateTime(_year, _month, 1);
    final startOffset = firstDay.weekday % 7; // Sun=0, Mon=1…
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final today       = DateTime.now();
    final isThisMonth = _year == today.year && _month == today.month;

    return SingleChildScrollView(
      child: Column(children: [

        // ── Stats row (reference style) ─────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: IntrinsicHeight(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _StatCol(
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF26C6DA),
                value: '$pct%',
                label: 'Attendance',
              ),
              const VerticalDivider(width: 1, color: Color(0xFFEEEEEE)),
              _StatCol(
                icon: Icons.event_available_rounded,
                color: const Color(0xFF66BB6A),
                value: '$present',
                label: 'Present',
              ),
              const VerticalDivider(width: 1, color: Color(0xFFEEEEEE)),
              _StatCol(
                icon: Icons.cancel_rounded,
                color: const Color(0xFFEF5350),
                value: '$absent',
                label: 'Absent',
              ),
              const VerticalDivider(width: 1, color: Color(0xFFEEEEEE)),
              _StatCol(
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFF42A5F5),
                value: '$total',
                label: 'School Days',
              ),
            ]),
          ),
        ),

        const SizedBox(height: 12),

        // ── Calendar card ────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(children: [

            // Month nav
            Row(children: [
              Text('Academic Calendar',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _prevMonth,
              ),
              Text('${_monthNames[_month]}, $_year',
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
              IconButton(
                icon: Icon(Icons.chevron_right, size: 20,
                  color: _isCurrentMonth ? Colors.grey.shade300 : null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _isCurrentMonth ? null : _nextMonth,
              ),
            ]),

            const Divider(height: 16),

            // Weekday headers
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((h) => Expanded(
                        child: Center(
                          child: Text(h,
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),

            // Calendar grid — constrained to fixed cell size
            LayoutBuilder(builder: (ctx, constraints) {
              const spacing = 4.0;
              final totalSpacing = 6 * spacing;
              final cellSize = (constraints.maxWidth - totalSpacing) / 7;

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
                        left: x, top: y,
                        width: cellSize, height: cellSize,
                        child: const SizedBox.shrink(),
                      );
                    }

                    final day = i - startOffset + 1;
                    final status = statusMap[day] ?? 'not_marked';
                    final isToday = isThisMonth && day == today.day;

                    return Positioned(
                      left: x, top: y,
                      width: cellSize, height: cellSize,
                      child: _CalCell(
                        day: day, status: status, isToday: isToday),
                    );
                  }),
                ),
              );
            }),

          ]),
        ),

        const SizedBox(height: 12),

        // ── Legend ────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Wrap(
            spacing: 20, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _LegendItem(color: Color(0xFF66BB6A), label: 'Present'),
              _LegendItem(color: Color(0xFFEF5350), label: 'Absent'),
              _LegendItem(color: Color(0xFFFFA726), label: 'Late'),
              _LegendItem(color: Color(0xFF42A5F5), label: 'Today'),
              _LegendItem(color: Color(0xFFBDBDBD), label: 'Holiday / Weekend'),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Stat column (reference style) ─────────────────────────────────────────────

class _StatCol extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  const _StatCol({required this.icon, required this.color,
      required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(height: 6),
      Text(value,
        style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
      Text(label,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }
}

// ── Calendar cell ─────────────────────────────────────────────────────────────

class _CalCell extends StatelessWidget {
  final int day;
  final String status;
  final bool isToday;
  const _CalCell({required this.day, required this.status, required this.isToday});

  Color get _bgColor {
    if (isToday) return const Color(0xFF1565C0);
    switch (status) {
      case 'present':  return const Color(0xFFE8F5E9);
      case 'absent':   return const Color(0xFFFFEBEE);
      case 'late':     return const Color(0xFFFFF3E0);
      case 'half_day': return const Color(0xFFE3F2FD);
      case 'holiday':  return const Color(0xFFF5F5F5);
      default:         return Colors.transparent;
    }
  }

  Color get _textColor {
    if (isToday) return Colors.white;
    switch (status) {
      case 'present':  return const Color(0xFF2E7D32);
      case 'absent':   return const Color(0xFFC62828);
      case 'late':     return const Color(0xFFE65100);
      case 'half_day': return const Color(0xFF1565C0);
      case 'holiday':  return const Color(0xFF9E9E9E);
      default:         return const Color(0xFF424242);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBg = _bgColor != Colors.transparent;
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
        border: !hasBg && !isToday
            ? Border.all(color: const Color(0xFFF0F0F0))
            : null,
      ),
      child: Center(
        child: Text('$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: _textColor,
          )),
      ),
    );
  }
}

// ── Legend ─────────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label,
      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  ]);
}
