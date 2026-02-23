import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/snackbars/custom_snackbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> _pumpBase(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                CustomSnackbar.show(
                  context: context,
                  title: 'Title',
                  message: 'Message',
                  type: SnackbarType.success,
                  duration: const Duration(milliseconds: 200),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('CustomSnackbar shows overlay with title and message and auto-dismisses', (tester) async {
    // Rebuild base with a longer duration so we can assert before it closes
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                CustomSnackbar.show(
                  context: context,
                  title: 'Title',
                  message: 'Message',
                  type: SnackbarType.success,
                  duration: const Duration(seconds: 1),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    // Pump one frame to present dialog
    await tester.pump();

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);

    // Advance time beyond duration to auto-dismiss
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Title'), findsNothing);
  });

  testWidgets('CustomSnackbar close button dismisses overlay', (tester) async {
    // Build with a custom button that shows longer duration snackbar
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                CustomSnackbar.show(
                  context: context,
                  title: 'Title',
                  message: 'Message',
                  type: SnackbarType.success,
                  duration: const Duration(seconds: 2),
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // Close icon exists and can dismiss
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    // Advance time to flush any scheduled auto-dismiss timer
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Title'), findsNothing);
  });
}
