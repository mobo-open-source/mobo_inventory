import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/filters/premium_filter_bottom_sheet.dart';

import '../layout/landscape_test_helpers.dart';

/// Opens the sheet the way the list screens do, capturing what `onApply`
/// receives. [preselected] marks a status chip as already applied.
Widget _launcher(
  void Function(Map<String, dynamic>) onApply, {
  String? preselected,
}) {
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
                    for (final s in const ['Draft', 'Ready', 'Done'])
                      FilterOption(title: s, value: s == preselected),
                  ],
                ),
              ],
              groupByOptions: [
                FilterGroup(
                  title: 'Group By',
                  options: [
                    FilterOption(title: 'Status', value: false),
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

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _isSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  testWidgets('selecting a filter chip and tapping Apply passes it on and '
      'closes the sheet', (tester) async {
    setPortraitPhone(tester);
    Map<String, dynamic>? applied;
    await tester.pumpWidget(_launcher((v) => applied = v));
    await _open(tester);

    await tester.tap(find.text('Ready'));
    await tester.pump();
    expect(_isSelected(tester, 'Ready'), isTrue);
    expect(_isSelected(tester, 'Draft'), isFalse);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(applied?['status_ready'], isTrue);
    expect(applied?['status_draft'], isFalse);
    expect(applied?['status_done'], isFalse);
    expect(find.byType(PremiumFilterBottomSheet), findsNothing);
  });

  testWidgets('several chips in a group can be selected, and one tapped again '
      'is deselected', (tester) async {
    setPortraitPhone(tester);
    Map<String, dynamic>? applied;
    await tester.pumpWidget(_launcher((v) => applied = v));
    await _open(tester);

    await tester.tap(find.text('Draft'));
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.tap(find.text('Draft'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(applied?['status_draft'], isFalse);
    expect(applied?['status_done'], isTrue);
  });

  testWidgets('a filter that is already applied opens selected', (
    tester,
  ) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(_launcher((_) {}, preselected: 'Done'));
    await _open(tester);

    expect(_isSelected(tester, 'Done'), isTrue);
    expect(_isSelected(tester, 'Draft'), isFalse);
    // And it is listed under Active Filters.
    expect(find.text('Status (1)'), findsOneWidget);
  });

  testWidgets('the ✕ on an active-filter chip clears that group', (
    tester,
  ) async {
    setPortraitPhone(tester);
    Map<String, dynamic>? applied;
    await tester.pumpWidget(
      _launcher((v) => applied = v, preselected: 'Ready'),
    );
    await _open(tester);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Status (1)'),
          matching: find.byType(Container),
        ),
        matching: find.byIcon(Icons.close),
      ).first,
    );
    await tester.pump();
    expect(find.text('Status (1)'), findsNothing);
    expect(_isSelected(tester, 'Ready'), isFalse);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied?['status_ready'], isFalse);
  });

  testWidgets('Group By: one option at a time, and it is applied', (
    tester,
  ) async {
    setPortraitPhone(tester);
    Map<String, dynamic>? applied;
    await tester.pumpWidget(_launcher((v) => applied = v));
    await _open(tester);

    await tester.tap(find.text('Group By').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Status').last);
    await tester.pump();
    await tester.tap(find.text('Priority'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(applied?['group_by_priority'], isTrue);
    expect(applied?['group_by_status'], isFalse);
  });

  testWidgets('Clear All resets every selection, applies, and closes', (
    tester,
  ) async {
    setPortraitPhone(tester);
    Map<String, dynamic>? applied;
    await tester.pumpWidget(
      _launcher((v) => applied = v, preselected: 'Draft'),
    );
    await _open(tester);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.values.every((v) => v == false), isTrue);
    expect(find.byType(PremiumFilterBottomSheet), findsNothing);
  });

  testWidgets('dismissing without Apply changes nothing', (tester) async {
    setPortraitPhone(tester);
    var calls = 0;
    await tester.pumpWidget(_launcher((_) => calls++));
    await _open(tester);

    await tester.tap(find.text('Ready'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(PremiumFilterBottomSheet), findsNothing);
  });
}
