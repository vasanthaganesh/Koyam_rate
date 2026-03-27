import 'package:flutter_test/flutter_test.dart';
import 'package:koyam_rate/main.dart';

void main() {
  testWidgets('KoyamRate app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const KoyamRateApp());
    expect(find.text('KoyamRate'), findsOneWidget);
  });
}
