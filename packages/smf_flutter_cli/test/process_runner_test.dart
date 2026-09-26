@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_cli/src/io/process_runner.dart';
import 'package:test/test.dart';

/// A Dart script that writes to both streams, with a carriage return that
/// rewrites a line, and exits with the code in its first argument.
const _script = r'''
import 'dart:io';

Future<void> main(List<String> arguments) async {
  stdout.write('first\nhalf');
  await stdout.flush();
  stdout.write(' line\n\n');
  stderr.write('waiting...\r      \rdone\n');
  stdout.write('in ${Directory.current.path}: ${Platform.environment['SMF_TEST']}\n');
  stdout.write('last');
  exitCode = int.parse(arguments.first);
}
''';

/// A Dart script that exits with the code in its first argument.
const _exit = '''
import 'dart:io';

void main(List<String> arguments) => exitCode = int.parse(arguments.first);
''';

/// A Dart script that reads its input to the end.
const _reader = r'''
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final input = await stdin.transform(utf8.decoder).join();
  stdout.write('read ${input.length} characters');
}
''';

/// A Dart script that waits until it is stopped.
const _sleeper = '''
Future<void> main() => Future<void>.delayed(const Duration(minutes: 1));
''';

void main() {
  late Directory temporary;
  late StreamController<ProcessSignal> signals;
  late Interruption interruption;
  late IoProcessRunner runner;
  final dart = Platform.resolvedExecutable;

  String scriptOf(String name, String text) =>
      (File(p.join(temporary.path, name))..writeAsStringSync(text)).path;

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('smf_runner_');
    signals = StreamController<ProcessSignal>();
    interruption = Interruption(
      signals: signals.stream,
      exit: (code) => throw StateError('exit $code'),
    )..listen();
    runner = IoProcessRunner(interruption);
  });

  tearDown(() async {
    await interruption.close();
    temporary.deleteSync(recursive: true);
  });

  test('runs a command and gives its output as it comes', () async {
    final lines = <String>[];
    final result = await runner.run(
      dart,
      [scriptOf('script.dart', _script), '3'],
      workingDirectory: temporary.path,
      environment: {'SMF_TEST': 'set'},
      onOutput: lines.add,
    );

    expect(result.exitCode, 3);
    expect(result.succeeded, isFalse);
    expect(result.stdout, startsWith('first\nhalf line\n\nin '));
    expect(result.stdout, endsWith(': set\nlast'));
    expect(result.stderr, 'waiting...\r      \rdone\n');
    expect(
      lines,
      unorderedEquals([
        'first',
        'half line',
        'waiting...',
        'done',
        allOf(startsWith('in '), endsWith(': set')),
        'last',
      ]),
    );
    // The working directory, which the output names, is the given one.
    final named = lines.singleWhere((line) => line.startsWith('in '));
    expect(
      File(named.substring(3, named.lastIndexOf(':')))
          .resolveSymbolicLinksSync(),
      temporary.resolveSymbolicLinksSync(),
    );
  });

  test('a command gets no input, so one that reads it ends', () async {
    final result = await runner.run(dart, [scriptOf('reader.dart', _reader)]);

    expect(result.stdout, 'read 0 characters');
  });

  test('a command that cannot start throws', () async {
    await expectLater(
      runner.run(p.join(temporary.path, 'missing'), const []),
      throwsA(isA<ProcessException>()),
    );
    await expectLater(
      runner.runInteractive(p.join(temporary.path, 'missing'), const []),
      throwsA(isA<ProcessException>()),
    );
  });

  test('an interrupted run starts no command', () async {
    interruption.markInterrupted();

    await expectLater(
      runner.run(dart, ['--version']),
      throwsA(isA<SmfCancelledException>()),
    );
    await expectLater(
      runner.runInteractive(dart, ['--version']),
      throwsA(isA<SmfCancelledException>()),
    );
  });

  test('Ctrl-C stops the command and cancels the run', () async {
    final running = runner.run(dart, [scriptOf('sleeper.dart', _sleeper)]);
    // The command may still be starting; it is stopped once it has.
    signals.add(ProcessSignal.sigint);

    await expectLater(running, throwsA(isA<SmfCancelledException>()));
  });

  test('Ctrl-C stops a running command', () async {
    final running = runner.run(dart, [scriptOf('sleeper.dart', _sleeper)]);
    await Future<void>.delayed(const Duration(seconds: 1));
    signals.add(ProcessSignal.sigint);

    await expectLater(running, throwsA(isA<SmfCancelledException>()));
  });

  test('a command that owns the terminal keeps Ctrl-C and its exit code',
      () async {
    final code = runner.runInteractive(
      dart,
      [scriptOf('exit.dart', _exit), '4'],
      workingDirectory: temporary.path,
    );
    signals.add(ProcessSignal.sigint);

    expect(await code, 4);
    expect(interruption.interrupted, isFalse);
  });

  group('on Windows', () {
    test('batch files are what cmd.exe runs', () {
      expect(isBatchFile(r'C:\flutter\bin\flutter.bat'), isTrue);
      expect(isBatchFile(r'C:\npm\firebase.CMD'), isTrue);
      expect(isBatchFile(r'C:\dart-sdk\bin\dart.exe'), isFalse);
    });

    test('a batch file gets no argument that cmd.exe would read', () {
      for (final argument in [
        '100%',
        'a^b',
        'a&b',
        'a|b',
        '<in',
        '>out',
        'say "hi"',
        'two\nlines',
        'a\rb',
      ]) {
        expect(batchArgumentProblem(argument), isNotNull, reason: argument);
      }
      for (final argument in [
        '--platforms=android,ios',
        'pub',
        r'C:\Program Files\app',
        "it's",
        '(x)',
        'a;b',
        'a=b',
        '',
      ]) {
        expect(batchArgumentProblem(argument), isNull, reason: argument);
      }
    });

    test('the runner refuses them before it starts anything', () async {
      final windows = IoProcessRunner(interruption, isWindows: true);

      await expectLater(
        windows.run(r'C:\flutter\bin\flutter.bat', ['pub', 'get', 'a&b']),
        throwsA(
          isA<ProcessException>().having(
            (e) => e.message,
            'message',
            '"a&b" cannot go to cmd.exe safely: cmd.exe would read "&" as '
                'the end of the command.',
          ),
        ),
      );
      await expectLater(
        windows.runInteractive(r'C:\A&B\flutter.bat', ['pub']),
        throwsA(isA<ProcessException>()),
      );
      // In a shell, any command's line goes through cmd.exe.
      await expectLater(
        windows.run(
          r'C:\git\git.exe',
          ['commit', '-m', '100%'],
          runInShell: true,
        ),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}
