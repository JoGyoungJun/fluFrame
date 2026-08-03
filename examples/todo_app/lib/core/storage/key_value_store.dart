import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal async key-value persistence interface.
///
/// Feature repositories depend on this interface instead of a concrete
/// storage plugin, which keeps them trivial to test (see
/// `test/helpers/in_memory_key_value_store.dart`).
abstract interface class KeyValueStore {
  /// Reads the string stored under [key], or `null` when absent.
  Future<String?> getString(String key);

  /// Stores [value] under [key], overwriting any previous value.
  Future<void> setString(String key, String value);

  /// Removes the value stored under [key], if any.
  Future<void> remove(String key);
}

/// [KeyValueStore] backed by [SharedPreferencesAsync].
class SharedPreferencesKeyValueStore implements KeyValueStore {
  /// Creates a store delegating to [preferences].
  SharedPreferencesKeyValueStore(SharedPreferencesAsync preferences)
    : _preferences = preferences;

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Provider for the app-wide [KeyValueStore].
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPreferencesKeyValueStore(SharedPreferencesAsync()),
);
