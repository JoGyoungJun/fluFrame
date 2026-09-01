import 'package:dio/dio.dart';
import 'package:fluframe_app/core/network/api_client.dart';
import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

DioException _dioException(
  DioExceptionType type, {
  Response<dynamic>? response,
}) => DioException(
  requestOptions: RequestOptions(path: '/posts'),
  type: type,
  response: response,
);

void main() {
  group('dioProvider', () {
    test('sets every timeout mapDioException claims to handle', () {
      // Regression: sendTimeout was never configured, so dio could not
      // raise DioExceptionType.sendTimeout and the arm of the mapper
      // below that answers it was unreachable. A request whose body
      // stalled mid-upload waited on the OS default instead of failing in
      // ten seconds like a connect or receive stall does.
      final options = createContainer().read(dioProvider).options;

      expect(options.connectTimeout, const Duration(seconds: 10));
      expect(options.sendTimeout, const Duration(seconds: 10));
      expect(options.receiveTimeout, const Duration(seconds: 10));
    });
  });

  group('mapDioException', () {
    test('carries the server error body onto ServerException', () {
      // Regression: only the status code survived, so an app could never
      // read the backend's own error code or message — the DioException
      // that held them never reaches the presentation layer.
      final exception = mapDioException(
        _dioException(
          DioExceptionType.badResponse,
          response: Response<Map<String, Object?>>(
            requestOptions: RequestOptions(path: '/posts'),
            statusCode: 422,
            data: const {'code': 'email_taken', 'message': 'Already used.'},
          ),
        ),
      );

      expect(
        exception,
        isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having(
              (e) => e.data,
              'data',
              const {'code': 'email_taken', 'message': 'Already used.'},
            ),
      );
    });

    test('maps a cancelled request to RequestCancelledException', () {
      // Regression: cancellation is the app's own doing, but it arrived
      // as UnknownApiException — indistinguishable from a real bug.
      expect(
        mapDioException(_dioException(DioExceptionType.cancel)),
        isA<RequestCancelledException>(),
      );
    });

    test('maps a rejected certificate to CertificateException', () {
      // Regression: a trust failure reported as "unexpected error" sends
      // readers of a crash report hunting for a bug that is not there.
      expect(
        mapDioException(_dioException(DioExceptionType.badCertificate)),
        isA<CertificateException>(),
      );
    });

    test('maps timeouts and connection errors to NetworkException', () {
      for (final type in const [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(mapDioException(_dioException(type)), isA<NetworkException>());
      }
    });

    test('maps anything else to UnknownApiException', () {
      expect(
        mapDioException(_dioException(DioExceptionType.unknown)),
        isA<UnknownApiException>(),
      );
    });
  });
}
