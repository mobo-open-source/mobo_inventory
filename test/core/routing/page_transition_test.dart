import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/routing/page_transition.dart';

class TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  testWidgets('dynamicRoute pushes and shows screen on Android', (tester) async {
    final observer = TestNavigatorObserver();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(dynamicRoute(context, const _DummyScreen()));
          },
          child: const Text('Go'),
        ),
      ),
      navigatorObservers: [observer],
    ));

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(observer.pushed.isNotEmpty, isTrue);
    expect(find.text('Dummy'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('dynamicRoute uses CupertinoPageRoute on iOS', (tester) async {
    final observer = TestNavigatorObserver();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(dynamicRoute(context, const _DummyScreen()));
          },
          child: const Text('Go'),
        ),
      ),
      navigatorObservers: [observer],
    ));

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    // Last pushed route should be CupertinoPageRoute on iOS
    expect(observer.pushed.last, isA<CupertinoPageRoute>());
    expect(find.text('Dummy'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}

class _DummyScreen extends StatelessWidget {
  const _DummyScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dummy')));
  }
}
