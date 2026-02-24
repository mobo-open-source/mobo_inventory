import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/forms/custom_dropdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CustomDropdown renders label, hint, items, and onChanged fires', (tester) async {
    String? selected = 'a';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomDropdown<String>(
          value: selected,
          labelText: 'Status',
          hintText: 'Pick one',
          items: const [
            DropdownMenuItem(value: 'a', child: Text('A')),
            DropdownMenuItem(value: 'b', child: Text('B')),
          ],
          onChanged: (v) => selected = v,
        ),
      ),
    ));

    expect(find.text('Status'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);

    // Open dropdown and select B
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(selected, 'b');
  });

  testWidgets('CustomDropdown disabled prevents onChanged', (tester) async {
    String? selected;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomDropdown<String>(
          value: selected,
          labelText: 'Disabled',
          items: const [
            DropdownMenuItem(value: 'x', child: Text('X')),
          ],
          onChanged: (v) => selected = v,
          enabled: false,
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump();

    // No menu should open for disabled
    expect(find.byType(Scrollable), findsNothing);
  });
}
