import 'dart:math' as math;
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
  'general':   Color(0xFF7986CB),
};

const _typeIcons = {
  'exam':      Icons.grade_rounded,
  'holiday':   Icons.beach_access_rounded,
  'fee':       Icons.payment_rounded,
  'emergency': Icons.warning_amber_rounded,
  'general':   Icons.campaign_rounded,
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
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No announcements right now.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                const Text('Check back later for updates from school.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final ann = list[i] as Map<String, dynamic>;
                  if (ann['type'] == 'birthday') {
                    return _BirthdayCard(
                      ann: ann,
                      onDismissed: () => ref.invalidate(_parentAnnouncementsProvider),
                    );
                  }
                  return _AnnouncementCard(
                    ann: ann,
                    onDismissed: () => ref.invalidate(_parentAnnouncementsProvider),
                  );
                },
              ),
      ),
    );
  }
}

// ── Birthday Postcard ─────────────────────────────────────────────────────────

class _BirthdayCard extends StatefulWidget {
  final Map<String, dynamic> ann;
  final VoidCallback onDismissed;
  const _BirthdayCard({required this.ann, required this.onDismissed});

  @override
  State<_BirthdayCard> createState() => _BirthdayCardState();
}

class _BirthdayCardState extends State<_BirthdayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // Extract student name from title "Happy Birthday, NAME! 🎂"
  String _studentName() {
    final title = widget.ann['title'] as String? ?? '';
    final match = RegExp(r'Happy Birthday, (.+?)!').firstMatch(title);
    return match?.group(1) ?? title;
  }

  @override
  Widget build(BuildContext context) {
    final name = _studentName();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withOpacity(0.35),
            blurRadius: 20, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (_, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: const [
                    Color(0xFFFF8F00), Color(0xFFFFB300),
                    Color(0xFFFFCA28), Color(0xFFFFB300),
                    Color(0xFFFF8F00),
                  ],
                  stops: [
                    0.0,
                    (_shimmer.value * 0.5).clamp(0.0, 0.4),
                    (_shimmer.value * 0.5 + 0.2).clamp(0.2, 0.6),
                    (_shimmer.value * 0.5 + 0.4).clamp(0.4, 0.8),
                    1.0,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: child,
            );
          },
          child: Stack(children: [
            // Decorative dots
            ..._buildDots(),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Dismiss button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: _confirmDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Cake icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: const Text('🎂', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 14),
                // "Happy Birthday" text
                const Text(
                  'Happy Birthday!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 6),
                // Student name
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                ),
                const SizedBox(height: 12),
                // Divider
                Container(height: 1, color: Colors.white.withOpacity(0.4)),
                const SizedBox(height: 12),
                // Message
                Text(
                  widget.ann['body'] as String? ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                    shadows: [Shadow(color: Colors.black12, blurRadius: 2)],
                  ),
                ),
                const SizedBox(height: 16),
                // Celebration row
                Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Text('🎉', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('🌟', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('🎊', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('🌟', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('🎉', style: TextStyle(fontSize: 20)),
                ]),
                const SizedBox(height: 12),
                // From school
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: const Text(
                    '— With love from your School Family 🏫',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildDots() {
    final rng = math.Random(42);
    return List.generate(12, (i) {
      final size  = rng.nextDouble() * 16 + 6;
      final left  = rng.nextDouble() * 320;
      final top   = rng.nextDouble() * 400;
      return Positioned(
        left: left, top: top,
        child: Opacity(
          opacity: 0.12,
          child: Container(
            width: size, height: size,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      );
    });
  }

  void _confirmDismiss() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dismiss'),
        content: const Text('Remove this birthday wish from your view?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiClient.instance.delete(
                    ApiConstants.parentDismissAnnouncement(widget.ann['id'] as String));
                widget.onDismissed();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Regular Announcement Card ─────────────────────────────────────────────────

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
    } catch (_) { return iso; }
  }

  void _confirmDismiss(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Announcement'),
        content: const Text('Remove this announcement from your view?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(_icon, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ann['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(ann['body'] as String,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              if (classTarget != null) ...[
                Icon(Icons.class_rounded, size: 11, color: _color),
                const SizedBox(width: 3),
                Text(classTarget,
                    style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
              ],
              Icon(Icons.access_time_rounded, size: 11, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(_formatDate(ann['created_at'] as String),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
