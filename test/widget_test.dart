import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/main.dart';

void main() {
  testWidgets('app starts on the home tab', (tester) async {
    await tester.pumpWidget(const FinanceApp());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Início'), findsOneWidget);
  });
}
