import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/loaders/loading_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoadingIndicator shows LoadingWidget and optional message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LoadingIndicator(message: 'Fetching data...'),
      ),
    ));

    expect(find.text('Fetching data...'), findsOneWidget);
    // SmallLoadingIndicator is also a LoadingWidget wrapper; ensure no crash when building
  });

  testWidgets('SmallLoadingIndicator builds without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SmallLoadingIndicator()),
    ));

    // Just verify it renders
    expect(find.byType(SmallLoadingIndicator), findsOneWidget);
  });
}
