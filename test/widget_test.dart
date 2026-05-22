import 'package:flutter_test/flutter_test.dart';
import 'package:companion/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const CompanionApp());
    expect(find.text('Канбан'), findsOneWidget);
  });
}
