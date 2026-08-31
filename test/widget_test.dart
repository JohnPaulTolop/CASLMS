import 'package:flutter_test/flutter_test.dart';
import 'package:caslms/main.dart';

void main() {
  testWidgets('CASLMS landing page loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CASLMSApp());

    expect(find.text('CASLMS'), findsOneWidget);
    expect(find.text('Learn. Connect. Grow.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}