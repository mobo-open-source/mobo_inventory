import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/theme/app_theme.dart';
import 'package:mobo_inv_app/features/profile/pages/profile_detail_screen.dart';
import 'package:mobo_inv_app/features/profile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/layout/landscape_test_helpers.dart';

/// Serves one profile without a network.
class _FakeProfileProvider extends ProfileProvider {
  @override
  bool get isLoading => false;

  @override
  Map<String, dynamic>? get userData => {
    'name': 'Mitchell Admin',
    'email': 'mitchell@example.com',
    'phone': false,
    'mobile': '555 0100',
    'website': false,
    'function': 'Manager',
    'company_id': [1, 'My Company'],
  };

  @override
  bool isProfileFieldAvailable(String field) => true;

  @override
  Future<Map<String, dynamic>?> loadRelatedCompany() async => null;

  @override
  Future<void> fetchUserProfile() async {}
}

Future<void> _open(WidgetTester tester, {Brightness? brightness}) async {
  setPortraitPhone(tester);
  await tester.pumpWidget(
    ChangeNotifierProvider<ProfileProvider>.value(
      value: _FakeProfileProvider(),
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness ?? Brightness.light,
          primaryColor: AppTheme.primaryColor,
        ),
        home: const ProfileDetailScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The filled box of a field: CRM's pale fill in light mode.
Finder _fieldBoxes(Color fill) => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == fill &&
      (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(12),
  description: 'field box filled $fill',
);

void main() {
  const lightFill = Color(0xffF8FAFB);
  const darkFill = Color(0xFF2A2A2A);

  testWidgets('view mode follows the CRM profile page', (tester) async {
    await _open(tester);

    // Labels: small grey text, not the 16px black of a form label.
    final label = tester.widget<Text>(find.text('Full Name')).style!;
    expect(label.color, const Color(0xff7F7F7F));
    expect(label.fontSize, isNull);

    // Each value sits in a pale filled box with a 1px (transparent) border.
    final boxes = _fieldBoxes(lightFill);
    expect(boxes, findsWidgets);
    final box = tester.widget<Container>(boxes.first);
    expect((box.decoration as BoxDecoration).border!.top.width, 1);

    // Values are plain weight, black; an empty one reads "Not set" in italic.
    final email = tester.widget<Text>(find.text('mitchell@example.com')).style!;
    expect(email.color, const Color(0xff000000));
    expect(email.fontWeight, isNull);
    expect(email.fontSize, 14);
    final notSet = tester.widget<Text>(find.text('Not set').first).style!;
    expect(notSet.fontStyle, FontStyle.italic);
    expect(notSet.color, Colors.grey[500]);

    // "Edit" is the brand colour, 16 / semibold, as in CRM.
    final edit = tester.widget<Text>(find.text('Edit')).style!;
    expect(edit.color, AppTheme.primaryColor);
    expect(edit.fontSize, 16);
    expect(edit.fontWeight, FontWeight.w600);
  });

  testWidgets('dark mode uses CRM\'s dark field fill', (tester) async {
    await _open(tester, brightness: Brightness.dark);

    expect(_fieldBoxes(darkFill), findsWidgets);
    expect(_fieldBoxes(lightFill), findsNothing);
    // Edit keeps the brand colour in dark mode too.
    expect(
      tester.widget<Text>(find.text('Edit')).style!.color,
      AppTheme.primaryColor,
    );
  });

  testWidgets('edit mode: Cancel and Save, plain-weight inputs, focus ring in '
      'the brand colour', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final cancel = tester.widget<Text>(find.text('Cancel')).style!;
    expect(cancel.fontSize, 16);
    expect(cancel.fontWeight, FontWeight.w500);
    expect(find.text('Save'), findsOneWidget);

    // An input's text is plain weight, and its empty hint italic grey.
    final inputs = find.byType(TextFormField);
    expect(inputs, findsWidgets);
    final field = tester.widget<TextField>(
      find.descendant(of: inputs.first, matching: find.byType(TextField)),
    );
    expect(field.style!.fontWeight, isNull);
    expect(field.style!.fontSize, 14);

    // Unfocused: 1px transparent border; focused: 1px brand colour.
    Border borderOf(Finder box) =>
        (tester.widget<Container>(box).decoration as BoxDecoration).border!
            as Border;
    final boxes = _fieldBoxes(lightFill);
    expect(borderOf(boxes.first).top.color, Colors.transparent);
    expect(borderOf(boxes.first).top.width, 1);

    await tester.tap(inputs.first);
    await tester.pumpAndSettle();
    expect(borderOf(boxes.first).top.color, AppTheme.primaryColor);
    expect(borderOf(boxes.first).top.width, 1);
  });
}
