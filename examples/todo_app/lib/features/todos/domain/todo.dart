import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

/// A single todo item.
@freezed
abstract class Todo with _$Todo {
  /// Creates a [Todo].
  const factory Todo({
    required String id,
    required String title,
    @Default(false) bool done,
  }) = _Todo;

  /// Decodes a [Todo] from its JSON representation.
  factory Todo.fromJson(Map<String, Object?> json) => _$TodoFromJson(json);
}
