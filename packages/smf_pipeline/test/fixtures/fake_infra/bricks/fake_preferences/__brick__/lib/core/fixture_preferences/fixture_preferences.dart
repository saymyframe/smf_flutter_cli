import '../preferences/app_preferences.dart';

/// What the preferences of the fixture have saved: it stands for the disk
/// of a device, which outlives the preferences that a start of the app
/// opens. A list on it is a copy of the list that was saved.
final Map<String, Object> fixturePreferencesDisk = {};

/// Creates the preferences of the fixture, which read
/// [fixturePreferencesDisk] into memory, as a start of the app does.
AppPreferences createFixturePreferences() => FixturePreferences();

/// The preferences of the fixture: the settings of the app that are no
/// secret, in memory, over [fixturePreferencesDisk]. Nothing here is
/// encrypted: never store a token, a password, an API key or an encryption
/// key in them.
final class FixturePreferences implements AppPreferences {
  /// Reads [fixturePreferencesDisk] into memory.
  FixturePreferences() {
    for (final MapEntry(:key, :value) in fixturePreferencesDisk.entries) {
      _values[key] = _copyOf(value);
    }
  }

  final Map<String, Object> _values = {};

  @override
  String? getString(String key) => _read<String>(key);

  @override
  bool? getBool(String key) => _read<bool>(key);

  @override
  int? getInt(String key) => _read<int>(key);

  @override
  double? getDouble(String key) => _read<double>(key);

  @override
  List<String>? getStringList(String key) => switch (_values[key]) {
    final List<String> list => List.of(list),
    _ => null,
  };

  @override
  Future<void> setString(String key, String value) => _save(key, value);

  @override
  Future<void> setBool(String key, bool value) => _save(key, value);

  @override
  Future<void> setInt(String key, int value) => _save(key, value);

  @override
  Future<void> setDouble(String key, double value) => _save(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _save(key, List.of(value));

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
    fixturePreferencesDisk.remove(key);
  }

  /// The value of [key] in memory if it is a [T], or `null`.
  T? _read<T>(String key) => switch (_values[key]) {
    final T value => value,
    _ => null,
  };

  /// Keeps [value] under [key] in memory, and saves it to the disk.
  Future<void> _save(String key, Object value) async {
    _values[key] = value;
    fixturePreferencesDisk[key] = _copyOf(value);
  }

  /// [value], or a copy of it if it is a list.
  static Object _copyOf(Object value) =>
      value is List<String> ? List.of(value) : value;
}
