import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/badges/status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StatusBadge.transfer maps states to labels/icons/colors', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [
          StatusBadge.transfer('draft'),
          StatusBadge.transfer('assigned'),
          StatusBadge.transfer('done'),
          StatusBadge.transfer('cancel'),
        ],
      ),
    ));

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('StatusBadge.order and invoice default to state label when unknown', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [
          StatusBadge.order('unknown_state'),
          StatusBadge.invoice('unknown_state'),
        ],
      ),
    ));

    expect(find.text('unknown_state'), findsNWidgets(2));
  });
}
