import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

final _parentAnnouncementsProvider = FutureProvider<List>((ref) async {
  final r = await ApiClient.instance.get(ApiConstants.parentAnnouncements);
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

class ParentAnnouncementsScreen extends ConsumerWidget {
  const ParentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_parentAnnouncementsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Announcements', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No announcements right now.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Check back later for updates from school.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _AnnouncementCard(
                  ann: list[i] as Map<String, dynamic>,
                  onDismissed: () => ref.invalidate(_parentAnnouncementsProvider),
                ),
              ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> ann;
  final VoidCallback onDismissed;
  const _AnnouncementCard({required this.ann, required this.onDismissed});

  Color get _color => _typeColors[ann['type'] as String?] ?? AppColors.primary;
  IconData get _icon => _typeIcons[ann['type'] as String?] ?? Icons.campaign_rounded;

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  void _confirmDismiss(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Announcement'),
        content: const Text('Remove this announcement from your view?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ApiClient.instance.delete(
                      ApiConstants.parentDismissAnnouncement(ann['id'] as String));
                  onDismissed();
                } on DioException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.response?.data?['error'] ?? 'Failed to dismiss'),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classTarget = ann['class_name'] != null
        ? 'Class ${ann['class_name']} - ${ann['section']}'
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_icon, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ann['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(ann['body'] as String,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              if (classTarget != null) ...[
                Icon(Icons.class_rounded, size: 11, color: _color),
                const SizedBox(width: 3),
                Text(classTarget,
                    style: TextStyle(
                        fontSize: 11,
                        color: _color,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
              ],
              Icon(Icons.access_time_rounded,
                  size: 11, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(_formatDate(ann['created_at'] as String),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
          tooltip: 'Dismiss',
          onPressed: () => _confirmDismiss(context),
        ),
      ]),
    );
  }
}
