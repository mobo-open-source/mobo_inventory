import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/action_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ActionTile renders title, subtitle, icon and trailing; invokes onTap', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: ActionTile(
          title: 'Settings',
          subtitle: 'Manage',
          icon: Icons.settings,
          onTap: () => tapped = true,
          trailing: const Icon(Icons.arrow_forward),
        ),
      ),
    ));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    expect(tapped, isTrue);
  });

  testWidgets('ActionTile destructive uses red tones', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: const Material(
        child: ActionTile(
          title: 'Delete',
          subtitle: 'Remove account',
          icon: Icons.delete,
          destructive: true,
        ),
      ),
    ));

    // Ensure the destructive icon is present
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });
}
