import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme constants', () {
    test('primaryColor matches expected hex', () {
      expect(AppTheme.primaryColor, const Color(0xFFC03355));
    });

    test('secondaryColor matches expected hex', () {
      expect(AppTheme.secondaryColor, const Color(0xFFffffff));
    });
  });
}
