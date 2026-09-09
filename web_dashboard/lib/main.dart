import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: BantayGawaWebDashboard(),
    ),
  );
}

class BantayGawaWebDashboard extends StatelessWidget {
  const BantayGawaWebDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BantayGawa - ENRO Ormoc City Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const BantayGawaAppShell(),
    );
  }
}
