import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/dialogs/loading_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoadingDialog shows and hides', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  LoadingDialog.show(context, message: 'Please wait');
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    // Pump several times to let the dialog show.
    // pumpAndSettle fails because of the continuous animation in LoadingWidget.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Please wait'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);

    // Hide
    LoadingDialog.hide(tester.element(find.text('Please wait')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Please wait'), findsNothing);
  });
}
