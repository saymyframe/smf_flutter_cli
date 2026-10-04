{{#has_preferences}}import '../preferences/app_preferences.dart';

{{/has_preferences}}/// The setting of the fixture: a number that the app remembers between its
/// launches when it has preferences.
final fixtureSetting = FixtureSetting();

/// A number, 0 until something sets it.
final class FixtureSetting {
  int _value = 0;{{#has_preferences}}

  /// The preferences that remember the number, once the app opened them.
  AppPreferences? _preferences;{{/has_preferences}}

  /// The number.
  int get value => _value;

  /// Sets the number to [value]. In an app with preferences, it saves the
  /// number too, once the app opened them: before that, it changes only
  /// memory.
  Future<void> set(int value) async {
    _value = value;{{#has_preferences}}
    await _preferences?.setInt(fixtureSettingKey, value);{{/has_preferences}}
  }
}{{#has_preferences}}

/// The key of the setting of the fixture in the preferences.
const fixtureSettingKey = 'fake_preferences_user.setting';

/// What the restorers of the fixture read each time the app gave them the
/// preferences, in the order they ran: the name of each and the number
/// that was saved, or `null`.
final List<(String, int?)> fixtureRestored = [];

/// Whether the restorers of the fixture throw once they did their work, as
/// a test that a restorer that throws keeps no other from restoring sets
/// it: the first an error, and the second an exception, as a restorer does
/// that cannot read what is saved.
bool fixtureRestorersThrow = false;

/// The first restorer of the fixture, which only notes in [fixtureRestored]
/// what is saved, and then throws an error if [fixtureRestorersThrow].
void noteFixtureSetting(AppPreferences preferences) {
  fixtureRestored.add(('note', preferences.getInt(fixtureSettingKey)));
  if (fixtureRestorersThrow) {
    throw StateError('The first restorer of the fixture throws.');
  }
}

/// The restorer of the setting of the fixture: takes the number that is
/// saved, or keeps the current one when nothing is saved, and keeps
/// [preferences] for the writes of the setting. It notes in
/// [fixtureRestored] what is saved, and then throws an exception if
/// [fixtureRestorersThrow].
void restoreFixtureSetting(AppPreferences preferences) {
  final saved = preferences.getInt(fixtureSettingKey);
  fixtureSetting
    .._value = saved ?? fixtureSetting._value
    .._preferences = preferences;
  fixtureRestored.add(('setting', saved));
  if (fixtureRestorersThrow) {
    throw const FormatException(
      'The restorer of the setting of the fixture throws.',
    );
  }
}{{/has_preferences}}
