abstract interface class UseCase<TInput, TOutput> {
  Future<TOutput> call(TInput input);
}

final class NoInput {
  const NoInput();
}
