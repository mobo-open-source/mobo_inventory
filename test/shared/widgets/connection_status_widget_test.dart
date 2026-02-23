import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/connection_status_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows Connection Error and default message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ConnectionStatusWidget()),
    ));

    expect(find.text('Connection Error'), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('serverUnreachable toggles title and uses provided customMessage', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ConnectionStatusWidget(
          serverUnreachable: true,
          customMessage: 'Cannot reach server',
        ),
      ),
    ));

    expect(find.text('Server Unreachable'), findsOneWidget);
    expect(find.text('Cannot reach server'), findsOneWidget);
  });

  testWidgets('onRetry shows ElevatedButton and invokes callback', (tester) async {
    bool retried = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConnectionStatusWidget(onRetry: () => retried = true),
      ),
    ));

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
