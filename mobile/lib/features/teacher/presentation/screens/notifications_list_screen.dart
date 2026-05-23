import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'send_notification_screen.dart';

final _myNotificationsProvider = FutureProvider<List>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.teacherAnnouncements);
  return r.data['data'] as List;
});

const _typeColors = {
  'exam':      Color(0xFF66BB6A),
  'holiday':   Color(0xFF42A5F5),
  'fee':       Color(0xFFEF5350),
  'emergency': Colors.deepOrange,
};

const _typeIcons = {
  'exam':      Icons.grade_rounded,
  'holiday':   Icons.beach_access_rounded,
  'fee':       Icons.payment_rounded,
  'emergency': Icons.warning_amber_rounded,
};

class NotificationsListScreen extends ConsumerWidget {
  const NotificationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myNotificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.send_rounded, color: Colors.white),
        label: const Text('Send New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SendNotificationScreen()))
            .then((_) => ref.invalidate(_myNotificationsProvider)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No notifications sent yet.',
                style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const Text('Tap "Send New" to notify parents.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: list.length,
              itemBuilder: (_, i) => _NotifCard(
                notif: list[i] as Map<String, dynamic>,
                onDeleted: () => ref.invalidate(_myNotificationsProvider),
                onEdited:  () => ref.invalidate(_myNotificationsProvider),
              ),
            ),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onDeleted;
  final VoidCallback onEdited;
  const _NotifCard({required this.notif, required this.onDeleted, required this.onEdited});

  Color get _color => _typeColors[notif['type'] as String?] ?? AppColors.primary;
  IconData get _icon => _typeIcons[notif['type'] as String?] ?? Icons.campaign_rounded;

  @override
  Widget build(BuildContext context) {
    final classTarget = notif['class_name'] != null
        ? 'Class ${notif['class_name']} - ${notif['section']}'
        : null;
    final showFrom  = notif['show_from']  as String?;
    final showUntil = notif['show_until'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(_icon, color: _color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(notif['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(notif['body'] as String,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (classTarget != null)
              _chip(Icons.class_rounded, classTarget, _color),
            if (showFrom != null || showUntil != null)
              _chip(Icons.date_range_rounded,
                '${_fmtDate(showFrom)} – ${_fmtDate(showUntil)}',
                Colors.grey.shade600),
            _chip(Icons.access_time_rounded,
              _fmtDate(notif['created_at'] as String),
              Colors.grey.shade500),
          ]),
        ])),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit')   _showEditSheet(context);
            if (v == 'delete') _confirmDelete(context);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit',   child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete',
              style: TextStyle(color: Colors.red))),
          ],
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: color),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
  ]);

  String _fmtDate(String? iso) {
    if (iso == null) return '--';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) { return iso; }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Remove this notification from all parents\' apps?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiClient.instance.delete(
                  ApiConstants.teacherAnnouncementById(notif['id'] as String));
                onDeleted();
              } on DioException catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.response?.data?['error'] ?? 'Failed'),
                  backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final titleCtrl   = TextEditingController(text: notif['title'] as String);
    final messageCtrl = TextEditingController(text: notif['body']  as String);
    DateTime? showFrom  = _parseDate(notif['show_from']  as String?);
    DateTime? showUntil = _parseDate(notif['show_until'] as String?);
    bool saving = false;
    String? err;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        Future<void> save() async {
          if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
            setModal(() => err = 'Title and message are required'); return;
          }
          setModal(() { saving = true; err = null; });
          try {
            await ApiClient.instance.put(
              ApiConstants.teacherAnnouncementById(notif['id'] as String),
              data: {
                'title': titleCtrl.text.trim(),
                'body':  messageCtrl.text.trim(),
                if (showFrom  != null) 'show_from':  DateFormat('yyyy-MM-dd').format(showFrom!),
                if (showUntil != null) 'show_until': DateFormat('yyyy-MM-dd').format(showUntil!),
                if (showFrom  == null) 'show_from':  null,
                if (showUntil == null) 'show_until': null,
              },
            );
            onEdited();
            if (ctx.mounted) Navigator.pop(ctx);
          } on DioException catch (e) {
            setModal(() { saving = false; err = e.response?.data?['error'] ?? 'Failed'; });
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Notification',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: AppColors.background),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: AppColors.background),
              ),
              const SizedBox(height: 12),
              // Date range
              const Text('Visibility Period',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _editDateTile(ctx, 'Show From', showFrom,
                  (d) => setModal(() => showFrom = d),
                  () => setModal(() => showFrom = null))),
                const SizedBox(width: 10),
                Expanded(child: _editDateTile(ctx, 'Show Until', showUntil,
                  (d) => setModal(() => showUntil = d),
                  () => setModal(() => showUntil = null))),
              ]),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          )),
        );
      }),
    );
  }

  Widget _editDateTile(BuildContext ctx, String label, DateTime? date,
      void Function(DateTime) onPick, VoidCallback onClear) =>
    InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: ctx,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: date != null ? AppColors.primary.withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null ? AppColors.primary : Colors.grey.shade300,
            width: date != null ? 1.5 : 1)),
        child: Row(children: [
          Icon(Icons.calendar_month_rounded, size: 14,
            color: date != null ? AppColors.primary : Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(
            date != null ? DateFormat('d MMM yy').format(date) : label,
            style: TextStyle(
              fontSize: 12,
              color: date != null ? AppColors.primary : AppColors.textSecondary,
              fontWeight: date != null ? FontWeight.w600 : FontWeight.normal))),
          if (date != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 13, color: AppColors.textSecondary)),
        ]),
      ),
    );

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }
}
