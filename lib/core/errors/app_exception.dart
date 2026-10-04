sealed class AppException implements Exception {
  const AppException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

final class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.code});
}

