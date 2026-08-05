import 'package:flutter_test/flutter_test.dart';
import 'package:red_app/main.dart';

void main() {
  testWidgets('RedApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RedApp());
    expect(find.text('RED APP'), findsOneWidget);
  });
}
