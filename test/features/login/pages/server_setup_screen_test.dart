import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_inv_app/features/login/pages/server_setup_screen.dart';
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
    when(() => mockLoginProvider.previousUrls).thenReturn([]);
    when(() => mockLoginProvider.isLoadingDatabases).thenReturn(false);
    when(() => mockLoginProvider.urlCheck).thenReturn(false);
    when(() => mockLoginProvider.dropdownItems).thenReturn([]);
    when(() => mockLoginProvider.errorMessage).thenReturn(null);
    when(() => mockLoginProvider.disableFields).thenReturn(false);
    when(() => mockLoginProvider.selectedProtocol).thenReturn('https://');
    when(() => mockLoginProvider.formKey).thenReturn(GlobalKey<FormState>());
    when(() => mockLoginProvider.getFullUrl()).thenReturn('https://test.com');
  });

  Widget createWidgetUnderTest({MockGoRouter? router}) {
    final mockRouter = router ?? MockGoRouter();
    return MaterialApp(
      home: InheritedGoRouter(
        goRouter: mockRouter,
        child: ServerSetupScreen(provider: mockLoginProvider),
      ),
    );
  }

  testWidgets('ServerSetupScreen shows initial UI components', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Configure your server connection'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Next button is enabled when URL and DB are valid', (
    WidgetTester tester,
  ) async {
    when(() => mockLoginProvider.urlCheck).thenReturn(true);
    when(() => mockLoginProvider.database).thenReturn('test_db');
    when(() => mockLoginProvider.dropdownItems).thenReturn(['test_db']);
    mockLoginProvider.urlController.text = 'test.com';

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final nextButton = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byType(ServerSetupScreen),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('Shows error message when provider has error', (
    WidgetTester tester,
  ) async {
    when(() => mockLoginProvider.errorMessage).thenReturn('Connection failed');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Connection failed'), findsOneWidget);
  });

  testWidgets('Next button navigates to CredentialsScreen', (
    WidgetTester tester,
  ) async {
    final mockRouter = MockGoRouter();
    when(
      () => mockRouter.pushNamed(any(), extra: any(named: 'extra')),
    ).thenAnswer((_) async => null);

    when(() => mockLoginProvider.urlCheck).thenReturn(true);
    when(() => mockLoginProvider.database).thenReturn('test_db');
    when(() => mockLoginProvider.dropdownItems).thenReturn(['test_db']);
    mockLoginProvider.urlController.text = 'test.com';

    await tester.pumpWidget(createWidgetUnderTest(router: mockRouter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    verify(
      () => mockRouter.pushNamed(any(), extra: any(named: 'extra')),
    ).called(1);
  });
}
