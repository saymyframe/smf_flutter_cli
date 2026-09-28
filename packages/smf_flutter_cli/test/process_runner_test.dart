@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/core.dart';
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

/// A Dart script that writes its arguments as JSON in UTF-8 and exits with
/// the code in its first argument.
const _arguments = '''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  stdout.add(utf8.encode(jsonEncode(arguments)));
  await stdout.flush();
  exitCode = int.parse(arguments.first);
}
''';

/// A shell script that starts a shell, which starts `sleep` and writes its
/// process id to the file in its first argument; once it is there, the
/// script says so and waits for them.
const _tree = r'''
sh -c 'sleep 60 & echo $! > "$1"; wait' inner "$1" &
while [ ! -s "$1" ]; do sleep 0.1; done
echo started
wait
''';

/// A shell script that ignores SIGTERM, as the `sleep` it starts does
/// then, and writes the process id of `sleep` to the file in its first
/// argument; the script says so and waits for it.
const _stubborn = r'''
trap '' TERM
sleep 60 &
echo $! > "$1"
echo started
wait
''';

/// A shell script whose subshell starts `sleep` and ends, so that `sleep`
/// belongs to no process of the script but keeps its output; the script
/// writes the process id of `sleep` to the file in its first argument,
/// says so, and runs a minute.
const _escaping = r'''
( sleep 60 & echo $! > "$1" )
echo started
sleep 60
''';

/// A Dart script that writes its process id to the file in its first
/// argument, says so, and waits a minute.
const _child = r'''
import 'dart:io';

Future<void> main(List<String> arguments) async {
  File(arguments.first).writeAsStringSync('$pid');
  stdout.writeln('child runs');
  await stdout.flush();
  await Future<void>.delayed(const Duration(minutes: 1));
}
''';

/// A batch file that runs [_child], next to it, with the Dart in
/// `SMF_TEST_DART`, as the `firebase.cmd` of npm runs `node`.
const _childBatch = '@echo off\r\n"%SMF_TEST_DART%" "%~dp0child.dart" %1\r\n';

