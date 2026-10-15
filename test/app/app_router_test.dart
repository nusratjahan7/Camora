import 'package:camera_overlay/app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router configuration is valid', () {
    final container = ProviderContainer.test();

    // Throws in debug when go_router's configuration asserts fail.
    expect(() => container.read(appRouterProvider), returnsNormally);
  });
}
