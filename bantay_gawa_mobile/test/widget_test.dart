import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bantay_gawa_mobile/main.dart';

void main() {
  testWidgets('Bantay Gawa Mobile app launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BantayGawaMobileApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(BantayGawaMobileApp), findsOneWidget);
  });
}
