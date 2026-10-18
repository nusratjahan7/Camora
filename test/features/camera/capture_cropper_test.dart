import 'package:camera_overlay/features/camera/data/capture_cropper.dart';
import 'package:camera_overlay/features/camera/domain/capture_crop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 90, 140));
  return img.encodeJpg(image, quality: 90);
}

void main() {
  test('crops a 16:9 still to the frame the preview showed', () async {
    // A 1:1 frame inside a 16:9 stream: the largest centred square.
    final result = await cropToFrame(
      _jpeg(160, 90),
      const CaptureCrop(
        frame: Rect.fromLTWH(0.21875, 0, 0.5625, 1),
        aspectRatio: 1,
      ),
    );

    expect(result, isNotNull);
    final decoded = img.decodeJpg(result!);
    expect(decoded, isNotNull);
    expect(decoded!.width, 90);
    expect(decoded.height, 90);
    expect(decoded.width / decoded.height, closeTo(1, 1e-9));
  });

  test('crops a 4:3 still to 1:1 without leaving the source', () async {
    final result = await cropToFrame(
      _jpeg(4032, 3024),
      const CaptureCrop(frame: Rect.fromLTWH(0, 0, 1, 1), aspectRatio: 1),
    );

    expect(result, isNotNull);
    final decoded = img.decodeJpg(result!)!;
    expect(decoded.width, decoded.height);
    expect(decoded.width, lessThanOrEqualTo(4032));
    expect(decoded.height, lessThanOrEqualTo(3024));
  });

  test('honours a frame that covers only part of the still', () async {
    final result = await cropToFrame(
      _jpeg(200, 100),
      const CaptureCrop(
        frame: Rect.fromLTWH(0, 0, 0.5, 0.5),
        aspectRatio: 1,
      ),
    );

    expect(result, isNotNull);
    final decoded = img.decodeJpg(result!)!;
    expect(decoded.width, 50);
    expect(decoded.height, 50);
  });

  test('keeps the original bytes when the still already matches', () async {
    // 16:9 output from a 16:9 still: the camera's own bytes are kept, so the
    // shutter costs no re-encode at all.
    final result = await cropToFrame(
      _jpeg(1920, 1080),
      const CaptureCrop(
        frame: Rect.fromLTWH(0, 0, 1, 1),
        aspectRatio: 16 / 9,
      ),
    );

    expect(result, isNull);
  });

  test('returns null for bytes that cannot be decoded', () async {
    final result = await cropToFrame(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      const CaptureCrop(frame: Rect.fromLTWH(0, 0, 1, 1), aspectRatio: 1),
    );

    expect(result, isNull);
  });
}
