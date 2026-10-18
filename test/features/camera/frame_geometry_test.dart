import 'package:camera_overlay/features/camera/domain/frame_geometry.dart';
import 'package:camera_overlay/features/settings/domain/capture_ratio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const Rect _portrait = Rect.fromLTWH(0, 0, 400, 800);
const Rect _landscape = Rect.fromLTWH(0, 0, 800, 400);

void main() {
  group('sameRatio', () {
    test('accepts rounding noise but not a different shape', () {
      expect(FrameGeometry.sameRatio(4 / 3, 1.3334), isTrue);
      expect(FrameGeometry.sameRatio(4 / 3, 16 / 9), isFalse);
      expect(FrameGeometry.sameRatio(double.nan, 1), isFalse);
    });
  });

  group('availableArea', () {
    test('removes the safe-area insets in portrait and landscape', () {
      expect(
        FrameGeometry.availableArea(
          viewport: const Size(400, 800),
          safeInsets: const EdgeInsets.fromLTRB(0, 24, 0, 16),
        ),
        const Rect.fromLTWH(0, 24, 400, 760),
      );

      // A landscape notch: insets on the sides rather than the top.
      expect(
        FrameGeometry.availableArea(
          viewport: const Size(800, 400),
          safeInsets: const EdgeInsets.fromLTRB(48, 0, 48, 0),
        ),
        const Rect.fromLTWH(48, 0, 704, 400),
      );
    });

    test('falls back to the whole viewport when the insets do not fit', () {
      expect(
        FrameGeometry.availableArea(
          viewport: const Size(100, 100),
          safeInsets: const EdgeInsets.all(80),
        ),
        const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(
        FrameGeometry.availableArea(
          viewport: Size.zero,
          safeInsets: EdgeInsets.zero,
        ),
        Rect.zero,
      );
    });
  });

  group('coverRect', () {
    test('scales a 3:4 stream to cover a portrait viewport', () {
      final rect = FrameGeometry.coverRect(
        viewport: const Size(400, 800),
        sensor: 3 / 4,
      );
      // 0.75 -> 600x800, so 100px hangs off each side.
      expect(rect, const Rect.fromLTRB(-100, 0, 500, 800));
    });

    test('scales a 16:9 stream to cover a landscape viewport', () {
      final rect = FrameGeometry.coverRect(
        viewport: const Size(800, 400),
        sensor: 16 / 9,
      );
      // 1.7778 -> 800x450, so 25px hangs off top and bottom.
      expect(rect.width, closeTo(800, 1e-9));
      expect(rect.height, closeTo(450, 1e-9));
      expect(rect.left, closeTo(0, 1e-9));
      expect(rect.top, closeTo(-25, 1e-9));
    });

    test('falls back to the viewport for a degenerate stream', () {
      expect(
        FrameGeometry.coverRect(viewport: const Size(400, 800), sensor: 0),
        _portrait,
      );
      expect(
        FrameGeometry.coverRect(viewport: const Size(400, 800), sensor: 1 / 0),
        _portrait,
      );
    });
  });

  group('focusPoint', () {
    test('maps the viewport centre to the stream centre', () {
      final displayed = FrameGeometry.coverRect(
        viewport: const Size(400, 800),
        sensor: 3 / 4,
      );
      expect(
        FrameGeometry.focusPoint(
          point: const Offset(200, 400),
          displayedImage: displayed,
        ),
        const Offset(0.5, 0.5),
      );
    });

    test('accounts for the cropped overflow', () {
      // The viewport's left edge sits 1/6 into the stream.
      final displayed = FrameGeometry.coverRect(
        viewport: const Size(400, 800),
        sensor: 3 / 4,
      );
      final point = FrameGeometry.focusPoint(
        point: Offset.zero,
        displayedImage: displayed,
      )!;
      expect(point.dx, closeTo(1 / 6, 1e-9));
      expect(point.dy, 0);
    });

    test('rejects points outside the image and degenerate images', () {
      final displayed = FrameGeometry.coverRect(
        viewport: const Size(400, 800),
        sensor: 3 / 4,
      );
      expect(
        FrameGeometry.focusPoint(
          point: const Offset(600, 400),
          displayedImage: displayed,
        ),
        isNull,
      );
      expect(
        FrameGeometry.focusPoint(
          point: Offset.zero,
          displayedImage: Rect.zero,
        ),
        isNull,
      );
    });
  });

  group('frameRect', () {
    test('portrait: each ratio fits inside the available area', () {
      expect(
        FrameGeometry.frameRect(available: _portrait, aspect: 4 / 3),
        const Rect.fromLTRB(0, 250, 400, 550),
      );
      expect(
        FrameGeometry.frameRect(available: _portrait, aspect: 16 / 9),
        const Rect.fromLTRB(0, 287.5, 400, 512.5),
      );
      expect(
        FrameGeometry.frameRect(available: _portrait, aspect: 1),
        const Rect.fromLTRB(0, 200, 400, 600),
      );
    });

    test('landscape: the width becomes the limit', () {
      void expectRect(Rect actual, Rect expected) {
        expect(actual.left, closeTo(expected.left, 1e-9), reason: '$actual');
        expect(actual.top, closeTo(expected.top, 1e-9), reason: '$actual');
        expect(actual.right, closeTo(expected.right, 1e-9), reason: '$actual');
        expect(
          actual.bottom,
          closeTo(expected.bottom, 1e-9),
          reason: '$actual',
        );
      }

      expectRect(
        FrameGeometry.frameRect(available: _landscape, aspect: 4 / 3),
        const Rect.fromLTRB(133.33333333333334, 0, 666.6666666666666, 400),
      );
      expectRect(
        FrameGeometry.frameRect(available: _landscape, aspect: 16 / 9),
        const Rect.fromLTRB(44.44444444444444, 0, 755.5555555555555, 400),
      );
      expectRect(
        FrameGeometry.frameRect(available: _landscape, aspect: 1),
        const Rect.fromLTRB(200, 0, 600, 400),
      );
    });

    test('full screen is the available area itself', () {
      const available = Rect.fromLTWH(0, 24, 400, 760);
      expect(FrameGeometry.frameRect(available: available, aspect: null),
          available);
    });

    test('survives degenerate inputs', () {
      expect(
        FrameGeometry.frameRect(available: Rect.zero, aspect: 4 / 3),
        Rect.zero,
      );
      expect(
        FrameGeometry.frameRect(available: _portrait, aspect: 0),
        _portrait,
      );
      expect(
        FrameGeometry.frameRect(available: _portrait, aspect: double.nan),
        _portrait,
      );
    });
  });

  group('cropRectForFrame', () {
    test('a 1:1 crop of a 16:9 still is square and centred', () {
      final rect = FrameGeometry.cropRectForFrame(
        displayedImage: const Rect.fromLTWH(0, 0, 1920, 1080),
        frame: const Rect.fromLTRB(420, 0, 1500, 1080),
        source: const Size(1920, 1080),
        targetRatio: 1,
      );
      expect(rect, const Rect.fromLTWH(420, 0, 1080, 1080));
      expect(rect!.width / rect.height, closeTo(1, 1e-9));
    });

    test('a 4:3 crop of a 16:9 still keeps the full height', () {
      final rect = FrameGeometry.cropRectForFrame(
        displayedImage: const Rect.fromLTWH(0, 0, 1920, 1080),
        frame: const Rect.fromLTRB(240, 0, 1680, 1080),
        source: const Size(1920, 1080),
        targetRatio: 4 / 3,
      );
      expect(rect, const Rect.fromLTWH(240, 0, 1440, 1080));
      expect(rect!.width / rect.height, closeTo(4 / 3, 1e-9));
    });

    test('snaps odd dimensions to the exact ratio inside the source', () {
      final rect = FrameGeometry.cropRectForFrame(
        displayedImage: const Rect.fromLTWH(0, 0, 1, 1),
        frame: const Rect.fromLTWH(0, 0, 1, 1),
        source: const Size(4033, 3025),
        targetRatio: 1,
      )!;
      expect(rect.width, rect.height);
      expect(rect.width / rect.height, closeTo(1, 1e-9));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(4033));
      expect(rect.bottom, lessThanOrEqualTo(3025));
    });

    test('honours a frame that only covers part of the still', () {
      // A 2:1 window over the still's top-left, cropped to 1:1: a centred
      // square inside that window.
      final rect = FrameGeometry.cropRectForFrame(
        displayedImage: const Rect.fromLTWH(0, 0, 1000, 1000),
        frame: const Rect.fromLTWH(0, 0, 500, 250),
        source: const Size(1000, 1000),
        targetRatio: 1,
      )!;
      expect(rect, const Rect.fromLTWH(125, 0, 250, 250));
    });

    test('returns null when there is nothing to crop', () {
      const source = Size(100, 100);
      const displayed = Rect.fromLTWH(0, 0, 100, 100);
      expect(
        FrameGeometry.cropRectForFrame(
          displayedImage: Rect.zero,
          frame: displayed,
          source: source,
          targetRatio: 1,
        ),
        isNull,
      );
      expect(
        FrameGeometry.cropRectForFrame(
          displayedImage: displayed,
          frame: Rect.zero,
          source: source,
          targetRatio: 1,
        ),
        isNull,
      );
      expect(
        FrameGeometry.cropRectForFrame(
          displayedImage: displayed,
          frame: displayed,
          source: Size.zero,
          targetRatio: 1,
        ),
        isNull,
      );
      expect(
        FrameGeometry.cropRectForFrame(
          displayedImage: displayed,
          frame: displayed,
          source: source,
          targetRatio: 0,
        ),
        isNull,
      );
    });
  });

  group('CaptureRatio', () {
    test('cycles through every mode and wraps', () {
      final seen = <CaptureRatio>[];
      var ratio = CaptureRatio.classic43;
      for (var i = 0; i < CaptureRatio.values.length; i++) {
        seen.add(ratio);
        ratio = ratio.next;
      }
      expect(seen, CaptureRatio.values);
      expect(ratio, CaptureRatio.classic43);
    });

    test('resolves full screen from the available area', () {
      expect(CaptureRatio.classic43.resolve(_portrait), closeTo(4 / 3, 1e-9));
      expect(CaptureRatio.square11.resolve(_portrait), 1);
      expect(
        CaptureRatio.fullScreen.resolve(const Rect.fromLTWH(0, 0, 400, 800)),
        0.5,
      );
      // A landscape window resolves to the landscape shape, not 9:16.
      expect(
        CaptureRatio.fullScreen.resolve(_landscape),
        closeTo(2, 1e-9),
      );
    });

    test('has a spoken label for the accessible quick control', () {
      expect(CaptureRatio.fullScreen.spokenLabel, 'Full screen');
      expect(CaptureRatio.classic43.spokenLabel, '4:3');
    });
  });
}
