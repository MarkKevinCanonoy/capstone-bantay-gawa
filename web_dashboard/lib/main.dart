import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConstants.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization notice: $e');
  }
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
