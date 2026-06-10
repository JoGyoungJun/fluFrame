abstract interface class AppLogger {
  void debug(String message, {Object? error, StackTrace? stackTrace});

  void info(String message, {Object? error, StackTrace? stackTrace});

  void warning(String message, {Object? error, StackTrace? stackTrace});

  void error(String message, {Object? error, StackTrace? stackTrace});
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

final class LogEntry {
  const LogEntry({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

final class NoopLogger implements AppLogger {
  const NoopLogger();

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {}
}

final class MemoryLogger implements AppLogger {
  final List<LogEntry> entries = <LogEntry>[];

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    entries.add(
      LogEntry(
        level: LogLevel.debug,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    entries.add(
      LogEntry(
        level: LogLevel.error,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    entries.add(
      LogEntry(
        level: LogLevel.info,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    entries.add(
      LogEntry(
        level: LogLevel.warning,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
