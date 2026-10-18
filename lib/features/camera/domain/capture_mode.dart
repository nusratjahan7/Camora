/// What the shutter does: take a still, or film a clip.
///
/// The mode decides whether the camera is opened with audio, so switching it
/// reopens the session — unlike the capture ratio, which is pure layout.
enum CaptureMode {
  photo('Photo'),
  video('Video');

  const CaptureMode(this.label);

  final String label;

  bool get isVideo => this == CaptureMode.video;

  CaptureMode get other => isVideo ? photo : video;
}
