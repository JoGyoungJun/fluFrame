import 'package:fulframe_core/fulframe_core.dart';
import 'package:test/test.dart';

void main() {
  test('FixedClock returns configured time', () {
    final now = DateTime.utc(2026, 6, 9);
    final clock = FixedClock(now);

    expect(clock.now(), now);
  });
}
