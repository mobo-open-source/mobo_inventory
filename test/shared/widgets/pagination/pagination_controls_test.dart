import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/pagination/pagination_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PaginationControls shows text and triggers callbacks when enabled', (tester) async {
    int previous = 0;
    int next = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PaginationControls(
            canGoToPreviousPage: true,
            canGoToNextPage: true,
            onPreviousPage: () => previous++,
            onNextPage: () => next++,
            paginationText: '1-20 of 200',
            isDark: false,
            theme: ThemeData.light(),
          ),
        ),
      ),
    ));

    expect(find.text('1-20 of 200'), findsOneWidget);

    // Tap chevron left (previous)
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    // Tap chevron right (next)
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(previous, 1);
    expect(next, 1);
  });

  testWidgets('PaginationControls disables taps when not allowed', (tester) async {
    int previous = 0;
    int next = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PaginationControls(
            canGoToPreviousPage: false,
            canGoToNextPage: false,
            onPreviousPage: () => previous++,
            onNextPage: () => next++,
            paginationText: '0-0 of 0',
            isDark: false,
            theme: ThemeData.light(),
          ),
        ),
      ),
    ));

    // Tapping should have no effect (onTap is null)
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));

    expect(previous, 0);
    expect(next, 0);
  });
}
