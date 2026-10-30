// Writes `.env` for a job of CI, from `.env.example` and the variables of the
// process. No value in the file is a secret: every value ends up in the app.
//
// A key whose variable has a value gets it, in one of the two forms of a value
// of `.env`: as it is, or in double quotes when it has white space, `#` or a
// quote. Any other line stays as `.env.example` has it. A value with a double
// quote or a control character fits neither form, and could add a line of its
// own, so the script stops and writes nothing. It never prints a value.
//
// It replaces the `.env` that it finds, so a developer who wants to keep the
// values in `.env` does not run it.
import 'dart:io';

final _key = RegExp(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=');
final _unsafe = RegExp(r'["\x00-\x1F\x7F]');
final _quoted = RegExp(r"[\s#'`]");

void main() {
  final example = File('.env.example');
  if (!example.existsSync()) {
    stderr.writeln('.env.example is missing.');
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
      empty.add(key);
      lines.add(line);
    } else if (_unsafe.hasMatch(value)) {
      refused.add(key);
    } else {
      lines.add('$key=${_quoted.hasMatch(value) ? '"$value"' : value}');
    }
  }
  if (refused.isNotEmpty) {
    stderr.writeln(
      'The values of ${refused.join(', ')} have a double quote or a control '
      'character, which .env cannot hold.',
    );
    exitCode = 1;
    return;
  }
  File('.env').writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('Wrote .env.');
  if (empty.isNotEmpty) {
    stdout.writeln('No value for: ${empty.join(', ')}.');
  }
}
