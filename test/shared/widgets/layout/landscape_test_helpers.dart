import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone in landscape: 800×360 logical px with a 24px status bar — the
/// short end of real devices, where the tester's screenshots came from.
void setLandscapePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1080);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 72);
  tester.view.viewPadding = const FakeViewPadding(top: 72);
  addTearDown(tester.view.reset);
}

/// The same phone in portrait: 360×800 logical px with a 24px status bar.
void setPortraitPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 72);
  tester.view.viewPadding = const FakeViewPadding(top: 72);
  addTearDown(tester.view.reset);
}

/// Height of the stand-in bottom navigation bar (MainShell's is 70px).
const double fakeBottomNavHeight = 70;

const fakeShellAppBarKey = ValueKey('fake-shell-app-bar');

/// Stands in for `MainShell`: its title AppBar (absent on the Replenishment
/// tab, which draws its own) above the tab body, and a 70px bottom bar.
class FakeShell extends StatelessWidget {
  const FakeShell({super.key, required this.child, this.showAppBar = true});

  final Widget child;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(key: fakeShellAppBarKey, title: const Text('Shell'))
          : null,
      body: child,
      bottomNavigationBar: const SizedBox(
        key: ValueKey('fake-bottom-nav'),
        height: fakeBottomNavHeight,
      ),
    );
  }
}

/// The region a tab body actually gets inside [FakeShell]: below the app bar
/// (or the status bar) and above the bottom bar.
Rect tabBodyRect(WidgetTester tester) {
  final scaffold = tester.getRect(find.byType(Scaffold).first);
  final navTop = tester.getTopLeft(find.byKey(const ValueKey('fake-bottom-nav'))).dy;
  final shellAppBar = find.byKey(fakeShellAppBarKey);
  final top = shellAppBar.evaluate().isEmpty
      ? MediaQuery.of(tester.element(find.byType(FakeShell))).padding.top
      : tester.getBottomLeft(shellAppBar).dy;
  return Rect.fromLTRB(scaffold.left, top, scaffold.right, navTop);
}
