import 'package:flutter/material.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_inv_app/shared/widgets/shared_bottom_nav_bar.dart';

class MockStatefulNavigationShell extends Mock
    implements StatefulNavigationShell {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      super.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStatefulNavigationShell mockNavigationShell;

  setUp(() {
    mockNavigationShell = MockStatefulNavigationShell();
    when(() => mockNavigationShell.currentIndex).thenReturn(0);
  });

  testWidgets('SharedBottomNavBar renders items and invokes goBranch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: SharedBottomNavBar(
            navigationShell: mockNavigationShell,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(SnakeNavigationBar), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);

    // Tap the third item (Transfer)
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    verify(
      () => mockNavigationShell.goBranch(2, initialLocation: false),
    ).called(1);
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required List<int> visibleBranches,
    bool compact = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: SharedBottomNavBar(
            navigationShell: mockNavigationShell,
            visibleBranches: visibleBranches,
            compact: compact,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('shows only the allowed tabs and maps taps to branch indices', (
    tester,
  ) async {
    await pumpBar(tester, visibleBranches: const [0, 1, 4]);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Transfer'), findsNothing);
    expect(find.text('Replenish'), findsNothing);

    // Third nav position is branch 4, not branch 2.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    verify(
      () => mockNavigationShell.goBranch(4, initialLocation: false),
    ).called(1);
  });

  testWidgets('re-tapping the current tab resets it to its first page', (
    tester,
  ) async {
    when(() => mockNavigationShell.currentIndex).thenReturn(4);
    await pumpBar(tester, visibleBranches: const [0, 4]);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    verify(
      () => mockNavigationShell.goBranch(4, initialLocation: true),
    ).called(1);
  });

  test('positionOf maps a branch to its nav slot, hidden ones to Dashboard', () {
    expect(SharedBottomNavBar.positionOf(4, const [0, 1, 4]), 2);
    expect(SharedBottomNavBar.positionOf(3, const [0, 1, 2]), 0);
  });

  testWidgets('uses the shorter bar on a compact-height screen', (
    tester,
  ) async {
    await pumpBar(tester, visibleBranches: SharedBottomNavBar.allBranches);
    expect(
      tester.widget<SnakeNavigationBar>(find.byType(SnakeNavigationBar)).height,
      SharedBottomNavBar.regularHeight,
    );

    await pumpBar(
      tester,
      visibleBranches: SharedBottomNavBar.allBranches,
      compact: true,
    );
    expect(
      tester.widget<SnakeNavigationBar>(find.byType(SnakeNavigationBar)).height,
      SharedBottomNavBar.compactHeight,
    );
    expect(tester.takeException(), isNull); // icon + label still fit
    expect(find.text('Replenish'), findsOneWidget);
  });
}
