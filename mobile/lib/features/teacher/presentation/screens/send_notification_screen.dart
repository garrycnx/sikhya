import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _classesForNotifProvider = FutureProvider<List>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherAllClasses);
  return r.data['data'] as List;
});

const _notifTypes = [
  {'value': 'general',   'label': 'General',    'icon': Icons.campaign_rounded},
  {'value': 'exam',      'label': 'Exam',        'icon': Icons.grade_rounded},
  {'value': 'holiday',   'label': 'Holiday',     'icon': Icons.beach_access_rounded},
  {'value': 'fee',       'label': 'Fee',         'icon': Icons.payment_rounded},
  {'value': 'emergency', 'label': 'Emergency',   'icon': Icons.warning_amber_rounded},
];

class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key});
  @override ConsumerState<SendNotificationScreen> createState() => _State();
}

class _State extends ConsumerState<SendNotificationScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();
  String     _type        = 'general';
  String     _target      = 'parents';
  String?    _targetClassId;
  DateTime?  _showFrom;
  DateTime?  _showUntil;
  bool       _saving      = false;
  String?    _error;
  bool       _sent        = false;

  @override
  void dispose() { _titleCtrl.dispose(); _messageCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ApiClient.instance.post(ApiConstants.teacherAnnouncements, data: {
        'title':           _titleCtrl.text.trim(),
        'body':            _messageCtrl.text.trim(),
        'type':            _type,
        'target':          _targetClassId != null ? 'class' : _target,
        if (_targetClassId != null) 'target_class_id': _targetClassId,
        if (_showFrom  != null) 'show_from':  DateFormat('yyyy-MM-dd').format(_showFrom!),
        if (_showUntil != null) 'show_until': DateFormat('yyyy-MM-dd').format(_showUntil!),
      });
      setState(() { _saving = false; _sent = true; });
    } on DioException catch (e) {
      setState(() { _saving = false; _error = e.response?.data?['error'] ?? 'Failed to send'; });
    } catch (_) { setState(() { _saving = false; _error = 'Network error'; }); }
  }

  Color get _typeColor {
    switch (_type) {
      case 'exam':      return const Color(0xFF66BB6A);
      case 'holiday':   return const Color(0xFF42A5F5);
      case 'fee':       return const Color(0xFFEF5350);
      case 'emergency': return Colors.deepOrange;
      default:          return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(_classesForNotifProvider);

    if (_sent) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Notification Sent')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 72),
          const SizedBox(height: 16),
          const Text('Notification sent to parents!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_titleCtrl.text, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _sent = false; _titleCtrl.clear(); _messageCtrl.clear();
                _type = 'general'; _targetClassId = null;
                _showFrom = null; _showUntil = null;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Send Another', style: TextStyle(color: Colors.white)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Send Notification', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Type selection
          const Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _notifTypes.map((t) {
            final selected = _type == t['value'];
            return GestureDetector(
              onTap: () => setState(() => _type = t['value'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _typeColor.withOpacity(0.15) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? _typeColor : Colors.grey.shade300, width: selected ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t['icon'] as IconData, size: 14, color: selected ? _typeColor : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(t['label'] as String,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: selected ? _typeColor : AppColors.textSecondary)),
                ]),
              ),
            );
          }).toList()),
          const SizedBox(height: 20),

          // Target
          const Text('Send To', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _targetBtn('All Parents', 'parents', Icons.people_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _targetBtn('Specific Class', 'class', Icons.class_rounded)),
          ]),
          if (_target == 'class') ...[
            const SizedBox(height: 10),
            classes.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) => DropdownButtonFormField<String>(
                value: _targetClassId,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                dropdownColor: Colors.white,
                iconEnabledColor: Color(0xFF64748B),
                decoration: InputDecoration(
                  labelText: 'Select Class',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.white),
                hint: const Text('Choose class'),
                items: list.map((c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text('Class ${c['name']} - ${c['section']}'),
                )).toList(),
                onChanged: (v) => setState(() => _targetClassId = v),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Title
          const Text('Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Final Exam Schedule Released',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Message
          const Text('Message', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _messageCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write the full message here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
          ),

          const SizedBox(height: 20),
          // Visibility date range
          const Text('Visibility Period (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Set the dates between which this notification will appear on parents\' app.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _datePicker(
              label: 'Show From',
              date: _showFrom,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _showFrom ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _showFrom = d);
              },
              onClear: () => setState(() => _showFrom = null),
            )),
            const SizedBox(width: 12),
            Expanded(child: _datePicker(
              label: 'Show Until',
              date: _showUntil,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _showUntil ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _showUntil = d);
              },
              onClear: () => setState(() => _showUntil = null),
            )),
          ]),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
          ],
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _saving ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: _typeColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
            label: Text(_saving ? 'Sending...' : 'Send Notification',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ])),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null ? AppColors.primary : Colors.grey.shade300,
            width: date != null ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(Icons.calendar_month_rounded,
              size: 16,
              color: date != null ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(
            date != null ? DateFormat('d MMM yyyy').format(date) : label,
            style: TextStyle(
              fontSize: 12,
              color: date != null ? AppColors.primary : AppColors.textSecondary,
              fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
            ),
          )),
          if (date != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
            ),
        ]),
      ),
    );
  }

  Widget _targetBtn(String label, String value, IconData icon) {
    final selected = _target == value;
    return GestureDetector(
      onTap: () => setState(() { _target = value; if (value == 'parents') _targetClassId = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300, width: selected ? 1.5 : 1)),
        child: Column(children: [
          Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary, size: 22),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
