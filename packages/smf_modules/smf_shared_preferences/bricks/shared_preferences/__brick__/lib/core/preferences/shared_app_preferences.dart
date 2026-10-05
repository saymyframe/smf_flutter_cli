import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';

/// Opens the preferences of the app with the shared_preferences package: it
/// reads what is saved into memory, which the reads then answer from.
///
/// The app has one object of its preferences, which
/// `createAppPreferences()` returns once `initPreferences()` opened them.
Future<AppPreferences> openSharedAppPreferences() async => SharedAppPreferences(
  await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  ),
);

/// The settings of the app that are no secret, with the shared_preferences
/// package, which keeps them in DataStore on Android and in `UserDefaults`
/// on iOS.
///
/// Neither is encrypted, and a backup of the device carries them: never
/// store a token, a password, an API key or an encryption key in the
/// preferences.
///
/// A number is read only as the type that it was saved as: `getDouble`
/// returns `null` for a key with an `int`, and `getInt` for a key with a
/// `double`, a whole number too.
///
/// A write puts its value into memory before it saves it. If the platform
/// refuses the save, as Android does for a text that starts with the prefix
/// that shared_preferences marks a list with, the write fails, the reads of
/// this run return the value all the same, and the next launch reads none.
final class SharedAppPreferences implements AppPreferences {
  /// Creates the preferences on [SharedPreferencesWithCache], which has
  /// read what is saved.
  SharedAppPreferences(this._preferences);

  final SharedPreferencesWithCache _preferences;

  @override
  String? getString(String key) => _read<String>(key);

  @override
  bool? getBool(String key) => _read<bool>(key);

  @override
  int? getInt(String key) => _read<int>(key);

  @override
  double? getDouble(String key) => _read<double>(key);

  @override
  List<String>? getStringList(String key) => switch (_preferences.get(key)) {
    final List<Object?> list => _textsOf(list),
    _ => null,
  };

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);

  @override
  Future<void> setInt(String key, int value) => _preferences.setInt(key, value);

  @override
  Future<void> setDouble(String key, double value) =>
      _preferences.setDouble(key, value);

  /// shared_preferences keeps the list that it is given, so it gets a copy.
  @override
  Future<void> setStringList(String key, List<String> value) =>
      _preferences.setStringList(key, List.of(value));

  @override
  Future<void> remove(String key) => _preferences.remove(key);

  /// The value of [key] if it is a [T], or `null`. The reads of
  /// shared_preferences cast the value instead, and throw on a value of
  /// another type.
  T? _read<T>(String key) => switch (_preferences.get(key)) {
    final T value => value,
    _ => null,
  };

  /// A copy of [list] as a list of texts, or `null` if an item of it is no
  /// text.
  ///
  /// When the preferences are opened, the platform returns a list in a form
  /// of its own: a list of objects on iOS, and on Android a list that casts
  /// each item to a text as it is read, and so throws on an item that is
  /// none. Cast to objects, either gives its items as they are.
  static List<String>? _textsOf(List<Object?> list) {
    final items = list.cast<Object?>();
    return items.every((item) => item is String)
        ? List<String>.from(items)
        : null;
  }
}
