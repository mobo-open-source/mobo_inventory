import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/filters/premium_filter_bottom_sheet.dart';

import '../layout/landscape_test_helpers.dart';

/// Opens the sheet with the Transfer tab's filter set (issue 9's screenshot).
Widget _launcher(void Function(Map<String, dynamic>) onApply) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => PremiumFilterBottomSheet.show(
              context: context,
              title: 'Filter & Group By',
              filterGroups: [
                FilterGroup(
                  title: 'Status',
                  options: [
                    for (final s in const [
                      'Draft',
                      'Waiting Another Operation',
                      'Waiting',
                      'Ready',
                      'Done',
                      'Cancelled',
                    ])
                      FilterOption(title: s, value: false),
                  ],
                ),
                FilterGroup(
                  title: 'Date Range',
                  options: [
                    FilterOption(title: 'Start Date', value: false),
                    FilterOption(title: 'End Date', value: false),
                  ],
                ),
              ],
              groupByOptions: [
                FilterGroup(
                  title: 'Group By',
                  options: [
                    FilterOption(title: 'Status', value: false),
                    FilterOption(title: 'Date', value: false),
                    FilterOption(title: 'Priority', value: false),
                  ],
                ),
              ],
              onApply: onApply,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Rect _sheet(WidgetTester tester) =>
    tester.getRect(find.byType(PremiumFilterBottomSheet));

void main() {
  group('landscape (issue 9)', () {
    testWidgets('uses nearly the full height below the status bar, capped '
        'in width', (tester) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(_launcher((_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final sheet = _sheet(tester);
      expect(sheet.top, moreOrLessEquals(24 + 8)); // status bar + gap
      expect(sheet.bottom, moreOrLessEquals(360));
      expect(sheet.width, 640);
      expect(sheet.center.dx, moreOrLessEquals(400)); // centred
    });

    testWidgets('footer stays pinned and fully visible', (tester) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(_launcher((_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      for (final label in ['Clear All', 'Apply']) {
        expect(tester.getRect(find.text(label)).bottom, lessThan(360));
      }
      final applyTop = tester.getTopLeft(find.text('Apply')).dy;

      await tester.drag(find.text('Status').first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Apply')).dy, applyTop);
    });

    testWidgets('title and tabs scroll away so the options get the room', (
      tester,
    ) async {
      setLandscapePhone(tester);
      Map<String, dynamic>? applied;
      await tester.pumpWidget(_launcher((v) => applied = v));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Group By'));
      await tester.pumpAndSettle();
      // Before scrolling, "None / Display as a simple list" is not hidden
      // behind the tabs any more.
      final tabsBottom = tester.getBottomLeft(find.byType(TabBar)).dy;
      expect(
        tester.getTopLeft(find.text('Display as a simple list')).dy,
        greaterThan(tabsBottom),
      );

      final footerTop = tester
          .getTopLeft(find.widgetWithText(OutlinedButton, 'Clear All'))
          .dy;
      await tester.drag(find.text('None'), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Filter & Group By'), findsNothing); // scrolled off
      // Every group-by option fits between the handle and the footer.
      for (final label in ['Status', 'Date', 'Priority']) {
        final rect = tester.getRect(find.text(label).last);
        expect(rect.top, greaterThan(_sheet(tester).top));
        expect(rect.bottom, lessThan(footerTop));
      }

      await tester.tap(find.text('Priority'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(applied?['group_by_priority'], isTrue);
    });

    testWidgets('Filter tab: every status chip and the dates are reachable', (
      tester,
    ) async {
      setLandscapePhone(tester);
      await tester.pumpWidget(_launcher((_) {}));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Status').first, const Offset(0, -400));
      await tester.pumpAndSettle();
      final footerTop = tester
          .getTopLeft(find.widgetWithText(OutlinedButton, 'Clear All'))
          .dy;
      expect(tester.getRect(find.text('End Date')).bottom, lessThan(footerTop));
      expect(
        tester.getRect(find.text('Cancelled')).top,
        greaterThan(_sheet(tester).top),
      );
    });
  });

  testWidgets('portrait layout is unchanged', (tester) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(_launcher((_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = _sheet(tester);
    expect(sheet.height, moreOrLessEquals(800 * 0.8));
    expect(sheet.width, 360);
    expect(
      find.descendant(
        of: find.byType(PremiumFilterBottomSheet),
        matching: find.byType(NestedScrollView),
      ),
      findsNothing,
    );

    // Title and tabs stay pinned while the options scroll.
    final titleTop = tester.getTopLeft(find.text('Filter & Group By')).dy;
    await tester.drag(find.text('Status').first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Filter & Group By')).dy, titleTop);
  });
}
