/// Failure raised by auth repository implementations when sign-in is
/// rejected (bad credentials, disabled account, network refusal...).
///
/// Presentation code catches this type — never a backend SDK's own
/// exception — so swapping backends cannot ripple into the UI.
final class AuthException implements Exception {
  /// Creates an [AuthException] with a human-readable [message].
  const AuthException(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
