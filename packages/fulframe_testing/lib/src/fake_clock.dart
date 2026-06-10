import 'package:fulframe_core/fulframe_core.dart';

final class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  set value(DateTime value) {
    _now = value;
  }
}
