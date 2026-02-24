import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_inv_app/features/login/pages/credentials_screen.dart';
import 'package:mobo_inv_app/features/login/providers/login_provider.dart';
import 'package:mobo_inv_app/core/services/odoo_session_manager.dart';
import 'package:mobo_inv_app/core/services/session_service.dart';
import 'package:mobo_inv_app/core/services/secure_storage_service.dart';
import 'package:mobo_inv_app/core/services/connectivity_service.dart';
import 'package:go_router/go_router.dart';

class MockLoginProvider extends Mock implements LoginProvider {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockGoRouter extends Mock implements GoRouter {}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockLoginProvider mockLoginProvider;
  late MockSecureStorageService mockSecureStorage;
  late MockConnectivityService mockConnectivity;

  setUpAll(() {
    registerFallbackValue(FakeBuildContext());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockLoginProvider = MockLoginProvider();
    mockSecureStorage = MockSecureStorageService();
    mockConnectivity = MockConnectivityService();

    SecureStorageService.setInstanceForTesting(mockSecureStorage);
    ConnectivityService.setInstanceForTesting(mockConnectivity);

    OdooSessionManager.resetForTesting();
    SessionService.instance.resetForTesting();

    // Default mocks for LoginProvider
    when(
      () => mockLoginProvider.urlController,
    ).thenReturn(TextEditingController());
    when(
      () => mockLoginProvider.emailController,
    ).thenReturn(TextEditingController());
    when(
      () => mockLoginProvider.passwordController,
    ).thenReturn(TextEditingController());
    when(() => mockLoginProvider.isLoading).thenReturn(false);
    when(() => mockLoginProvider.isLoadingDatabases).thenReturn(false);
    when(() => mockLoginProvider.errorMessage).thenReturn(null);
    when(() => mockLoginProvider.disableFields).thenReturn(false);
    when(() => mockLoginProvider.obscurePassword).thenReturn(true);
    when(() => mockLoginProvider.formKey).thenReturn(GlobalKey<FormState>());
    when(() => mockLoginProvider.setDatabase(any())).thenReturn(null);
    when(() => mockLoginProvider.dispose()).thenReturn(null);
  });

  Widget createWidgetUnderTest({MockGoRouter? router}) {
    final mockRouter = router ?? MockGoRouter();
    return MaterialApp(
      home: InheritedGoRouter(
        goRouter: mockRouter,
        child: CredentialsScreen(
          url: 'http://test.com',
          database: 'test_db',
          provider: mockLoginProvider,
        ),
      ),
    );
  }

  testWidgets('CredentialsScreen shows initial UI components', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsNWidgets(2));
    expect(find.text('Enter your credentials to continue'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email and Password
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('Toggling password visibility calls provider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final visibilityIcon = find.byIcon(Icons.visibility_off_outlined);
    expect(visibilityIcon, findsOneWidget);

    await tester.tap(visibilityIcon);
    verify(() => mockLoginProvider.togglePasswordVisibility()).called(1);
  });

  testWidgets('Submit button calls login on provider and navigates', (
    WidgetTester tester,
  ) async {
    final mockRouter = MockGoRouter();
    when(() => mockRouter.goNamed(any())).thenReturn(null);
    when(() => mockLoginProvider.login(any())).thenAnswer((_) async => true);

    // Mock form validation
    final formKey = GlobalKey<FormState>();
    when(() => mockLoginProvider.formKey).thenReturn(formKey);

    await tester.pumpWidget(createWidgetUnderTest(router: mockRouter));
    await tester.pumpAndSettle();

    mockLoginProvider.emailController.text = 'test@test.com';
    mockLoginProvider.passwordController.text = 'password';

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump(const Duration(milliseconds: 200));

    verify(() => mockLoginProvider.login(any())).called(1);
    verify(() => mockRouter.goNamed(any())).called(1);
  });
}
