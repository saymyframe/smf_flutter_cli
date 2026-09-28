@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../example/smf_contribution_engine_example.dart' as example;

/// A standard output that records what is written to it.
final class _Output implements Stdout {
  final text = StringBuffer();

  @override
  void write(Object? object) => text.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the example prints the file that its comment shows', () async {
    final output = _Output();

    // In this process: a process of its own would compile the analyzer
    // first, which can take longer than a test may on a busy machine.
    await IOOverrides.runZoned(example.main, stdout: () => output);

    final lib = await Isolate.resolvePackageUri(
      Uri.parse('package:smf_contribution_engine/'),
    );
    final source = File(
      p.join(
        p.dirname(lib!.toFilePath()),
        'example',
        'smf_contribution_engine_example.dart',
      ),
    );
    expect(
      const LineSplitter().convert('${output.text}'),
      _printed(source.readAsLinesSync()),
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
      if (line == '//') '' else line.substring('//   '.length),
  ];
}
