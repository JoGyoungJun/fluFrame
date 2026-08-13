import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';
part 'post.g.dart';

/// A blog post returned by the sample REST API.
@freezed
abstract class Post with _$Post {
  /// Creates a [Post].
  const factory Post({
    required int id,
    required int userId,
    required String title,
    required String body,
  }) = _Post;

  /// Decodes a [Post] from its JSON representation.
  factory Post.fromJson(Map<String, Object?> json) => _$PostFromJson(json);
}
