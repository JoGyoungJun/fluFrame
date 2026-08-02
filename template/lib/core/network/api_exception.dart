/// Failures raised by the data layer when talking to the REST API.
///
/// Repositories catch transport-level errors (e.g. `DioException`) and
/// rethrow them as one of these typed exceptions so the presentation layer
/// never depends on the HTTP client.
sealed class ApiException implements Exception {
  /// Creates an [ApiException] with a human-readable [message].
  const ApiException(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// The device could not reach the server (timeout, DNS, no connectivity).
final class NetworkException extends ApiException {
  /// Creates a [NetworkException].
  const NetworkException(super.message);
}

/// The server answered with a non-2xx status code.
final class ServerException extends ApiException {
  /// Creates a [ServerException] with the offending [statusCode], if any.
  const ServerException(super.message, {this.statusCode});

  /// HTTP status code returned by the server, when available.
  final int? statusCode;
}

/// Anything that is neither a connectivity nor a server failure.
final class UnknownApiException extends ApiException {
  /// Creates an [UnknownApiException].
  const UnknownApiException(super.message);
}
