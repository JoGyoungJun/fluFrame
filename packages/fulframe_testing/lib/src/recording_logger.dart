import 'package:fulframe_core/fulframe_core.dart';

final class RecordedLog {
  const RecordedLog(this.level, this.message, this.error, this.stackTrace);

  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

final class RecordingLogger implements AppLogger {
  final List<RecordedLog> logs = <RecordedLog>[];

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    logs.add(RecordedLog(LogLevel.debug, message, error, stackTrace));
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    logs.add(RecordedLog(LogLevel.error, message, error, stackTrace));
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    logs.add(RecordedLog(LogLevel.info, message, error, stackTrace));
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    logs.add(RecordedLog(LogLevel.warning, message, error, stackTrace));
  }
}
