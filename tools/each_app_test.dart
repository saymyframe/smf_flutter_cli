// Tests .github/scripts/each_app.sh, which runs a command for each app of a
// directory in the jobs of CI, such as for the app with every module of a
// job that the --create of a matrix tool generates there.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String script;
  late Directory temp;

  setUpAll(() {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    script = '${'${top.stdout}'.trim()}/.github/scripts/each_app.sh';
  });

  // By its real path, which the shell takes for the current directory, as
  // the temporary directory of macOS is behind a symbolic link.
  setUp(
    () => temp = Directory(
      Directory.systemTemp
          .createTempSync('each_app_')
          .resolveSymbolicLinksSync(),
    ),
  );
  tearDown(() => temp.deleteSync(recursive: true));

  /// A directory [name] in the temporary directory with an app, a directory,
  /// for each of [apps], and a file, which is no app.
  String directoryOf(String name, List<String> apps) {
    final directory = Directory('${temp.path}/$name')..createSync();
    for (final app in apps) {
      Directory('${directory.path}/$app').createSync();
    }
    File('${directory.path}/notes.txt').writeAsStringSync('no app');
    return directory.path;
  }

  /// A command [name] in the temporary directory that runs [body] with sh.
  String command(String name, String body) {
    final file = File('${temp.path}/$name')
      ..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['+x', file.path]);
    return file.path;
  }

  /// Runs each_app.sh with [arguments] in the temporary directory, with the
  /// log of the commands in LOG.
  ProcessResult run(List<String> arguments) => Process.runSync(
        'bash',
        [script, ...arguments],
        workingDirectory: temp.path,
        environment: {'LOG': '${temp.path}/log'},
      );

  /// The lines that the commands wrote to the log.
  List<String> log() {
    final file = File('${temp.path}/log');
    return file.existsSync() ? file.readAsLinesSync() : const [];
  }

  test('runs the command in the directory of each app, one after another', () {
    final apps = directoryOf('apps', ['app_a', 'app_b']);
    final record = command('record', r'echo "$PWD $*" >> "$LOG"');

    final result = run([apps, record, 'one', 'two words']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(log(), ['$apps/app_a one two words', '$apps/app_b one two words']);
    expect(
      '${result.stdout}',
      endsWith('record passed for the 2 apps in $apps: app_a app_b.\n'),
    );
  });

  test(
      'runs the command for every app when it fails for one, and then fails, '
      'naming it', () {
    final apps = directoryOf('apps', ['app_a', 'app_b', 'app_c']);
    final record = command(
      'record',
      'echo "\${PWD##*/}" >> "\$LOG"\n[ "\${PWD##*/}" != app_b ] || exit 3',
    );

    final result = run([apps, record]);

    expect(result.exitCode, 1);
    expect(log(), ['app_a', 'app_b', 'app_c']);
    expect(
      '${result.stdout}',
      allOf(
        contains('::error::record failed for app_b with the exit code 3.\n'),
        endsWith(
          '::error::record failed for 1 of the 3 apps in $apps: app_b.\n',
        ),
      ),
    );
  });

  test('fails for a directory without apps', () {
    final apps = directoryOf('apps', []);
    final record = command('record', r'echo "$PWD" >> "$LOG"');

    final result = run([apps, record]);

    expect(result.exitCode, 1);
    expect(log(), isEmpty);
    expect('${result.stdout}', '::error::$apps has no app.\n');
  });

  test(
      'fails with its usage for a directory that does not exist, without a '
      'command, or with a variable that is no name', () {
    final apps = directoryOf('apps', ['app_a']);
    final record = command('record', r'echo "$PWD" >> "$LOG"');

    for (final arguments in [
      ['${temp.path}/missing', record],
      [apps],
      ['--env', '1APP', apps, record],
      ['--env', '', apps, record],
      ['--env', 'APP', apps],
      ['--tool-arguments', apps],
      ['--env'],
    ]) {
      final result = run(arguments);
      expect(result.exitCode, 64, reason: '$arguments');
      expect(
        '${result.stderr}',
        startsWith(
          'Usage: $script [--env <variable>] [--tool-arguments] '
          '<directory of apps> ',
        ),
        reason: '$arguments',
      );
    }
    expect(log(), isEmpty);
  });

  group('with --tool-arguments', () {
    /// A directory of the apps app_a, app_b and app_c, with the file of the
    /// tool arguments next to each: two arguments, one with a space, and an
    /// empty line, which is no argument; none; and one on a line without a
    /// line break at its end.
    String appsWithToolArguments() {
      final apps = directoryOf('SMF apps застосунки é', [
        'app_a',
        'app_b',
        'app_c',
      ]);
      File('$apps/app_a.tool_arguments')
          .writeAsStringSync('--dart-define-from-file=.env\ntwo words\n\n');
      File('$apps/app_b.tool_arguments').writeAsStringSync('');
      File('$apps/app_c.tool_arguments').writeAsStringSync('--last');
      return apps;
    }

    test(
        'gives the command of each app the lines of the file next to the app '
        'after its own arguments', () {
      final apps = appsWithToolArguments();
      final record = command(
        'record',
        r'''
line="${PWD##*/}"
for argument in "$@"; do line="$line [$argument]"; done
echo "$line ${SMF_TOOL_ARGUMENTS-<unset>}" >> "$LOG"''',
      );

      final result = run(['--tool-arguments', apps, record, 'own']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(log(), [
        'app_a [own] [--dart-define-from-file=.env] [two words] <unset>',
        'app_b [own] <unset>',
        'app_c [own] [--last] <unset>',
      ]);
      expect(
        '${result.stdout}',
        endsWith(
          'record passed for the 3 apps in $apps: app_a app_b app_c.\n',
        ),
      );
    });

    test(
        'with --env, before it or after it, gives them to the command in '
        'SMF_TOOL_ARGUMENTS, one on each line, and no more arguments', () {
      final apps = appsWithToolArguments();
      final record = command(
        'record',
        r'''
arguments="$(printf '%s' "${SMF_TOOL_ARGUMENTS-<unset>}" | tr '\n' '|')"
echo "${APP##*/} $* [$arguments]" >> "$LOG"''',
      );

      for (final options in [
        ['--tool-arguments', '--env', 'APP'],
        ['--env', 'APP', '--tool-arguments'],
      ]) {
        File('${temp.path}/log').writeAsStringSync('');
        final result = run([...options, apps, record, 'own']);

        expect(
          result.exitCode,
          0,
          reason: '$options ${result.stdout}${result.stderr}',
        );
        expect(
          log(),
          [
            'app_a own [--dart-define-from-file=.env|two words]',
            'app_b own []',
            'app_c own [--last]',
          ],
          reason: '$options',
        );
      }

      // Without --tool-arguments, the command gets no such variable.
      File('${temp.path}/log').writeAsStringSync('');
      expect(run(['--env', 'APP', apps, record]).exitCode, 0);
      expect(log(), everyElement(endsWith(' [<unset>]')));
    });

    test(
        'fails for an app without the file of its tool arguments, without '
        'running the command for it, and runs it for the others', () {
      final apps = appsWithToolArguments();
      File('$apps/app_b.tool_arguments').deleteSync();
      final record = command('record', r'echo "${PWD##*/} $*" >> "$LOG"');

      final result = run(['--tool-arguments', apps, record]);

      expect(result.exitCode, 1);
      expect(log(), [
        'app_a --dart-define-from-file=.env two words',
        'app_c --last',
      ]);
      expect(
        '${result.stdout}',
        allOf(
          contains(
            '::error::app_b has no file of the arguments of the flutter tool '
            'that build it with its values, $apps/app_b.tool_arguments, '
            'which the --create of packages/smf_flutter_cli/tool/matrix.dart '
            'writes next to the app: record does not run for it without '
            'them.\n',
          ),
          endsWith(
            '::error::record failed for 1 of the 3 apps in $apps: app_b.\n',
          ),
        ),
      );
    });
  });

  test(
      'with --env, runs the command in the current directory with the path '
      'of each app in the variable', () {
    final apps = directoryOf('apps', ['app_a', 'app_b']);
    final record = command('record', r'echo "$PWD $APP" >> "$LOG"');

    final result = run(['--env', 'APP', apps, record]);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(log(), [
      '${temp.path} $apps/app_a',
      '${temp.path} $apps/app_b',
    ]);
  });

  test('runs in a directory whose name has a space and letters beyond ASCII',
      () {
    final apps = directoryOf('SMF apps застосунки é', ['app_a', 'app_b']);
    final record = command('record', r'echo "$PWD" >> "$LOG"');

    final result = run([apps, record]);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(log(), ['$apps/app_a', '$apps/app_b']);
    expect(
      '${result.stdout}',
      endsWith('record passed for the 2 apps in $apps: app_a app_b.\n'),
    );
  });

  group('keeps a report of the tests of each app', () {
    /// A command like dart test with --file-reporter json:<path>, which
    /// writes the path of the app it tests to the report at <path>, from
    /// the directory it runs in, and fails for app_b.
    String tests() => command('tests', r'''
app="${APP:-$PWD}"
for argument in "$@"; do
  case "$previous" in --file-reporter) report="${argument#json:}" ;; esac
  case "$argument" in --file-reporter=json:*) report="${argument#--file-reporter=json:}" ;; esac
  previous="$argument"
done
mkdir -p "$(dirname "$report")"
echo "$app" > "$report"
[ "${app##*/}" != app_b ]
''');

    /// The reports in the directory [directory], by their names, with what
    /// they hold.
    Map<String, String> reportsIn(String directory) => {
          for (final file in Directory(directory).listSync()
            ..sort(
              (a, b) => a.path.compareTo(b.path),
            ))
            file.uri.pathSegments.last: (file as File).readAsStringSync(),
        };

    test('with --env, in the current directory, named after each app', () {
      final apps = directoryOf('SMF apps', ['app_a', 'app_b']);

      final result = run([
        '--env',
        'APP',
        apps,
        tests(),
        'test/a_test.dart',
        '--file-reporter',
        'json:build/test-results/a_test.json',
      ]);

      expect(result.exitCode, 1);
      expect(reportsIn('${temp.path}/build/test-results'), {
        'a_test.app_a.json': '$apps/app_a\n',
        'a_test.app_b.json': '$apps/app_b\n',
      });
    });

    test('in the directory of each app, named after it', () {
      final apps = directoryOf('apps', ['app_a', 'app_b']);

      final result = run([
        apps,
        tests(),
        '--file-reporter=json:build/test-results/a_test.json',
      ]);

      expect(result.exitCode, 1);
      for (final app in ['app_a', 'app_b']) {
        expect(reportsIn('$apps/$app/build/test-results'), {
          'a_test.$app.json': '$apps/$app\n',
        });
      }
    });
  });
}
