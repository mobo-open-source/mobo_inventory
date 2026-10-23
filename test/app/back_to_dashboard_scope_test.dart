import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobo_inv_app/app/main_shell.dart';

/// A shell shaped like the app's: Dashboard is branch 0, Transfers branch 2,
/// and the Transfers tab can push a detail page of its own.
GoRouter _router() {
  Widget page(String name) => Scaffold(body: Center(child: Text(name)));
  GoRoute tab(String path) =>
      GoRoute(path: path, builder: (_, __) => page(path));

  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            BackToDashboardScope(navigationShell: shell, child: shell),
        branches: [
          StatefulShellBranch(routes: [tab('/dashboard')]),
          StatefulShellBranch(routes: [tab('/inventory')]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transfer',
                builder: (_, __) => page('/transfer'),
                routes: [
                  GoRoute(
                    path: 'detail',
                    builder: (_, __) => page('/transfer/detail'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// What Android's Back button does: asks the router to pop. False means
/// nothing handled it — the app would close.
Future<bool> _systemBack(WidgetTester tester, GoRouter router) async {
  final handled = await router.routerDelegate.popRoute();
  await tester.pumpAndSettle();
  return handled;
}

void main() {
  testWidgets('Back on another tab returns to the Dashboard', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/transfer');
    await tester.pumpAndSettle();
    expect(find.text('/transfer'), findsOneWidget);

    expect(await _systemBack(tester, router), isTrue);
    expect(find.text('/dashboard'), findsOneWidget);
  });

  testWidgets('Back on the Dashboard is left to the system', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(await _systemBack(tester, router), isFalse);
  });

  testWidgets('a page opened inside a tab is popped first', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/transfer');
    await tester.pumpAndSettle();
    router.push('/transfer/detail');
    await tester.pumpAndSettle();
    expect(find.text('/transfer/detail'), findsOneWidget);

    expect(await _systemBack(tester, router), isTrue);
    expect(find.text('/transfer'), findsOneWidget);

    expect(await _systemBack(tester, router), isTrue);
    expect(find.text('/dashboard'), findsOneWidget);
  });
}
