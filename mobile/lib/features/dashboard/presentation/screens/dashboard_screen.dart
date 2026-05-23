import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authNotifierProvider.notifier).logout())]),
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
        SizedBox(height: 16),
        Text('Login successful!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text('Dashboard — Phase 2', style: TextStyle(color: AppColors.textSecondary)),
      ])),
    );
  }
}