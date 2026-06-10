import 'package:fulframe_core/fulframe_core.dart';
import 'package:test/test.dart';

final class DoubleValueUseCase implements UseCase<int, int> {
  @override
  Future<int> call(int input) async => input * 2;
}

void main() {
  test('UseCase provides async application contract', () async {
    final useCase = DoubleValueUseCase();

    await expectLater(useCase(21), completion(42));
  });

  test('NoInput can represent no-argument use cases', () {
    const input = NoInput();

    expect(input, isA<NoInput>());
  });
}
