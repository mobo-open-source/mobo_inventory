import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/section_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SectionCard renders title, icon, children and optional trailing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'General',
              icon: Icons.tune,
              headerTrailing: const Text('More'),
              children: const [
                ListTile(title: Text('Child 1')),
                ListTile(title: Text('Child 2')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
    },
  );
}
