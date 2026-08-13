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
  /// Creates a [ServerException] with the offending [statusCode] and the
  /// decoded response [data], when either is available.
  const ServerException(super.message, {this.statusCode, this.data});

  /// HTTP status code returned by the server, when available.
  final int? statusCode;

  /// Decoded response body the server sent with the failure, if any.
  ///
  /// Real backends answer errors with their own envelope — an error code,
  /// a field-level message, a trace id. Dropping it left the app with the
  /// generic [message] and no way to tell "email already registered" from
  /// "rate limited", because the `DioException` that carried the body is
  /// deliberately not visible above the data layer. The shape is
  /// backend-specific: check the type before reading it.
  final Object? data;
}

/// The request was cancelled before it finished (see dio's `CancelToken`).
///
/// Not a failure of the network or the server: the app itself asked for
/// it — a screen was disposed, a search query was retyped. Callers
/// normally ignore it rather than showing an error.
final class RequestCancelledException extends ApiException {
  /// Creates a [RequestCancelledException].
  const RequestCancelledException(super.message);
}

/// The server's TLS certificate was rejected.
///
/// Distinct from [NetworkException]: the host answered, its identity did
/// not check out — an expired certificate, an intercepting proxy, or a
/// failing pinning rule. Retrying the same request will not help.
final class CertificateException extends ApiException {
  /// Creates a [CertificateException].
  const CertificateException(super.message);
}

/// Anything that is neither a connectivity nor a server failure.
final class UnknownApiException extends ApiException {
  /// Creates an [UnknownApiException].
  const UnknownApiException(super.message);
}
