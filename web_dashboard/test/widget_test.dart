import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_dashboard/main.dart';

void main() {
  testWidgets('BantayGawa Web Dashboard boots cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BantayGawaWebDashboard(),
      ),
    );

    // Verify header title or brand renders
    expect(find.text('BantayGawa'), findsOneWidget);
    expect(find.text('ENRO Ormoc City'), findsWidgets);
  });
}
