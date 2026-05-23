import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _timingRulesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherTimingRules);
  return r.data['data'] as Map<String, dynamic>;
});

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});
  @override ConsumerState<TimetableScreen> createState() => _State();
}

class _State extends ConsumerState<TimetableScreen> {
  // ── Default school hours edit ──────────────────────────────────────────
  bool _savingDefault    = false;
  bool _defaultsInited   = false;
  TimeOfDay _defStart = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _defEnd   = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay? _loadedStart;
  TimeOfDay? _loadedEnd;

  TimeOfDay? _parseTime(String? t) {
    if (t == null || t.isEmpty) return null;
    final p = t.split(':');
    return p.length < 2 ? null : TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  String _disp(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _saveDefault() async {
    setState(() => _savingDefault = true);
    try {
      await ApiClient.instance.put(ApiConstants.schoolTiming, data: {
        'school_start_time': _fmt(_defStart),
        'school_end_time':   _fmt(_defEnd),
      });
      setState(() {
        _loadedStart = _defStart;
        _loadedEnd   = _defEnd;
      });
      ref.invalidate(_timingRulesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default hours saved')));
    } on DioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['error'] ?? 'Failed'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _savingDefault = false);
    }
  }

  // ── Add/Edit rule sheet ────────────────────────────────────────────────
  Future<void> _showRuleSheet({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    DateTime? dateFrom = isEdit ? DateTime.parse(existing['date_from'] as String) : null;
    DateTime? dateTo   = isEdit ? DateTime.parse(existing['date_to']   as String) : null;
    TimeOfDay startTime = isEdit
        ? (_parseTime(existing['start_time'] as String?) ?? const TimeOfDay(hour: 8, minute: 0))
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = isEdit
        ? (_parseTime(existing['end_time'] as String?) ?? const TimeOfDay(hour: 14, minute: 0))
        : const TimeOfDay(hour: 14, minute: 0);
    final labelCtrl = TextEditingController(text: isEdit ? (existing['label'] as String? ?? '') : '');
    bool saving = false;
    String? err;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        Future<void> save() async {
          if (dateFrom == null || dateTo == null) {
            setModal(() => err = 'Select a date range'); return;
          }
          setModal(() { saving = true; err = null; });
          try {
            final body = {
              'date_from':  DateFormat('yyyy-MM-dd').format(dateFrom!),
              'date_to':    DateFormat('yyyy-MM-dd').format(dateTo!),
              'start_time': _fmt(startTime),
              'end_time':   _fmt(endTime),
              if (labelCtrl.text.trim().isNotEmpty) 'label': labelCtrl.text.trim(),
            };
            if (isEdit) {
              await ApiClient.instance.put(
                ApiConstants.teacherTimingRuleById(existing['id'] as String), data: body);
            } else {
              await ApiClient.instance.post(ApiConstants.teacherTimingRules, data: body);
            }
            ref.invalidate(_timingRulesProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          } on DioException catch (e) {
            setModal(() { saving = false; err = e.response?.data?['error'] ?? 'Failed'; });
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEdit ? 'Edit Timing Rule' : 'Add Timing Rule',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Sunday is always a holiday and is never affected by rules.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            // Label
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. Exam Week, Winter Schedule',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: Colors.grey.shade50),
            ),
            const SizedBox(height: 14),

            // Date range — single tap opens range picker
            _DateRangeTile(
              dateFrom: dateFrom,
              dateTo: dateTo,
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: ctx,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: (dateFrom != null && dateTo != null)
                    ? DateTimeRange(start: dateFrom!, end: dateTo!)
                    : null,
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setModal(() {
                  dateFrom = picked.start;
                  dateTo   = picked.end;
                });
              },
            ),
            const SizedBox(height: 14),

            // Time row
            Row(children: [
              Expanded(child: _TimePickerTile(
                label: 'School Starts',
                time: startTime,
                color: Colors.green,
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: startTime);
                  if (t != null) setModal(() => startTime = t);
                },
              )),
              const SizedBox(width: 10),
              Expanded(child: _TimePickerTile(
                label: 'School Ends',
                time: endTime,
                color: Colors.red,
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: endTime);
                  if (t != null) setModal(() => endTime = t);
                },
              )),
            ]),

