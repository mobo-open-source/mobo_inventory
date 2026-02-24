import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/runtime_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
  // Track app settings open call
  bool openedSettings = false;

  setUp(() {
    openedSettings = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          // 7 = microphone, 4 = camera in permission_handler mapping (may vary across versions),
          // but we don't rely on the numeric id, we just branch by test-scoped variables.
          // We'll leave default to denied; tests will override handler between phases.
          return 1; // PermissionStatus.denied index
        case 'requestPermissions':
          // Return granted for all
          final Map<dynamic, dynamic> result = {};
          final List<dynamic> list = (call.arguments as List).toList();
          for (final id in list) {
            result[id] = 3; // PermissionStatus.granted index
          }
          return result;
        case 'openAppSettings':
          openedSettings = true;
          return true;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  testWidgets('requestMicrophonePermission requests when denied then returns true on grant', (tester) async {
    bool firstCheck = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          if (firstCheck) return 1; // denied
          return 3; // granted (after request)
        case 'requestPermissions':
          firstCheck = false;
          final Map<dynamic, dynamic> result = {};
          final List<dynamic> list = (call.arguments as List).toList();
          for (final id in list) {
            result[id] = 3; // granted
          }
          return result;
        case 'openAppSettings':
          openedSettings = true;
          return true;
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
        onPressed: () async {
          final ok = await RuntimePermissionService.requestMicrophonePermission(context);
          expect(ok, isTrue);
        },
        child: const Text('go'),
      );
    })));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  });

  testWidgets('requestCameraPermission requests when denied then returns true on grant', (tester) async {
    bool firstCheck = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          // First denied, then granted after request
          if (firstCheck) {
            return 1; // denied
          }
          return 3; // granted
        case 'requestPermissions':
          firstCheck = false;
          final Map<dynamic, dynamic> result = {};
          final List<dynamic> list = (call.arguments as List).toList();
          for (final id in list) {
            result[id] = 3; // granted
          }
          return result;
        case 'openAppSettings':
          openedSettings = true;
          return true;
      }
      return null;
    });

    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
        onPressed: () async {
          final ok = await RuntimePermissionService.requestCameraPermission(context);
          expect(ok, isTrue);
        },
        child: const Text('go'),
      );
    })));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  });

  testWidgets('permanentlyDenied shows dialog and Not Now keeps settings closed and returns false', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return 4; // PermissionStatus.permanentlyDenied
        case 'openAppSettings':
          openedSettings = true;
          return true;
      }
      return null;
    });

    bool? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
        onPressed: () async {
          result = await RuntimePermissionService.requestMicrophonePermission(context);
        },
        child: const Text('go'),
      );
    })));

    await tester.tap(find.text('go'));
    await tester.pump();

    // Dialog appears
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(openedSettings, isFalse);
  });

  testWidgets('permanentlyDenied and user taps Open Settings triggers openAppSettings', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (MethodCall call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return 4; // permanentlyDenied
        case 'openAppSettings':
          openedSettings = true;
          return true;
      }
      return null;
    });

    bool? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
        onPressed: () async {
          result = await RuntimePermissionService.requestCameraPermission(context);
        },
        child: const Text('go'),
      );
    })));

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(openedSettings, isTrue);
  });
}
