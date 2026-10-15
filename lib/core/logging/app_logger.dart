import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogLevel { debug, info, warning, error }

final class AppLogger {
  const AppLogger([this.tag = 'Veylora']);

  final String tag;

  void debug(String message) => _log(LogLevel.debug, message);

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.warning, message, error, stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (level == LogLevel.debug && kReleaseMode) return;
    final buffer = StringBuffer('[$tag] ${level.name.toUpperCase()}: $message');
    if (error != null) buffer.write(' | $error');
    if (stackTrace != null && !kReleaseMode) buffer.write('\n$stackTrace');
    debugPrint(buffer.toString());
  }
}

final appLoggerProvider = Provider<AppLogger>((ref) => const AppLogger());
