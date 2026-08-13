import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal structured logger built on `dart:developer`.
///
/// Swap the implementation for a package such as `logger` or `talker`
/// without touching call sites.
class AppLogger {
  /// Creates a logger tagged with [name].
  const AppLogger(this.name);

  /// Tag included with every log record.
  final String name;

  /// Logs a fine-grained debugging message.
  void debug(String message) => _log(message, level: 500);

  /// Logs an informational message.
  void info(String message) => _log(message, level: 800);

  /// Logs a potential problem.
  void warning(String message) => _log(message, level: 900);

  /// Logs a failure with an optional [error] and [stackTrace].
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(message, level: 1000, error: error, stackTrace: stackTrace);

  void _log(
    String message, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Provider exposing the app-wide root [AppLogger].
final appLoggerProvider = Provider<AppLogger>(
  (ref) => const AppLogger('todo_app'),
);