            if (err != null) ...[
              const SizedBox(height: 10),
              Text(err!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Update Rule' : 'Add Rule',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  Future<void> _deleteRule(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Remove this timing rule?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.delete(ApiConstants.teacherTimingRuleById(id));
      ref.invalidate(_timingRulesProvider);
    } on DioException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.response?.data?['error'] ?? 'Failed'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_timingRulesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('School Hours', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRuleSheet(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Rule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          // Sync loaded defaults once
          if (!_defaultsInited) {
            final ds = _parseTime(data['default_start'] as String?);
            final de = _parseTime(data['default_end']   as String?);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _defStart       = ds ?? const TimeOfDay(hour: 8,  minute: 0);
                _defEnd         = de ?? const TimeOfDay(hour: 14, minute: 0);
                _loadedStart    = _defStart;
                _loadedEnd      = _defEnd;
                _defaultsInited = true;
              });
            });
          }

          final rules = (data['rules'] as List?) ?? [];
          final isDirty = _loadedStart != null &&
              (_defStart != _loadedStart || _defEnd != _loadedEnd);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ── Default hours section ──────────────────────────────
              const Text('Default School Hours',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Tap the times below to change. Applies every day unless a rule overrides it.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _TimePickerTile(
                      label: 'School Starts', time: _defStart, color: Colors.green,
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _defStart);
                        if (t != null) setState(() => _defStart = t);
                      },
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _TimePickerTile(
                      label: 'School Ends', time: _defEnd, color: Colors.red,
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: _defEnd);
                        if (t != null) setState(() => _defEnd = t);
                      },
                    )),
                  ]),
                  if (isDirty) ...[
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: _savingDefault ? null : () => setState(() {
                          _defStart = _loadedStart!;
                          _defEnd   = _loadedEnd!;
                        }),
                        child: const Text('Undo')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _savingDefault ? null : _saveDefault,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        child: _savingDefault
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                      ),
                    ]),
                  ],
                ]),
              ),

              const SizedBox(height: 24),

              // ── Timing rules section ───────────────────────────────
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Date-Range Rules',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Override default hours for specific date ranges.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 10),

              if (rules.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                  child: const Center(child: Text(
                    'No rules yet. Tap "+ Add Rule" to set different hours for a date range.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                )
              else
                ...rules.map((r) {
                  final rule = r as Map<String, dynamic>;
                  final from  = DateTime.parse(rule['date_from'] as String);
                  final to    = DateTime.parse(rule['date_to']   as String);
                  final start = _parseTime(rule['start_time'] as String?);
                  final end   = _parseTime(rule['end_time']   as String?);
                  final label = rule['label'] as String?;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.date_range_rounded,
                          color: AppColors.primary, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (label != null && label.isNotEmpty)
                          Text(label,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}',
                          style: TextStyle(
                            fontSize: label != null && label.isNotEmpty ? 12 : 14,
                            color: label != null && label.isNotEmpty
                                ? AppColors.textSecondary : Colors.black87,
                            fontWeight: label != null && label.isNotEmpty
                                ? FontWeight.normal : FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.login_rounded, size: 13, color: Colors.green),
                          const SizedBox(width: 3),
                          Text(start != null ? _disp(start) : '--',
                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          const Icon(Icons.logout_rounded, size: 13, color: Colors.red),
                          const SizedBox(width: 3),
                          Text(end != null ? _disp(end) : '--',
                            style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                        ]),
                      ])),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit')   _showRuleSheet(existing: rule);
                          if (v == 'delete') _deleteRule(rule['id'] as String);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit',   child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ]),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}


class _DateRangeTile extends StatelessWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final VoidCallback onTap;
  const _DateRangeTile({required this.dateFrom, required this.dateTo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasRange = dateFrom != null && dateTo != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: hasRange ? AppColors.primary.withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasRange ? AppColors.primary : Colors.grey.shade300,
            width: hasRange ? 1.5 : 1)),
        child: Row(children: [
          Icon(Icons.date_range_rounded,
            color: hasRange ? AppColors.primary : Colors.grey.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Date Range', style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            Text(
              hasRange
                ? '${DateFormat('d MMM yyyy').format(dateFrom!)}  →  ${DateFormat('d MMM yyyy').format(dateTo!)}'
                : 'Tap to select start & end date',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: hasRange ? AppColors.primary : Colors.grey)),
          ])),
          Icon(Icons.chevron_right,
            color: hasRange ? AppColors.primary : Colors.grey.shade400, size: 18),
        ]),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;
  const _TimePickerTile({required this.label, required this.time, required this.color, required this.onTap});

  String _disp(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        const SizedBox(height: 4),
        Text(_disp(time),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}
