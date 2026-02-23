import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/loaders/loading_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoadingWidget reduceMotion shows static icon and message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LoadingWidget(
          message: 'Please wait',
          reduceMotion: true,
          size: 24,
        ),
      ),
    ));

    expect(find.text('Please wait'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
  });

  testWidgets('LoadingWidget overlay renders barrier and card with message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LoadingWidget(
          message: 'Loading overlay',
          overlay: true,
          reduceMotion: true,
        ),
      ),
    ));

    // ModalBarrier and Card should be present (allow multiple barriers)
    expect(find.byType(ModalBarrier), findsAtLeastNWidgets(1));
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Loading overlay'), findsOneWidget);
  });
}
