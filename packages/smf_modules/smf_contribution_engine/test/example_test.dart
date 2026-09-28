@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('the example prints the file that its comment shows', () async {
    final lib = await Isolate.resolvePackageUri(
      Uri.parse('package:smf_contribution_engine/'),
    );
    final example = p.join(
      p.dirname(lib!.toFilePath()),
      'example',
      'smf_contribution_engine_example.dart',
    );
    final packages = await Isolate.packageConfig;

    final result = await Process.run(
      Platform.resolvedExecutable,
      ['--packages=${packages!.toFilePath()}', example],
      stdoutEncoding: utf8,
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      const LineSplitter().convert(result.stdout as String),
      _printed(File(example).readAsLinesSync()),
    );
  });
}

/// The lines that the leading comment of the example, [lines], shows under
/// "It prints:", indented by two spaces after `//`.
List<String> _printed(List<String> lines) {
  final start = lines.indexOf('// It prints:');
  expect(start, isNot(-1), reason: 'The comment shows no output.');
  return [
    // A blank line of the comment comes first.
    for (final line in lines.skip(start + 2).takeWhile(
          (line) => line.startsWith('//'),
        ))
      line == '//' ? '' : line.substring('//   '.length),
  ];
}
