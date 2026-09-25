import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late RecordingRunner runner;
  late FakeHost host;

  /// The modules of a small app, with [contributions] of a module `extra`.
  List<SmfModule> modulesWith([List<Contribution> contributions = const []]) =>
      [
        scaffold(contributions: [entryBrick()]),
        TestModule('extra', contributions: contributions),
      ];

  setUp(() {
    runner = RecordingRunner();
    host = FakeHost(processRunner: runner);
  });

  late List<bool> flags;
  late ModuleRegistry registry;

  Future<int> smf(List<String> arguments) => runSmf(
        arguments,
        registry: registry,
        hostFor: ({required verbose}) {
          flags.add(verbose);
          return host.host;
        },
        version: '1.2.3',
      );

  setUp(() {
    flags = [];
    registry = ModuleRegistry(modulesWith());
  });

  test('creates the app and says how to run it', () async {
    expect(
      await smf([
        'create',
        'my_app',
        '-o',
        '/work',
        '-m',
        'extra',
        '--no-input',
        '--skip-external-setup',
      ]),
      SmfExitCodes.success,
    );

    expect(host.logger.successes, ['Created my_app in /work/my_app.']);
    expect(
      host.logger.infos.last,
      'Run it: cd /work/my_app && flutter run',
    );
    expect(flags, [false]);
  });

  test('--verbose reaches the host', () async {
    await smf(['--verbose', 'create', 'my_app', '--explain']);

    expect(flags, [true]);
  });

  test('prints the version, help and explanations', () async {
    expect(await smf(['--version']), SmfExitCodes.success);
    expect(host.logger.infos.last, '1.2.3');

    expect(await smf(['--help']), SmfExitCodes.success);
    expect(host.logger.infos.last, contains('Available commands:'));

    expect(await smf([]), SmfExitCodes.success);
    expect(host.logger.infos.last, contains('create'));

    expect(await smf(['create', '--help']), SmfExitCodes.success);
    expect(host.logger.infos.last, contains('--on-conflict'));

    expect(
      await smf(['create', 'my_app', '--explain', '-m', 'extra']),
      SmfExitCodes.success,
    );
    expect(host.logger.infos, contains('Modules'));
  });

  test('usage errors exit with 64', () async {
    expect(await smf(['--nope']), SmfExitCodes.usage);
    expect(
        host.logger.errors.last,
        'Could not find an option named '
        '"--nope".');

    expect(await smf(['create', 'my_app', '--nope']), SmfExitCodes.usage);
    expect(host.logger.infos.last, contains('Usage: smf create <app name>'));

    expect(
      await smf(['create', 'my_app', '-m', 'unknown']),
      SmfExitCodes.usage,
    );
    expect(
      host.logger.errors.last,
      startsWith('There is no module unknown.'),
    );

    expect(await smf(['create', 'a', 'b']), SmfExitCodes.usage);
    expect(host.logger.errors.last, 'Give one app name, not 2: a b.');
  });

  test('the help of an unknown command is a usage error', () async {
    expect(await smf(['help', 'nope']), SmfExitCodes.usage);
    expect(
      host.logger.errors.last,
      'Could not find a command named "nope".',
    );
  });

  test('says which steps to run later', () async {
    registry = ModuleRegistry(
      modulesWith([
        const PostGenStep(
          ToolRef('firebase'),
          ['login'],
          description: 'Log in to Firebase',
          external: true,
          skippable: true,
        ),
      ]),
    );

    await smf([
      'create',
      'my_app',
      '-o',
      '/work',
      '-m',
      'extra',
      '--skip-external-setup',
    ]);

    expect(
      host.logger.warnings.last,
      'Log in to Firebase did not run, because the run skips external '
      'setup. Run it in the app later: firebase login',
    );
  });

  test('a failed generation exits with 1 and lists the problems', () async {
    registry = ModuleRegistry(
      modulesWith([
        BrickContribution(bundle('broken', files: {'lib/b.dart': '{{#a}}'})),
      ]),
    );

    expect(
      await smf(['create', 'my_app', '-o', '/work', '-m', 'extra']),
      SmfExitCodes.generationFailed,
    );
    expect(host.logger.errors, [
      'The app cannot be rendered because of an error.',
      startsWith('  error [extra] lib/b.dart: The template lib/b.dart'),
    ]);
  });

  test('an unexpected error exits with 70', () async {
    host = FakeHost(processRunner: runner, terminal: true);

    // The prompter has no answer for the name of the app.
    expect(await smf(['create']), SmfExitCodes.software);
    expect(
      host.logger.errors.single,
      startsWith('smf stopped because of an unexpected error: Bad state: '
          'Unexpected question'),
    );
    expect(host.logger.details.last, contains('cli_test.dart'));
  });
}
