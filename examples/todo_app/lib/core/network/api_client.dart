import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/config/app_config.dart';
import 'package:todo_app/core/logging/app_logger.dart';
import 'package:todo_app/core/network/api_exception.dart';

/// Provider for the configured [Dio] HTTP client.
///
/// The base URL comes from [apiBaseUrl] (see `env/*.json`); requests and
/// failures are logged through [appLoggerProvider].
final dioProvider = Provider<Dio>((ref) {
  final logger = ref.watch(appLoggerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        logger.debug('--> ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        logger.debug(
          '<-- ${response.statusCode} ${response.requestOptions.uri}',
        );
        handler.next(response);
      },
      onError: (exception, handler) {
        logger.warning(
          '<-- ${exception.type.name} ${exception.requestOptions.uri}',
        );
        handler.next(exception);
      },
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Maps a transport-level [DioException] into a typed [ApiException].
ApiException mapDioException(DioException exception) {
  return switch (exception.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => const NetworkException(
      'Could not reach the server.',
    ),
    DioExceptionType.badResponse => ServerException(
      'The server responded with an error.',
      statusCode: exception.response?.statusCode,
      // The backend's own error envelope. Without it the app can only
      // ever show the sentence above, however precise the API was, and
      // `DioException` never reaches the presentation layer to be asked.
      data: exception.response?.data,
    ),
    // Cancellation is the app's own doing and a rejected certificate is a
    // trust failure — neither is "unexpected". Reporting both as
    // UnknownApiException sent readers of a crash report hunting for a
    // bug that was not there.
    DioExceptionType.cancel => const RequestCancelledException(
      'The request was cancelled.',
    ),
    DioExceptionType.badCertificate => const CertificateException(
      'The server certificate could not be verified.',
    ),
    _ => UnknownApiException(exception.message ?? 'Unexpected error.'),
  };
}
