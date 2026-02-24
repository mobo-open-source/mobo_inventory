import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_inv_app/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('initially loads preference and exposes themeMode', () async {
    SharedPreferences.setMockInitialValues({'dark_mode': true});

    final provider = ThemeProvider();
    // Wait for constructor-triggered _loadTheme future to complete
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(provider.isDarkMode, isTrue);
    expect(provider.themeMode.toString(), contains('dark'));
  });

  test('toggleTheme flips state and persists', () async {
    final provider = ThemeProvider();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final initial = provider.isDarkMode;
    await provider.toggleTheme();
    expect(provider.isDarkMode, !initial);

    // Read back from prefs
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), provider.isDarkMode);
  });

  test('setDarkMode sets exact state and persists', () async {
    final provider = ThemeProvider();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await provider.setDarkMode(true);
    expect(provider.isDarkMode, isTrue);
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), isTrue);

    await provider.setDarkMode(false);
    expect(provider.isDarkMode, isFalse);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dark_mode'), isFalse);
  });
}
