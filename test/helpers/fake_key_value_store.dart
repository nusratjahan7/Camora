import 'package:camera_overlay/core/storage/key_value_store.dart';

/// In-memory [KeyValueStore], so storage tests never touch the platform.
class FakeKeyValueStore implements KeyValueStore {
  final Map<String, Object> _values = <String, Object>{};

  /// Every key currently stored, for assertions.
  Iterable<String> get keys => _values.keys;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<void> setDouble(String key, double value) async {
    _values[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