/// A batch file that runs [_arguments], next to it, with the Dart in
/// `SMF_TEST_DART` and every argument it gets, as `dart.bat` of the
/// Flutter SDK passes its arguments to the Dart VM.
const _batch = '@echo off\r\n"%SMF_TEST_DART%" "%~dp0arguments.dart" %*\r\n';

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
    expect(result.timedOut, isFalse);
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

  group('with a timeout', () {
    test(
      'stops a command that runs past it with the processes it started, and '
      'says so with what the command wrote',
      () async {
        final started = p.join(temporary.path, 'sleep.pid');
        final clock = Stopwatch()..start();

        final result = await runner.run(
          '/bin/sh',
          [scriptOf('tree.sh', _tree), started],
          timeout: const Duration(seconds: 2),
        );

        clock.stop();
        expect(result.timedOut, isTrue);
        expect(result.succeeded, isFalse);
        expect(result.stdout, 'started\n');
        // Not the minute of sleep, which holds the output until it ends.
        expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
        final sleep = File(started).readAsStringSync().trim();
        expect(await _gone(sleep), isTrue, reason: 'sleep $sleep still runs');
      },
      testOn: '!windows',
    );

    test(
      'kills a command that ignores SIGTERM, and what it started, with '
      'SIGKILL after stopGrace',
      () async {
        final started = p.join(temporary.path, 'sleep.pid');
        final clock = Stopwatch()..start();

        final result = await runner.run(
          '/bin/sh',
          [scriptOf('stubborn.sh', _stubborn), started],
          timeout: const Duration(seconds: 1),
        );

        clock.stop();
        expect(result.timedOut, isTrue);
        expect(result.exitCode, -ProcessSignal.sigkill.signalNumber);
        expect(result.stdout, 'started\n');
        expect(clock.elapsed, greaterThan(IoProcessRunner.stopGrace));
        expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
        final sleep = File(started).readAsStringSync().trim();
        expect(await _gone(sleep), isTrue, reason: 'sleep $sleep still runs');
      },
      testOn: '!windows',
    );

    test(
      'gives what came when a process that left the command holds its output',
      () async {
        final escaped = p.join(temporary.path, 'escaped.pid');
        final clock = Stopwatch()..start();

        final result = await runner.run(
          '/bin/sh',
          [scriptOf('escaping.sh', _escaping), escaped],
          timeout: const Duration(seconds: 1),
        );

        clock.stop();
        // It outlives the command, so the test stops it.
        final sleep = int.parse(File(escaped).readAsStringSync().trim());
        addTearDown(() => Process.killPid(sleep, ProcessSignal.sigkill));
        expect(result.timedOut, isTrue);
        expect(result.stdout, 'started\n');
        // Not the minute for which the process holds both streams, nor
        // stopGrace for each of them.
        expect(
          clock.elapsed,
          lessThan(
            const Duration(seconds: 1) +
                IoProcessRunner.stopGrace +
                const Duration(milliseconds: 1500),
          ),
        );
      },
      testOn: '!windows',
    );

    test(
      'stops the command itself when ps cannot list what it started',
      () async {
        for (final ps in [p.join(temporary.path, 'missing'), 'false']) {
          final clock = Stopwatch()..start();

          final result = await IoProcessRunner(interruption, ps: ps).run(
            dart,
            [scriptOf('sleeper.dart', _sleeper)],
            timeout: const Duration(seconds: 1),
          );

          clock.stop();
          expect(result.timedOut, isTrue, reason: ps);
          expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
        }
      },
      testOn: '!windows',
    );

    test(
      'ends the command alone when taskkill of Windows cannot run',
      () async {
        final clock = Stopwatch()..start();

        // taskkill is not there outside Windows.
        final result = await IoProcessRunner(interruption, isWindows: true).run(
          dart,
          [scriptOf('sleeper.dart', _sleeper)],
          timeout: const Duration(seconds: 1),
        );

        clock.stop();
        expect(result.timedOut, isTrue);
        expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
      },
      testOn: '!windows',
    );

    test('gives the result of a command that ends before it as always',
        () async {
      final result = await runner.run(
        dart,
        [scriptOf('exit.dart', _exit), '3'],
        timeout: const Duration(minutes: 1),
      );

      expect(result.exitCode, 3);
      expect(result.timedOut, isFalse);
    });
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

    group(
      'a batch file',
      () {
        late String batch;

        setUp(() {
          // As the Flutter SDK may be, in a directory whose name has a
          // space and letters beyond ASCII.
          final directory = Directory(
            p.join(temporary.path, 'Flutter SDK – é ї'),
          )..createSync();
          File(p.join(directory.path, 'arguments.dart'))
              .writeAsStringSync(_arguments);
          batch = p.join(directory.path, 'dart.bat');
          File(batch).writeAsStringSync(_batch);
        });

        Future<SmfProcessResult> runBatch(List<String> arguments) => runner.run(
              batch,
              arguments,
              workingDirectory: temporary.path,
              environment: {'SMF_TEST_DART': dart},
            );

        test('runs without a shell and gets the arguments as they are',
            () async {
          // Those of the commands that SMF runs, such as flutterfire through
          // dart.bat, and a path like those of the apps.
          final arguments = [
            '0',
            'pub',
            'global',
            'run',
            'flutterfire_cli:flutterfire',
            'configure',
            '--platforms=android,ios',
            '--ios-bundle-id=com.example.my-app',
            '--android-package-name=com.example.my_app',
            p.join(temporary.path, 'SMF apps – застосунки é', 'my_app'),
            "it's (x); a=b",
          ];

          final result = await runBatch(arguments);

          expect(result.exitCode, 0, reason: result.stderr);
          expect(result.stdout, jsonEncode(arguments));
        });

        test('gives the exit code of the command it runs', () async {
          for (final code in [0, 1, 64, 70]) {
            final result = await runBatch(['$code']);

            expect(result.exitCode, code, reason: result.stderr);
            expect(result.stdout, jsonEncode(['$code']));
          }
        });

        test(
            'stops at its timeout with the command that it runs, as '
            'taskkill stops the tree of its processes', () async {
          final directory = p.dirname(batch);
          File(p.join(directory, 'child.dart')).writeAsStringSync(_child);
          final slow = p.join(directory, 'slow.cmd');
          File(slow).writeAsStringSync(_childBatch);
          final started = p.join(temporary.path, 'child.pid');

          final result = await runner.run(
            slow,
            [started],
            environment: {'SMF_TEST_DART': dart},
            // Long enough for the Dart of the child to start.
            timeout: const Duration(seconds: 10),
          );

          expect(result.timedOut, isTrue);
          expect(result.stdout, contains('child runs'));
          final child = File(started).readAsStringSync().trim();
          expect(await _gone(child), isTrue, reason: 'child $child runs');
        });

        test('gives the exit code of an interactive command too', () async {
          for (final code in [0, 64]) {
            expect(
              await runner.runInteractive(
                batch,
                ['$code'],
                environment: {'SMF_TEST_DART': dart},
              ),
              code,
            );
          }
        });
      },
      testOn: 'windows',
    );
  });
}

/// Whether the process [pid] ends within a few seconds, as `ps` tells, or
/// `tasklist` on Windows.
Future<bool> _gone(String pid) async {
  bool running() {
    if (!Platform.isWindows) {
      return Process.runSync('ps', ['-p', pid]).exitCode == 0;
    }
    final tasks = Process.runSync(
      'tasklist',
      ['/fi', 'PID eq $pid', '/fo', 'csv', '/nh'],
    );
    return '${tasks.stdout}'.contains('"$pid"');
  }

  for (var attempt = 0; attempt < 30; attempt++) {
    if (!running()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}
