import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Always clear stored tokens on startup — every page refresh requires re-login
  try {
    await SecureStorageService.clearAll()
        .timeout(const Duration(seconds: 2));
  } catch (_) {}
  runApp(const ProviderScope(child: SchoolMgmtApp()));
}
