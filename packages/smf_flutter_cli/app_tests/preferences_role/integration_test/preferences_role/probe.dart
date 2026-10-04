// The probe of the preferences role, whichever module provides it, which
// the start check runs on a device once the first screen of the app
// settled, the only place where the platform side of the provider is the
// real one, and whose checks the test of the role runs too
// (preferences_role_test.dart): a value of each type is read back as it
// was saved, and as null by the reads of the other types; a key that was
// removed has no value; and the preferences keep lists of their own.
//
// It uses no test framework. It writes only keys of its own, under the id
// of the role, `preferences.`, which no module and no other role has, and
// removes them when it is done, since on a device the preferences are
// those of the app.
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

/// The probe of the start check: the problems of [problemsOfOneRun] with
/// the preferences of the app. It waits for no screen, so it leaves
/// [settle] out.
Future<List<String>> probePreferences(Future<void> Function() settle) =>
    problemsOfOneRun(createAppPreferences());

/// A type of the values that the preferences keep: its name, the key and
/// the value of it that the probe saves, how to save that value, and how
/// to read a value of the type.
typedef PreferenceKind = ({
  String name,
  String key,
  Object value,
  Future<void> Function(AppPreferences preferences, String key) save,
  Object? Function(AppPreferences preferences, String key) read,
});

/// The types of the values that the preferences keep.
final List<PreferenceKind> preferenceKinds = [
  (
    name: 'String',
    key: 'preferences.probe_string',
    value: 'text',
    save: (preferences, key) => preferences.setString(key, 'text'),
    read: (preferences, key) => preferences.getString(key),
  ),
  (
    name: 'bool',
    key: 'preferences.probe_bool',
    value: true,
    save: (preferences, key) => preferences.setBool(key, true),
    read: (preferences, key) => preferences.getBool(key),
  ),
  (
    name: 'int',
    key: 'preferences.probe_int',
    value: 7,
    save: (preferences, key) => preferences.setInt(key, 7),
    read: (preferences, key) => preferences.getInt(key),
  ),
  (
    name: 'double',
    key: 'preferences.probe_double',
    value: 1.5,
    save: (preferences, key) => preferences.setDouble(key, 1.5),
    read: (preferences, key) => preferences.getDouble(key),
  ),
  (
    name: 'List<String>',
    key: 'preferences.probe_list',
    value: const ['a', 'b'],
    save: (preferences, key) => preferences.setStringList(key, ['a', 'b']),
    read: (preferences, key) => preferences.getStringList(key),
  ),
];

/// What is wrong with [preferences] within one run of the app: the
/// problems of [problemsOfSavedValues] and [problemsOfOtherTypes] with the
/// values of [saveValues], and those of [problemsOfRemoval] and
/// [problemsOfLists], which leave no key of the probe behind.
Future<List<String>> problemsOfOneRun(AppPreferences preferences) async {
  await saveValues(preferences);
  return [
    ...problemsOfSavedValues(preferences),
    ...problemsOfOtherTypes(preferences),
    ...await problemsOfRemoval(preferences),
    ...await problemsOfLists(preferences),
  ];
}

/// Saves the value of each of [preferenceKinds] under its key.
Future<void> saveValues(AppPreferences preferences) async {
  for (final kind in preferenceKinds) {
    await kind.save(preferences, kind.key);
  }
}

/// Removes what is saved under the key of each of [preferenceKinds].
Future<void> removeValues(AppPreferences preferences) async {
  for (final kind in preferenceKinds) {
    await preferences.remove(kind.key);
  }
}

/// The values of [saveValues] that [preferences] do not read back as they
/// were saved, each with what its read returns or throws.
List<String> problemsOfSavedValues(AppPreferences preferences) => [
      for (final kind in preferenceKinds)
        switch (_reading(kind, preferences, kind.key)) {
          (value: _, :final String error) =>
            'The ${kind.name} that was saved is not read back: its read '
                'threw $error.',
          (:final value, error: _) when !_same(value, kind.value) =>
            'The ${kind.name} that was saved, ${kind.value}, is read back '
                'as $value.',
          _ => null,
        },
    ].nonNulls.toList();

