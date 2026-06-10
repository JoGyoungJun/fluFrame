import 'package:fulframe_core/fulframe_core.dart';
import 'package:test/test.dart';

void main() {
  test('MemoryLogger records log entries', () {
    final logger = MemoryLogger();

    logger.info('started');
    logger.error('failed', error: 'boom');

    expect(logger.entries, hasLength(2));
    expect(logger.entries.first.level, LogLevel.info);
    expect(logger.entries.first.message, 'started');
    expect(logger.entries.last.level, LogLevel.error);
    expect(logger.entries.last.error, 'boom');
  });
}
