/// Which lens the camera screen opens with. The user can still switch lenses
/// while shooting; this only decides the starting one.
enum PreferredCamera {
  rear('Rear'),
  front('Front');

  const PreferredCamera(this.label);

  final String label;
}
