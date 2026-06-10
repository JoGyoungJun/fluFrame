sealed class Result<TFailure, TValue> {
  const Result();

  const factory Result.success(TValue value) = Success<TFailure, TValue>;

  const factory Result.failure(TFailure failure) = Failure<TFailure, TValue>;

  bool get isSuccess => this is Success<TFailure, TValue>;

  bool get isFailure => this is Failure<TFailure, TValue>;

  TFailure? get failureOrNull {
    return switch (this) {
      Failure(:final failure) => failure,
      Success() => null,
    };
  }

  TValue? get valueOrNull {
    return switch (this) {
      Failure() => null,
      Success(:final value) => value,
    };
  }

  T fold<T>(
    T Function(TFailure failure) onFailure,
    T Function(TValue value) onSuccess,
  ) {
    return switch (this) {
      Failure(:final failure) => onFailure(failure),
      Success(:final value) => onSuccess(value),
    };
  }

  Result<TFailure, TNext> map<TNext>(TNext Function(TValue value) transform) {
    return switch (this) {
      Failure(:final failure) => Failure<TFailure, TNext>(failure),
      Success(:final value) => Success<TFailure, TNext>(transform(value)),
    };
  }

  Result<TNextFailure, TValue> mapFailure<TNextFailure>(
    TNextFailure Function(TFailure failure) transform,
  ) {
    return switch (this) {
      Failure(:final failure) => Failure<TNextFailure, TValue>(
          transform(failure),
        ),
      Success(:final value) => Success<TNextFailure, TValue>(value),
    };
  }
}

final class Success<TFailure, TValue> extends Result<TFailure, TValue> {
  const Success(this.value);

  final TValue value;
}

final class Failure<TFailure, TValue> extends Result<TFailure, TValue> {
  const Failure(this.failure);

  final TFailure failure;
}