/// The reads of [preferences] that do not return `null` for the key of a
/// value of [saveValues] of another type, each with what it returns or
/// throws. Whether a number saved as an `int` is read as a `double`, or
/// the other way round, is up to the provider, so those reads are left
/// out.
List<String> problemsOfOtherTypes(AppPreferences preferences) => [
      for (final saved in preferenceKinds)
        for (final read in preferenceKinds)
          if (read.name != saved.name && !(_isNumber(saved) && _isNumber(read)))
            switch (_reading(read, preferences, saved.key)) {
              (value: _, :final String error) =>
                'The ${saved.name} that was saved, read as ${read.name}, '
                    'threw $error rather than returning null.',
              (:final Object value, error: _) =>
                'The ${saved.name} that was saved, read as ${read.name}, is '
                    '$value rather than null.',
              _ => null,
            },
    ].nonNulls.toList();

/// The keys of [preferenceKinds] that [preferences] still read a value of,
/// each with what its read returns or throws.
List<String> problemsOfRemovedValues(AppPreferences preferences) => [
      for (final kind in preferenceKinds)
        switch (_reading(kind, preferences, kind.key)) {
          (value: _, :final String error) =>
            'The read of the ${kind.name} that was removed threw $error.',
          (:final Object value, error: _) =>
            'The ${kind.name} that was removed is still read, as $value.',
          _ => null,
        },
    ].nonNulls.toList();

/// What is wrong with removing from [preferences]: the problems of
/// [problemsOfRemovedValues] once the values of [saveValues] are removed,
/// and what removing a key that has no value throws.
Future<List<String>> problemsOfRemoval(AppPreferences preferences) async {
  await saveValues(preferences);
  await removeValues(preferences);
  final problems = problemsOfRemovedValues(preferences);
  try {
    await removeValues(preferences);
  } on Object catch (error) {
    problems.add('Removing a key without a value threw ${_firstLine(error)}.');
  }
  return problems;
}

/// What is wrong with the lists of [preferences]: a change of a list that
/// was saved, or of one that was read, changes what a read returns.
Future<List<String>> problemsOfLists(AppPreferences preferences) async {
  const key = 'preferences.probe_own_list';
  final problems = <String>[];
  final saved = ['a', 'b'];
  await preferences.setStringList(key, saved);
  saved.add('c');
  final kept = preferences.getStringList(key);
  if (!_same(kept, ['a', 'b'])) {
    problems.add(
      'A change of the list that was saved changes what the preferences '
      'have: they read $kept rather than [a, b].',
    );
  }
  try {
    preferences.getStringList(key)?.add('d');
  } on UnsupportedError {
    // A list that cannot be changed changes nothing either.
  }
  final after = preferences.getStringList(key);
  if (!_same(after, kept)) {
    problems.add(
      'A change of the list that was read changes what the preferences '
      'have: they read $after rather than $kept.',
    );
  }
  await preferences.remove(key);
  return problems;
}

/// What the read of [kind] returns for [key] of [preferences], or the
/// first line of what it throws.
({Object? value, String? error}) _reading(
  PreferenceKind kind,
  AppPreferences preferences,
  String key,
) {
  try {
    return (value: kind.read(preferences, key), error: null);
  } on Object catch (error) {
    return (value: null, error: _firstLine(error));
  }
}

/// Whether [kind] is a type of numbers.
bool _isNumber(PreferenceKind kind) => kind.value is num;

/// Whether [a] and [b] are equal, lists by their items.
bool _same(Object? a, Object? b) {
  if (a is! List<Object?> || b is! List<Object?>) return a == b;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// The first line of the text of [error].
String _firstLine(Object error) => '$error'.trim().split('\n').first;
