import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App can build a minimal shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('smoke'))));
    expect(find.text('smoke'), findsOneWidget);
  });
}
