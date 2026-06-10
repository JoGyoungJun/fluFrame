import 'package:fulframe_core/fulframe_core.dart';
import 'package:test/test.dart';

void main() {
  test('Result.success creates success result', () {
    const result = Result<String, int>.success(7);

    expect(result.isSuccess, isTrue);
    expect(result.isFailure, isFalse);
    expect(result.valueOrNull, 7);
    expect(result.failureOrNull, isNull);
  });

  test('Result.failure creates failure result', () {
    const result = Result<String, int>.failure('missing');

    expect(result.isFailure, isTrue);
    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull, 'missing');
    expect(result.valueOrNull, isNull);
  });

  test('Success folds to success branch', () {
    const result = Success<String, int>(42);

    final value = result.fold((failure) => -1, (success) => success);

    expect(value, 42);
  });

  test('Failure folds to failure branch', () {
    const result = Failure<String, int>('missing');

    final value = result.fold((failure) => failure, (success) => '$success');

    expect(value, 'missing');
  });

  test('map transforms success value', () {
    const result = Result<String, int>.success(21);

    final mapped = result.map((value) => value * 2);

    expect(mapped.valueOrNull, 42);
  });

  test('mapFailure transforms failure value', () {
    const result = Result<String, int>.failure('missing');

    final mapped = result.mapFailure((failure) => 'error:$failure');

    expect(mapped.failureOrNull, 'error:missing');
  });
}
