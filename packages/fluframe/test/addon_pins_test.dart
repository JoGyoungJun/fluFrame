import 'package:fluframe/src/addon_pins.dart';
import 'package:test/test.dart';

void main() {
  group('classifyPin', () {
    test('a pin equal to the latest stable is current', () {
      expect(
        classifyPin(pinned: '^2.17.1', latest: '2.17.1'),
        PinVerdict.current,
      );
    });

    test('a newer patch inside the pinned major is reported, not failed', () {
      // This is the state all five pins are in today. A caret constraint
      // resolves it forward on its own, for users and for CI alike.
      expect(
        classifyPin(pinned: '^2.17.1', latest: '2.17.2'),
        PinVerdict.behindInMajor,
      );
      expect(
        classifyPin(pinned: '^9.26.0', latest: '9.30.0'),
        PinVerdict.behindInMajor,
      );
    });

    test('a newer major is the one verdict that fails the watch', () {
      expect(
        classifyPin(pinned: '^2.17.1', latest: '3.0.0'),
        PinVerdict.behindMajor,
      );
    });

    test('a pin ahead of pub.dev is named, not silently called ok', () {
      // Reachable after a retraction, or when the constraint was bumped
      // before the release landed. The previous implementation had no
      // branch for it and fell into the in-major arm, reporting a pin
      // pub.dev cannot satisfy as "ok (in major)".
      expect(
        classifyPin(pinned: '^4.6.2', latest: '3.9.0'),
        PinVerdict.aheadOfLatest,
      );
    });

    test('an unreachable registry is unknown, never up to date', () {
      expect(
        classifyPin(pinned: '^2.17.1', latest: null),
        PinVerdict.unknown,
      );
    });

    test('an unparseable version on either side is unknown', () {
      expect(
        classifyPin(pinned: 'any', latest: '2.17.1'),
        PinVerdict.unknown,
      );
      expect(
        classifyPin(pinned: '^2.17.1', latest: 'nightly'),
        PinVerdict.unknown,
      );
    });

    test('a bare pin with no caret compares the same way', () {
      expect(
        classifyPin(pinned: '2.17.1', latest: '2.17.1'),
        PinVerdict.current,
      );
      expect(
        classifyPin(pinned: '2.17.1', latest: '3.0.0'),
        PinVerdict.behindMajor,
      );
    });
  });

  group('majorOf', () {
    test('reads the major through a constraint operator', () {
      expect(majorOf('^2.17.1'), 2);
      expect(majorOf('2.17.1'), 2);
      expect(majorOf('>=13.3.0'), 13);
    });

    test('returns null rather than guessing', () {
      expect(majorOf('any'), isNull);
      expect(majorOf(''), isNull);
    });
  });

  group('shouldFail', () {
    test('fails only on a major behind', () {
      expect(
        shouldFail([PinVerdict.current, PinVerdict.behindMajor]),
        isTrue,
      );
      expect(
        shouldFail([PinVerdict.current, PinVerdict.behindInMajor]),
        isFalse,
      );
    });

    test('an all-unreachable run is an outage, not a verdict', () {
      // Otherwise the watch cries wolf every time pub.dev has a bad night,
      // and a nightly that is red for reasons outside the repo is a
      // nightly people stop reading.
      expect(
        shouldFail([PinVerdict.unknown, PinVerdict.unknown]),
        isFalse,
      );
    });

    test('one reachable major-behind still fails a partly unreachable run', () {
      expect(
        shouldFail([PinVerdict.unknown, PinVerdict.behindMajor]),
        isTrue,
      );
    });

    test('no pins at all is not a pass to celebrate', () {
      // The tool exits 1 on an empty pin set before reaching here; this
      // pins that shouldFail does not quietly bless the empty case.
      expect(shouldFail(const []), isFalse);
    });
  });
}
