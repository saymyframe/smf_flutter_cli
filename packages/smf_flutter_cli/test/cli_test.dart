import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_cli/src/banner.dart';
import 'package:smf_flutter_cli/version.dart';
import 'package:test/test.dart';

/// A standard stream that records what is written to it.
final class _Stream implements Stdout {
  final text = StringBuffer();

  @override
  void write(Object? object) => text.write(object);

  @override
  void writeln([Object? object = '']) => text.writeln(object);

  @override
  bool get hasTerminal => false;

  @override
  bool get supportsAnsiEscapes => false;

  @override
  Encoding get encoding => utf8;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs `smf` with [arguments] in this process, with the standard output
/// and error recorded, and returns the exit code, the output and the error.
Future<(int, String, String)> _smf(List<String> arguments) async {
  final out = _Stream();
  final err = _Stream();
  final code = await IOOverrides.runZoned(
    () => runCli(arguments),
    stdout: () => out,
    stderr: () => err,
  );
  return (code, '${out.text}', '${err.text}');
}

void main() {
  test('prints the version', () async {
    final (code, out, _) = await _smf(['--version']);

    expect(code, 0);
    expect(out, '$packageVersion\n');
  });

  test('an unknown command is a usage error', () async {
    final (code, out, err) = await _smf(['bogus']);

    expect(code, 64);
    expect(err, contains('Could not find a command named "bogus".'));
    expect(out, contains('Usage: smf <command> [arguments]'));
  });

  test('create offers the options of the roles of its modules', () async {
    final (code, out, _) = await _smf(['create', '--help']);

    expect(code, 0);
    expect(out, contains('--start=<path>'));
  });

  test('the banner points to the community', () {
    expect(
      communityBanner,
      allOf(
        contains('Created an SMF App!'),
        contains('https://saymyframe.com/discord'),
        contains('https://github.com/saymyframe/smf_flutter_cli'),
      ),
    );
    expect(greeting, contains('Say My Frame'));
  });
}
