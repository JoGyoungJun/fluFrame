import 'package:dio/dio.dart';
import 'package:fluframe_app/core/network/api_client.dart';
import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/posts/data/cached_posts_repository.dart';
import 'package:fluframe_app/features/posts/domain/post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fetches [Post]s from the sample REST API.
///
/// Transport errors surface as typed [ApiException]s, never as raw
/// `DioException`s.
class PostsRepository {
  /// Creates a repository that talks to the API through [dio].
  PostsRepository(Dio dio) : _dio = dio;

  final Dio _dio;

  /// Fetches every post.
  Future<List<Post>> fetchPosts() async {
    try {
      final response = await _dio.get<List<dynamic>>('/posts');
      final data = response.data ?? const <dynamic>[];
      return data
          .map((json) => Post.fromJson(json as Map<String, Object?>))
          .toList();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }

  /// Fetches the single post identified by [id].
  Future<Post> fetchPost(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/posts/$id');
      final data = response.data;
      if (data == null) {
        throw const UnknownApiException('Empty response body.');
      }
      return Post.fromJson(data);
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

/// Provider for the app-wide [PostsRepository], wrapped in the offline
/// fallback cache (see [CachedPostsRepository]).
final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => CachedPostsRepository(
    PostsRepository(ref.watch(dioProvider)),
    ref.watch(keyValueStoreProvider),
  ),
);
