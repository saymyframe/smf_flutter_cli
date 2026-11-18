import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_cli/src/banner.dart';
import 'package:smf_flutter_cli/version.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
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

  test('two modules that manage the state are a usage error', () async {
    final directory = Directory.systemTemp.createTempSync('smf_cli_');
    addTearDown(() => directory.deleteSync(recursive: true));

    final (code, _, err) = await _smf([
      'create',
      'my_app',
      '--no-input',
      '-m',
      'bloc,riverpod',
      '-o',
      directory.path,
    ]);

    expect(code, 64);
    expect(
      err,
      contains(
        'An app can have at most one provider of the state management role, '
        'but it has bloc (requested) and riverpod (requested). Keep one of '
        'them.',
      ),
    );
    expect(directory.listSync(), isEmpty);
  });

  test(
      'stops at an option of a role of its modules that is given twice, a '
      'mode option too', () async {
    final directory = Directory.systemTemp.createTempSync('smf_cli_');
    addTearDown(() => directory.deleteSync(recursive: true));
    // The options of the roles of the registry, not a list of their names,
    // so that the option of a role that comes later takes one value too.
    final options = [
      for (final role in ModuleRegistry(smfModules).roles) ...role.options,
    ];
    expect(options.where((option) => option.isMode), isNotEmpty);

    for (final option in options) {
      final [first, second, ...] = option.allowed ?? const ['a', 'b'];
      // A run that took the last value would stop at the two state managers
      // before it checks the machine or writes a file.
      final (code, _, err) = await _smf([
        'create',
        'my_app',
        '--no-input',
        '-m',
        'bloc,riverpod',
        '-o',
        directory.path,
        '--${option.name}',
        first,
        '--${option.name}=$second',
      ]);

      expect(code, 64, reason: option.name);
      expect(
        err,
        contains(
          'Give one value of --${option.name}, not 2: "$first", "$second".',
        ),
        reason: option.name,
      );
    }
    expect(directory.listSync(), isEmpty);
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

  test(
      'the frame of the banner has only ASCII, in lines of one length, so '
      'that every terminal draws its right edge straight', () {
    final frame = [
      for (final line in communityBanner.split('\n'))
        if (line.contains('|') || line.contains('+--')) line,
    ];
    // The colour of the frame starts on its first line and ends on its
    // last one.
    final plain = [
      for (final line in frame) line.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), ''),
    ];

    expect(plain, hasLength(greaterThan(2)));
    expect(plain.map((line) => line.length).toSet(), hasLength(1));
    // A terminal draws an emoji one or two cells wide, so a line with one
    // ends where no padding can foresee.
    for (final line in plain) {
      expect(line.runes.every((rune) => rune < 0x80), isTrue, reason: line);
    }
    expect(plain.first, plain.last);
    for (final line in plain.sublist(1, plain.length - 1)) {
      expect(line, allOf(startsWith('| '), endsWith(' |')));
    }
  });
}
