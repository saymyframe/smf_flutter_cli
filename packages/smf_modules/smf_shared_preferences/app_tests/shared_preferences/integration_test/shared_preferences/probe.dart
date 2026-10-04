// The probe of the shared_preferences module, which the start check runs
// on a device once the first screen of the app settled: the only place
// where the platform side of the package is the real one. When the
// preferences are opened, each platform returns what is saved in a form of
// its own, such as a list of objects on iOS and a list that casts its items
// on Android. So the probe saves a value of each type through the
// preferences of the module, opens the preferences again, as the next
// launch of the app does, and reads each value back, as its type.
//
// It uses no test framework. It opens preferences of its own, next to those
// of the app, writes only keys of its own, under the id of the module, and
// removes them when it is done, since on a device the preferences are those
// of the app. The test of the module runs it too, over platform sides that
// return lists as iOS and as Android do (shared_preferences_test.dart).
import 'package:{{app_name}}/core/preferences/shared_app_preferences.dart';

/// The probe of the start check: the problems of [problemsOfANewOpen]. It
/// waits for no screen, so it leaves [settle] out.
Future<List<String>> probeSharedPreferences(
  Future<void> Function() settle,
) =>
    problemsOfANewOpen();

/// What preferences that are opened anew read otherwise than preferences
/// opened before saved it: a value of each type, a number as the other
/// type of numbers, and a key that was removed.
Future<List<String>> problemsOfANewOpen() async {
  const text = 'shared_preferences.probe_text';
  const flag = 'shared_preferences.probe_flag';
  const count = 'shared_preferences.probe_count';
  const ratio = 'shared_preferences.probe_ratio';
  const whole = 'shared_preferences.probe_whole_ratio';
  const list = 'shared_preferences.probe_list';
  const empty = 'shared_preferences.probe_empty_list';

  final first = await openSharedAppPreferences();
  await first.setString(text, 'text');
  await first.setBool(flag, true);
  await first.setInt(count, 3);
  await first.setDouble(ratio, 1.5);
  // A whole number, which a platform could return as an int.
  await first.setDouble(whole, 2);
  await first.setStringList(list, ['a', 'b']);
  await first.setStringList(empty, []);

  final opened = await openSharedAppPreferences();
  final problems = [
    ..._problemsOf('the String', () => opened.getString(text), 'text'),
    ..._problemsOf('the bool', () => opened.getBool(flag), true),
    ..._problemsOf('the int', () => opened.getInt(count), 3),
    ..._problemsOf('the double', () => opened.getDouble(ratio), 1.5),
    ..._problemsOf('the whole double', () => opened.getDouble(whole), 2.0),
    ..._problemsOf(
      'the List<String>',
      () => opened.getStringList(list),
      const ['a', 'b'],
    ),
    ..._problemsOf(
      'the empty List<String>',
      () => opened.getStringList(empty),
      const <String>[],
    ),
    // This provider reads a number only as the type it was saved as.
    ..._problemsOf('the int, as a double,', () => opened.getDouble(count)),
    ..._problemsOf('the whole double, as an int,', () => opened.getInt(whole)),
  ];

  for (final key in [text, flag, count, ratio, whole, list, empty]) {
    await opened.remove(key);
  }
  final after = await openSharedAppPreferences();
  for (final (what, read) in <(String, Object? Function())>[
    ('the String', () => after.getString(text)),
    ('the bool', () => after.getBool(flag)),
    ('the int', () => after.getInt(count)),
    ('the double', () => after.getDouble(ratio)),
    ('the whole double', () => after.getDouble(whole)),
    ('the List<String>', () => after.getStringList(list)),
    ('the empty List<String>', () => after.getStringList(empty)),
  ]) {
    problems.addAll(_problemsOf('$what that was removed', read));
  }
  return problems;
}

/// The problem of [read], what preferences opened anew read of [what]: a
/// value other than [expected], of another type, or what it throws; none if
/// it returns [expected], which is `null` for a key that must have no value
/// of the type that is read.
List<String> _problemsOf(
  String what,
  Object? Function() read, [
  Object? expected,
]) {
  final Object? value;
  try {
    value = read();
  } on Object catch (error) {
    return [
      'Reading $what once the preferences were opened again threw '
          '${'$error'.trim().split('\n').first}.',
    ];
  }
  final same = switch ((value, expected)) {
    (final List<String> a, final List<String> b) => a.length == b.length &&
        [for (var index = 0; index < a.length; index++) a[index] == b[index]]
            .every((equal) => equal),
    _ => value == expected && value.runtimeType == expected.runtimeType,
  };
  return [
    if (!same)
      'Once the preferences were opened again, $what is read as '
          '${_described(value)} rather than ${_described(expected)}.',
  ];
}

/// [value] with its type, such as `2.0 (double)`.
String _described(Object? value) =>
    value == null ? 'null' : '$value (${value.runtimeType})';
