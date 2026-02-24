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
}
