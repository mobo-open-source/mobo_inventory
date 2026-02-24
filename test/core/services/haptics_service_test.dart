import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/haptics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          log.add(methodCall);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('HapticsService', () {
    test('selection triggers HapticFeedback.selectionClick', () async {
      await HapticsService.selection();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.selectionClick');
    });

    test('light triggers HapticFeedback.lightImpact', () async {
      await HapticsService.light();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('medium triggers HapticFeedback.mediumImpact', () async {
      await HapticsService.medium();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('heavy triggers HapticFeedback.heavyImpact', () async {
      await HapticsService.heavy();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.heavyImpact');
    });

    test('warning triggers HapticFeedback.lightImpact', () async {
      await HapticsService.warning();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('error triggers HapticFeedback.heavyImpact', () async {
      await HapticsService.error();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.heavyImpact');
    });

    test('success triggers sequence', () async {
      await HapticsService.success();

      // Should call medium, then selection
      expect(log, hasLength(2));
      expect(log[0].method, 'HapticFeedback.vibrate');
      expect(log[0].arguments, 'HapticFeedbackType.mediumImpact');

      expect(log[1].method, 'HapticFeedback.vibrate');
      expect(log[1].arguments, 'HapticFeedbackType.selectionClick');
    });
  });
}
