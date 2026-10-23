import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/dashboard/widgets/dashboard_stat_card.dart';

/// The stat-card grid with [count] plain boxes, [width] dp wide and with the
/// dashboard's 16dp side padding.
Widget _grid(int count, double width) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
          builder: (context, constraints) => CustomScrollView(
            slivers: [
              SliverGrid(
                gridDelegate: DashboardStatCard.gridDelegate(
                  context,
                  constraints.maxWidth,
                  itemCount: count,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Container(key: ValueKey('box$i')),
                  childCount: count,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _screen(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Rect _box(WidgetTester tester, int i) =>
    tester.getRect(find.byKey(ValueKey('box$i')));

void main() {
  group('two columns (a phone)', () {
    testWidgets('an odd count: the last card spans the whole row', (
      tester,
    ) async {
      _screen(tester, 400);
      await tester.pumpWidget(_grid(5, 400));

      final first = _box(tester, 0);
      final last = _box(tester, 4);
      expect(first.width, closeTo((368 - 12) / 2, 0.01));
      expect(last.width, closeTo(368, 0.01));
      expect(last.left, first.left, reason: 'starts at the row start');

      // Same height as the rest, directly under the last full row.
      expect(last.height, first.height);
      expect(last.top, _box(tester, 2).bottom + 12);
    });

    testWidgets('an even count is the plain grid', (tester) async {
      _screen(tester, 400);
      await tester.pumpWidget(_grid(6, 400));

      for (var i = 0; i < 6; i++) {
        expect(_box(tester, i).width, closeTo((368 - 12) / 2, 0.01));
      }
    });

    testWidgets('a single card fills the row', (tester) async {
      _screen(tester, 400);
      await tester.pumpWidget(_grid(1, 400));

      expect(_box(tester, 0).width, closeTo(368, 0.01));
    });

    testWidgets('the cards above a lone last one are unchanged', (
      tester,
    ) async {
      _screen(tester, 400);
      await tester.pumpWidget(_grid(5, 400));

      expect(_box(tester, 0).left, 16);
      expect(_box(tester, 1).left, closeTo(16 + (368 - 12) / 2 + 12, 0.01));
      expect(_box(tester, 1).right, closeTo(16 + 368, 0.01));
    });
  });

  group('three columns (a tablet)', () {
    testWidgets('one left over spans the row; two share it', (tester) async {
      _screen(tester, 800);

      await tester.pumpWidget(_grid(4, 800));
      expect(_box(tester, 3).width, closeTo(768, 0.01));

      await tester.pumpWidget(_grid(5, 800));
      final a = _box(tester, 3);
      final b = _box(tester, 4);
      expect(a.width, closeTo((768 - 12) / 2, 0.01));
      expect(b.width, a.width);
      expect(b.left, closeTo(a.right + 12, 0.01));
      expect(b.right, closeTo(16 + 768, 0.01));
    });
  });

  testWidgets('RTL: a lone last card still spans the row', (tester) async {
    _screen(tester, 400);
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.rtl, child: _grid(3, 400)),
    );

    final last = _box(tester, 2);
    expect(last.width, closeTo(368, 0.01));
    expect(last.left, closeTo(16, 0.01));
  });
}
