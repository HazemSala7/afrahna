import 'package:flutter_test/flutter_test.dart';

import 'package:afrahna/main.dart';

void main() {
  testWidgets('App boots and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(const AfrahnaApp());
    await tester.pump();
    expect(find.text('افراحنا'), findsWidgets);
  });
}
