import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_inv_app/shared/widgets/pagination/pagination_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget controls({
    required bool canGoToPreviousPage,
    required bool canGoToNextPage,
    required String paginationText,
    VoidCallback? onPreviousPage,
    VoidCallback? onNextPage,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: PaginationControls(
            canGoToPreviousPage: canGoToPreviousPage,
            canGoToNextPage: canGoToNextPage,
            onPreviousPage: onPreviousPage ?? () {},
            onNextPage: onNextPage ?? () {},
            paginationText: paginationText,
            isDark: false,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
  }

  testWidgets('PaginationControls shows text and triggers callbacks when enabled', (tester) async {
    int previous = 0;
    int next = 0;

    await tester.pumpWidget(
      controls(
        canGoToPreviousPage: true,
        canGoToNextPage: true,
        onPreviousPage: () => previous++,
        onNextPage: () => next++,
        paginationText: '21-40/200',
      ),
    );

    expect(find.text('21-40/200'), findsOneWidget);

    await tester.tap(find.byIcon(HugeIcons.strokeRoundedArrowLeft01));
    await tester.pump();
    await tester.tap(find.byIcon(HugeIcons.strokeRoundedArrowRight01));
    await tester.pump();

    expect(previous, 1);
    expect(next, 1);
  });

  testWidgets('PaginationControls disables the arrow with no page to go to', (tester) async {
    int previous = 0;
    int next = 0;

    await tester.pumpWidget(
      controls(
        canGoToPreviousPage: false,
        canGoToNextPage: true,
        onPreviousPage: () => previous++,
        onNextPage: () => next++,
        paginationText: '1-20/200',
      ),
    );

    await tester.tap(find.byIcon(HugeIcons.strokeRoundedArrowLeft01));
    await tester.pump();

    expect(previous, 0);
    expect(next, 0);
  });

  testWidgets('PaginationControls keeps the record count on a single page', (tester) async {
    await tester.pumpWidget(
      controls(
        canGoToPreviousPage: false,
        canGoToNextPage: false,
        paginationText: '1-5/5',
      ),
    );

    expect(find.text('1-5/5'), findsOneWidget);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowLeft01), findsNothing);
    expect(find.byIcon(HugeIcons.strokeRoundedArrowRight01), findsNothing);
  });
}
