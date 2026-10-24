import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/mobile_repository_provider.dart';
import 'data/repositories/offline_sync_service.dart';
import 'features/auth/face_login_screen.dart';
import 'features/shell/worker_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background network auto-sync listener
  OfflineSyncService.instance.startListening();

  runApp(const ProviderScope(child: BantayGawaMobileApp()));
}

class BantayGawaMobileApp extends ConsumerWidget {
  const BantayGawaMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'BantayGawa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: userAsync.when(
        data: (user) {
          if (user != null) {
            return const WorkerShellView();
          }
          return const FaceLoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => const FaceLoginScreen(),
      ),
    );
  }
}
