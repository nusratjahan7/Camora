import 'package:camera_overlay/features/overlay/domain/overlay_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverlaySettings', () {
    test('defaults are sensible', () {
      const settings = OverlaySettings.defaults;

      expect(settings.opacity, greaterThan(0));
      expect(settings.opacity, lessThanOrEqualTo(1));
      expect(settings.scale, 1.0);
      expect(settings.offset, Offset.zero);
      expect(settings.rotation, 0.0);
    });

    test('copyWith changes only the provided field', () {
      const settings = OverlaySettings.defaults;
      final updated = settings.copyWith(opacity: 0.75);

      expect(updated.opacity, 0.75);
      expect(updated.scale, settings.scale);
      expect(updated, isNot(equals(settings)));
      expect(updated, equals(const OverlaySettings(opacity: 0.75)));
    });
  });
}
