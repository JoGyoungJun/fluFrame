import 'package:dio/dio.dart';
import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/features/posts/data/posts_repository.dart';
import 'package:fluframe_app/features/posts/domain/post.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  group('PostsRepository', () {
    late _MockDio dio;
    late PostsRepository repository;

    setUp(() {
      dio = _MockDio();
      repository = PostsRepository(dio);
    });

    /// Stubs `GET /posts` for any page, answering with [data].
    void stubPosts(List<dynamic> data) {
      when(
        () => dio.get<List<dynamic>>(
          '/posts',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: data,
          requestOptions: RequestOptions(path: '/posts'),
          statusCode: 200,
        ),
      );
    }

    test('fetchPosts decodes the response body', () async {
      stubPosts(<dynamic>[
        <String, Object?>{
          'id': 1,
          'userId': 1,
          'title': 'title',
          'body': 'body',
        },
      ]);

      final posts = await repository.fetchPosts();

      expect(
        posts,
        const [Post(id: 1, userId: 1, title: 'title', body: 'body')],
      );
    });

    test('fetchPosts asks for the requested page', () async {
      // Pins the paging contract: a page number the server does not
      // receive is a list that silently never advances.
      stubPosts(<dynamic>[]);

      await repository.fetchPosts(page: 3, limit: 5);

      verify(
        () => dio.get<List<dynamic>>(
          '/posts',
          queryParameters: <String, Object?>{'_page': 3, '_limit': 5},
        ),
      ).called(1);
    });

    test('fetchPosts defaults to the first page', () async {
      stubPosts(<dynamic>[]);

      await repository.fetchPosts();

      verify(
        () => dio.get<List<dynamic>>(
          '/posts',
          queryParameters: <String, Object?>{
            '_page': 1,
            '_limit': postsPageSize,
          },
        ),
      ).called(1);
    });

    test('fetchPosts maps timeouts to NetworkException', () async {
      when(
        () => dio.get<List<dynamic>>(
          '/posts',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/posts'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(repository.fetchPosts, throwsA(isA<NetworkException>()));
    });

    test('fetchPost decodes a single post', () async {
      when(() => dio.get<Map<String, dynamic>>('/posts/1')).thenAnswer(
        (_) async => Response(
          data: <String, dynamic>{
            'id': 1,
            'userId': 1,
            'title': 'title',
            'body': 'body',
          },
          requestOptions: RequestOptions(path: '/posts/1'),
          statusCode: 200,
        ),
      );

      final post = await repository.fetchPost(1);

      expect(post, const Post(id: 1, userId: 1, title: 'title', body: 'body'));
    });

    test('fetchPost maps bad responses to ServerException', () async {
      when(() => dio.get<Map<String, dynamic>>('/posts/1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/posts/1'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/posts/1'),
            statusCode: 500,
          ),
        ),
      );

      expect(
        () => repository.fetchPost(1),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}
