import 'package:args/command_runner.dart';
import 'package:smf_flutter_cli/commands/smf_command_runner.dart';
import 'package:smf_flutter_cli/version.dart';
import 'package:test/test.dart';

import '../helpers/io_capture.dart';

void main() {
  group('SMFCommandRunner', () {
    Future<CapturedOutput> run(List<String> args) =>
        captureOutput(() => SMFCommandRunner().run(args));

    Matcher throwsUsageException(String message) => throwsA(
          isA<UsageException>().having(
            (e) => e.message,
            'message',
            contains(message),
          ),
        );

    test('is named smf and registers the create command', () {
      final runner = SMFCommandRunner();

      expect(runner.executableName, 'smf');
      expect(runner.commands.keys, containsAll(['create', 'help']));
    });

    group('--version', () {
      test('prints the CLI version without the usage', () async {
        final output = await run(['--version']);

        expect(output.stdout, 'ℹ️ CLI version: $packageVersion\n');
        expect(output.printed, isEmpty);
      });

      test('accepts -v', () async {
        final output = await run(['-v']);

        expect(output.stdout, contains('CLI version: $packageVersion'));
      });

      test('still runs a command given after the flag', () async {
        final output = await run(['--version', 'help']);

        expect(output.stdout, contains('CLI version: $packageVersion'));
        expect(output.printed, contains('Usage: smf <command> [arguments]'));
      });
    });

    group('usage', () {
      test('--help lists the global options and commands', () async {
        final output = await run(['--help']);

        expect(
          output.printed,
          allOf([
            contains('Usage: smf <command> [arguments]'),
            contains('--verbose'),
            contains('--strict'),
            contains('--version'),
            contains('--on-conflict'),
            contains('[replace, copy, cancel, prompt (default)]'),
            contains('create'),
            contains('Create flutter app'),
          ]),
        );
        expect(output.stdout, isEmpty);
      });

      test('is printed when no command is given', () async {
        final output = await run([]);

        expect(output.printed, contains('Usage: smf <command> [arguments]'));
      });

      test('help create describes the create options', () async {
        final output = await run(['help', 'create']);

        expect(
          output.printed,
          allOf([
            contains('Usage: smf create [arguments]'),
            contains('--output'),
            contains('--modules'),
            contains('--route'),
            contains('--org'),
            contains('--state-manager'),
            contains('[bloc, riverpod]'),
          ]),
        );
      });
    });

    group('usage errors', () {
      test('are thrown for an unknown command', () async {
        await expectLater(
          run(['bogus']),
          throwsUsageException('Could not find a command named "bogus".'),
        );
      });

      test('are thrown for an unknown global flag', () async {
        await expectLater(
          run(['--bogus']),
          throwsUsageException('Could not find an option named "--bogus".'),
        );
      });

      test('are thrown for an unsupported --on-conflict value', () async {
        await expectLater(
          run(['--on-conflict', 'merge', 'create']),
          throwsUsageException(
            '"merge" is not an allowed value for option "--on-conflict".',
          ),
        );
      });

      test('are thrown for an unsupported --state-manager value', () async {
        await expectLater(
          run(['create', 'app', '--state-manager', 'mobx']),
          throwsUsageException(
            '"mobx" is not an allowed value for option "--state-manager".',
          ),
        );
      });
    });
  });
}
