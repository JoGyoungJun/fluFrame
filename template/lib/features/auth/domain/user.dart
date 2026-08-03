import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// An authenticated user of the app.
@freezed
abstract class User with _$User {
  /// Creates a [User].
  const factory User({required String email}) = _User;
}
