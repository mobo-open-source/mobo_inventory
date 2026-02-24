import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/shared/widgets/connection_status_banner.dart';

void main() {
  test('ConnectionStatusBanner preferredSize is 22', () {
    const banner = ConnectionStatusBanner();
    expect(banner.preferredSize.height, 22);
  });
}
