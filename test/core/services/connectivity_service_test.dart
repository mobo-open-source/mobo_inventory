import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    test('ensureServerReachable throws for invalid host', () async {
      expect(
        () => ConnectivityService.instance.ensureServerReachable('http://definitely.invalid.host.example'),
        throwsA(isA<ServerUnreachableException>()),
      );
    });

    test('hasInternetAccess returns false for invalid domain quickly', () async {
      final result = await ConnectivityService.instance.hasInternetAccess(host: 'definitely.invalid.host.example');
      expect(result, isFalse);
    });
  });
}
