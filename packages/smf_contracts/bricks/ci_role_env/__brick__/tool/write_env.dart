// Writes `.env` for a job of CI, from `.env.example` and the variables of the
// process. No value in the file is a secret: every value ends up in the app.
//
// A key whose variable has a value gets it, in one of the two forms of a value
// of `.env`: as it is, or in double quotes when it has white space, `#` or a
// quote. Any other line stays as `.env.example` has it. A value with a double
// quote, a control character or a line separator fits neither form, and could
// add a line of its own, so the script stops and writes nothing. It never prints
// a value.
//
// It never replaces a value. When `.env` has one, the script stops and leaves
// the file as it is, and a developer who wants it written again deletes it. A
// missing `.env`, or one without values such as a copy of `.env.example`, is
// what a job of CI starts from.
import 'dart:convert';
import 'dart:io';

final _key = RegExp(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=');
final _unsafe = RegExp(r'["\x00-\x1F\x7F\u2028\u2029]');
final _quoted = RegExp(r"[\s#'`]");
final _withoutValue = RegExp(
  r'^\s*(?:#.*|[A-Za-z_][A-Za-z0-9_]*\s*=\s*(?:""\s*)?(?:#.*)?)?$',
);

void main() {
  final example = File('.env.example');
  if (!example.existsSync()) {
    stderr.writeln('.env.example is missing.');
    exitCode = 1;
    return;
  }
  final env = File('.env');
  // In latin1, every file reads, so an error shows no part of a value.
  if (env.existsSync() &&
      !env.readAsLinesSync(encoding: latin1).every(_withoutValue.hasMatch)) {
    stderr.writeln(
      '.env has values, which this script would replace. Delete .env to write '
      'it again.',
    );
    exitCode = 1;
    return;
  }
  final lines = <String>[];
  final empty = <String>[];
  final refused = <String>[];
  for (final line in example.readAsLinesSync()) {
    final key = _key.firstMatch(line)?[1];
    if (key == null) {
      lines.add(line);
      continue;
    }
    final value = Platform.environment[key] ?? '';
    if (value.isEmpty) {
      if (_withoutValue.hasMatch(line)) empty.add(key);
      lines.add(line);
    } else if (_unsafe.hasMatch(value)) {
      refused.add(key);
    } else {
      lines.add('$key=${_quoted.hasMatch(value) ? '"$value"' : value}');
    }
  }
  if (refused.isNotEmpty) {
    stderr.writeln(
      'The values of ${refused.join(', ')} have a double quote, a control '
      'character or a line separator, which .env cannot hold.',
    );
    exitCode = 1;
    return;
  }
  env.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('Wrote .env.');
  if (empty.isNotEmpty) {
    stdout.writeln('No value for: ${empty.join(', ')}.');
  }
}
