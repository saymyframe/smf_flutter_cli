import 'package:flutter/foundation.dart';

/// The settings of the app that are no secret, which it remembers between
/// its launches: the theme mode, the language, whether the user has seen
/// the onboarding.
///
/// Nothing here is encrypted, and a backup of the device carries it: never
/// store a token, a password or a key in the preferences.
///
/// A key is `<owner id>.<setting>`, such as `theme.mode`, where the owner
/// is the module or the role whose code keeps the setting.
///
/// A read is synchronous, from memory, and never throws: it returns `null`
/// when the key has no value of the type it asks for. Whether a number
/// saved as an `int` is read as a `double`, or the other way round, is up
/// to the provider of the preferences. Once the future of a write
/// completes, reads return what it saved, in this run of the app and after
/// its next launch.
abstract interface class AppPreferences {
  /// The text saved under [key], or `null` if it has none.
  String? getString(String key);

  /// The flag saved under [key], or `null` if it has none.
  bool? getBool(String key);

  /// The whole number saved under [key], or `null` if it has none.
  int? getInt(String key);

  /// The number saved under [key], or `null` if it has none.
  double? getDouble(String key);

  /// A copy of the list of texts saved under [key], or `null` if it has
  /// none: a change of the list changes nothing that is saved.
  List<String>? getStringList(String key);

  /// Saves the text [value] under [key].
  Future<void> setString(String key, String value);

  /// Saves the flag [value] under [key].
  Future<void> setBool(String key, bool value);

  /// Saves the whole number [value] under [key].
  Future<void> setInt(String key, int value);

  /// Saves the number [value] under [key].
  Future<void> setDouble(String key, double value);

  /// Saves a copy of the list of texts [value] under [key]: a later change
  /// of [value] changes nothing that is saved.
  Future<void> setStringList(String key, List<String> value);

  /// Removes what is saved under [key], which puts its setting back to its
  /// default: the reads of [key] return `null` again.
  Future<void> remove(String key);
}

/// Returns the preferences of the app, which [initPreferences] opened:
/// `bootstrap()` awaits it before the first frame, and there are none to
/// return before that.
AppPreferences createAppPreferences() => _appPreferences;

{{{smf_preferences__implementations}}}

/// The functions of the parts of the app that restore what they keep in the
/// preferences, such as the theme mode. [initPreferences] calls each with
/// the preferences once they are open, so that every part has its settings
/// before the first frame.
///
/// A restorer reads its settings, and keeps the preferences for the writes
/// of its part. It may run again, with preferences that were opened anew.
final List<void Function(AppPreferences preferences)> _restorers = [
{{{smf_preferences__restorers}}}
];

/// Calls each of [_restorers] with [preferences] on its own: what one
/// throws keeps no other from restoring and does not stop the start-up of
/// the app, which goes on with the defaults of that part. In debug mode it
/// is printed, so that a restorer that fails shows in the console.
void _restore(AppPreferences preferences) {
  for (final restore in _restorers) {
    try {
      restore(preferences);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('A restorer of the preferences failed: $error');
      }
    }
  }
}
