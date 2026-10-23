import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/layout/collapsible_header_layout.dart';

import 'landscape_test_helpers.dart';

void main() {
  Widget buildLayout({TextEditingController? controller}) {
    return MaterialApp(
      home: FakeShell(
        child: CollapsibleHeaderLayout(
          header: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const ValueKey('search'),
                  controller: controller,
                ),
              ),
              const SizedBox(key: ValueKey('chips'), height: 40),
            ],
          ),
          body: ListView.builder(
            itemCount: 30,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Row $i')),
          ),
        ),
      ),
    );
  }

  testWidgets('portrait keeps the header pinned above the list', (
    tester,
  ) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(buildLayout());

    expect(find.byType(NestedScrollView), findsNothing);
    final searchTop = tester.getTopLeft(find.byKey(const ValueKey('search')));

    await tester.drag(find.text('Row 2'), const Offset(0, -300));
    await tester.pumpAndSettle();

    // The list scrolled under a header that stayed put.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('search'))),
      searchTop,
    );
    expect(find.text('Row 0'), findsNothing);
  });

  testWidgets('portrait list keeps a private scroll controller', (
    tester,
  ) async {
    setPortraitPhone(tester);
    await tester.pumpWidget(buildLayout());

    // Cut off from the route's PrimaryScrollController, exactly as when the
    // screens passed their own controller.
    final list = tester.widget<Scrollable>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(list.controller, isNull);
    final route = PrimaryScrollController.maybeOf(
      tester.element(find.byType(CollapsibleHeaderLayout)),
    );
    expect(route?.hasClients ?? false, isFalse);
  });

  testWidgets('landscape scrolls the header away with the list', (
    tester,
  ) async {
    setLandscapePhone(tester);
    await tester.pumpWidget(buildLayout());

    expect(find.byType(NestedScrollView), findsOneWidget);
    final body = tabBodyRect(tester);
    final headerHeight = tester.getTopLeft(find.text('Row 0')).dy - body.top;
    expect(headerHeight, greaterThan(100));

    await tester.drag(find.text('Row 0'), Offset(0, -(headerHeight + 30)));
    await tester.pumpAndSettle();

    // Header gone; the list now fills the tab body from its top edge.
    expect(find.byKey(const ValueKey('chips')), findsNothing); // offstage
    expect(
      tester.getTopLeft(find.text('Row 0')).dy,
      moreOrLessEquals(body.top - 30, epsilon: 1),
    );
  });

  testWidgets('rotating keeps the search field focused and its text', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);
    setPortraitPhone(tester);
    await tester.pumpWidget(buildLayout(controller: controller));

    await tester.tap(find.byKey(const ValueKey('search')));
    await tester.pump();
    final focusNode = tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode;
    expect(focusNode.hasFocus, isTrue);

    setLandscapePhone(tester);
    await tester.pump();
    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode,
      same(focusNode),
    );
    expect(focusNode.hasFocus, isTrue);
    expect(find.text('abc'), findsOneWidget);
  });
}
