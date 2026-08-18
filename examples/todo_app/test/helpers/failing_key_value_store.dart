import 'package:todo_app/core/storage/key_value_store.dart';

/// What a real [KeyValueStore] throws when the platform underneath it
/// gives up.
///
/// `shared_preferences` raises a `PlatformException`, and web
/// `localStorage` a quota error once it is full. Neither is a type any
/// feature models — which is the point: code that treats the store as
/// infallible turns one of these into a failed fetch or a dead button.
class StoreFailure implements Exception {
  /// Creates the failure.
  const StoreFailure();

  @override
  String toString() => 'StoreFailure';
}

/// [KeyValueStore] double whose operations fail on demand.
class FailingKeyValueStore implements KeyValueStore {
  /// Creates a store that fails the operations the flags select.
  FailingKeyValueStore({
    this.failReads = false,
    this.failWrites = false,
    this.failRemovals = false,
  });

  final Map<String, String> _values = <String, String>{};

  /// Whether [getString] throws a [StoreFailure].
  bool failReads;

  /// Whether [setString] throws a [StoreFailure].
  bool failWrites;

  /// Whether [remove] throws a [StoreFailure].
  bool failRemovals;

  @override
  Future<String?> getString(String key) async {
    if (failReads) throw const StoreFailure();
    return _values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw const StoreFailure();
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failRemovals) throw const StoreFailure();
    _values.remove(key);
  }
}
