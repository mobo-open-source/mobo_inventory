import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_inv_app/features/dashboard/models/today_activity.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/dashboard_empty_card.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/negative_quants_list.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/replenishment_needs_list.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/today_activities_list.dart';

/// A 400dp-wide screen with the dashboard's 16dp side padding, so a section
/// is 368 wide.
Widget _section(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        ),
      ),
    ),
  );
}

void _screen(WidgetTester tester, {double width = 400}) {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // The test font makes every glyph a full em wide, so a long section heading
  // reports an overflow a real font does not have; the cards are what these
  // tests measure.
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    onError?.call(details);
  };
  addTearDown(() => FlutterError.onError = onError);
}

void main() {
  const sectionWidth = 368.0;

  group('empty sections fill the width, like the sections with data', () {
    testWidgets('Products Needing Replenishment', (tester) async {
      _screen(tester);
      await tester.pumpWidget(_section(const ReplenishmentNeedsList(items: [])));

      expect(find.text('Nothing to replenish'), findsOneWidget);
      expect(find.text('All products are above minimum stock'), findsOneWidget);
      expect(
        tester.getSize(find.byType(DashboardEmptyCard)).width,
        sectionWidth,
      );
    });

    testWidgets('Negative Stock Alerts', (tester) async {
      _screen(tester);
      await tester.pumpWidget(_section(const NegativeQuantsList(items: [])));

      expect(find.text('No negative stock found'), findsOneWidget);
      expect(
        tester.getSize(find.byType(DashboardEmptyCard)).width,
        sectionWidth,
      );
      // No animation fetched from the internet for an empty list.
      expect(find.byType(Lottie), findsNothing);
    });

    testWidgets("Today's Activities", (tester) async {
      _screen(tester);
      await tester.pumpWidget(_section(const TodayActivitiesList(items: [])));

      expect(find.text('No activities today'), findsOneWidget);
      expect(
        tester.getSize(find.byType(DashboardEmptyCard)).width,
        sectionWidth,
      );
    });

    testWidgets('all three look alike: same height, same icon circle', (
      tester,
    ) async {
      // Wide, so the test font wraps none of the detail lines and only the
      // cards' own design decides their height.
      _screen(tester, width: 900);
      await tester.pumpWidget(
        _section(
          const Column(
            children: [
              ReplenishmentNeedsList(items: []),
              NegativeQuantsList(items: []),
              TodayActivitiesList(items: []),
            ],
          ),
        ),
      );

      final cards = find.byType(DashboardEmptyCard);
      expect(cards, findsNWidgets(3));
      final heights = [
        for (var i = 0; i < 3; i++) tester.getSize(cards.at(i)).height,
      ];
      expect(heights.toSet().length, 1, reason: 'cards differ in height');
      // Tinted icon circle + the title and detail beside it, as in a tile.
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
    });

    testWidgets('dark mode renders them too', (tester) async {
      _screen(tester);
      await tester.pumpWidget(
        _section(
          const NegativeQuantsList(items: []),
          brightness: Brightness.dark,
        ),
      );

      expect(find.text('No negative stock found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("Today's Activities with data", () {
    TodayActivity activity(int id, String summary) => TodayActivity(
      id: id,
      resModel: 'stock.picking',
      resId: id,
      summary: summary,
      deadline: DateTime(2026, 10, 12),
    );

    testWidgets('a single activity is a full-width tile, not a short card', (
      tester,
    ) async {
      _screen(tester);
      await tester.pumpWidget(
        _section(TodayActivitiesList(items: [activity(1, 'Pick stock')])),
      );

      final tile = find
          .ancestor(of: find.text('Pick stock'), matching: find.byType(Container))
          .first;
      expect(tester.getSize(tile).width, sectionWidth);
    });

    testWidgets('several activities stack, all the same width', (tester) async {
      _screen(tester);
      await tester.pumpWidget(
        _section(
          TodayActivitiesList(
            items: [
              activity(1, 'First'),
              activity(2, 'Second'),
              activity(3, 'Third'),
            ],
          ),
        ),
      );

      Finder tileOf(String t) => find
          .ancestor(of: find.text(t), matching: find.byType(Container))
          .first;
      for (final t in ['First', 'Second', 'Third']) {
        expect(tester.getSize(tileOf(t)).width, sectionWidth);
      }
      expect(
        tester.getTopLeft(tileOf('Second')).dy,
        greaterThan(tester.getTopLeft(tileOf('First')).dy),
      );
      expect(
        tester.getTopLeft(tileOf('Third')).dy,
        greaterThan(tester.getTopLeft(tileOf('Second')).dy),
      );
    });
  });
}
