// A test that continuous integration runs in the apps with the env role
// that have keys, whichever module provides the role: for each
// key of the app, the getter of AppEnv returns the value that .env gives
// the key, and null when .env leaves the value empty or lacks the key.
//
// It only reads. The matrix writes into .env the values that the tests of
// the modules of the app give their keys, and removes the line of a key that
// a test gives null, before it runs flutter test with the arguments that the
// provider of the role gives the role. The test parses .env in the two forms
// of a value that the role names: a plain value, without white space, # or
// quotes, and any other value in double quotes, each after KEY= and before a
// comment, if the line has one. The matrix writes the keys of the app, from
// the data of the role, into keys.dart next to the test. It reads AppEnv
// without starting the app, since the role says that the getters return the
// values before any code of the app runs, main() included.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'keys.dart';

/// A line `KEY=value` of .env: the key, and the rest of the line, which
/// starts with the value.
final _keyLine = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$');

/// A value in double quotes, with a comment after it or none.
final _quoted = RegExp(r'^"([^"]*)"\s*(?:#.*)?$');

/// A plain value, which may be empty, with a comment after it or none.
final _plain = RegExp(r'''^([^\s#"'`]*)\s*(?:#.*)?$''');

/// The values of [text], the text of .env, by their keys. A line that is
/// empty or starts with `#` is no value.
///
/// Throws a [FormatException] for a line with a value in no form of the
/// role, and for a key that has two lines, which the role gives no meaning.
/// Neither names a value.
Map<String, String> _valuesIn(String text) {
  final values = <String, String>{};
  for (final (index, raw) in text.split('\n').indexed) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final match = _keyLine.firstMatch(line);
    if (match == null) {
      throw FormatException(
        'Line ${index + 1} of $dotEnvFile is neither KEY=value, a comment nor '
        'empty.',
      );
    }
    final key = match[1]!;
    final value =
        (_quoted.firstMatch(match[2]!) ?? _plain.firstMatch(match[2]!))
            ?.group(1);
    if (value == null) {
      throw FormatException(
        'Line ${index + 1} of $dotEnvFile, the line of $key, has a value in '
        'none of the forms of the env role: a plain value without white '
        'space, # or quotes, or a value in double quotes.',
      );
    }
    if (values.containsKey(key)) {
      throw FormatException('$dotEnvFile has $key twice.');
    }
    values[key] = value;
  }
  return values;
}

void main() {
  // The values of .env as the matrix wrote it, read once the test files are
  // loaded, before any test runs.
  final values = _valuesIn(File(dotEnvFile).readAsStringSync());
  final given = [
    for (final key in appKeys)
      if (values[key.name] case final value? when value.isNotEmpty)
        (key, value),
  ];
  final empty = [
    for (final key in appKeys)
      if (values[key.name] == '') key,
  ];
  final missing = [
    for (final key in appKeys)
      if (!values.containsKey(key.name)) key,
  ];

  test(
    'AppEnv returns the value that .env gives each key, under the getter of '
    'the key',
    () {
      for (final (key, value) in given) {
        expect(
          key.read(),
          value,
          reason: 'The value of ${key.name} in $dotEnvFile reaches '
              'AppEnv.${key.getter}.',
        );
      }
    },
    skip:
        given.isEmpty ? 'No key of the app has a value in $dotEnvFile.' : null,
  );

  test(
    'AppEnv returns null for each key that .env leaves empty',
    () {
      for (final key in empty) {
        expect(
          key.read(),
          isNull,
          reason: '${key.name} is empty in $dotEnvFile, so '
              'AppEnv.${key.getter} is null: an empty value counts as '
              'missing.',
        );
      }
    },
    skip: empty.isEmpty ? 'No key of the app is empty in $dotEnvFile.' : null,
  );

  test(
    'AppEnv returns null for each key that .env lacks',
    () {
      for (final key in missing) {
        expect(
          key.read(),
          isNull,
          reason: '${key.name} is not in $dotEnvFile, so AppEnv.${key.getter} '
              'is null.',
        );
      }
    },
    skip: missing.isEmpty ? 'Every key of the app is in $dotEnvFile.' : null,
  );
}
