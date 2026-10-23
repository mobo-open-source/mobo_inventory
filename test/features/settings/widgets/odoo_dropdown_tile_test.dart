import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/theme/app_theme.dart';
import 'package:mobo_inv_app/features/settings/widgets/odoo_dropdown_tile.dart';

Widget _tile(Brightness brightness) {
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      primaryColor: AppTheme.primaryColor,
    ),
    home: Scaffold(
      body: OdooDropdownTile(
        title: 'Language',
        subtitle: 'Select your preferred language',
        icon: Icons.translate,
        selectedValue: 'en_US',
        options: const [
          {'code': 'en_US', 'name': 'English (US)'},
          {'code': 'fr_FR', 'name': 'French'},
        ],
        isLoading: false,
        onChanged: (_) {},
        displayKey: 'name',
        valueKey: 'code',
      ),
    ),
  );
}

void main() {
  testWidgets('light: grey chevron and black value, none of the brand colour', (
    tester,
  ) async {
    await tester.pumpWidget(_tile(Brightness.light));

    final chevron = tester.widget<Icon>(
      find.byIcon(Icons.keyboard_arrow_down_sharp),
    );
    expect(chevron.color, Colors.grey[600]);

    final value = tester.widget<Text>(find.text('English (US)')).style!;
    expect(value.color, Colors.black87);
    expect(value.fontWeight, isNull);
    expect(value.color, isNot(AppTheme.primaryColor));
  });

  testWidgets('dark: grey chevron and white value', (tester) async {
    await tester.pumpWidget(_tile(Brightness.dark));

    final chevron = tester.widget<Icon>(
      find.byIcon(Icons.keyboard_arrow_down_sharp),
    );
    expect(chevron.color, Colors.grey[400]);
    expect(
      tester.widget<Text>(find.text('English (US)')).style!.color,
      Colors.white,
    );
  });
}
