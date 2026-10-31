// The commands of the CI of an app in the matrix: what they run from the CI
// role (matrixCi), the run of them in a clone of the app (runCiCommands, with
// real git and bash), which apps of a run of the matrix run them, and the run
// of them for an app of a job of CI (runCiOf).
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_ci.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'mode_registry.dart';

/// A provider of the CI role of the test, with a file of the commands.
final class _Pipelines extends SmfModule {
  const _Pipelines();

  static const id = ModuleId('pipelines');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'CI in a file of its own (test)',
        kind: ModuleKinds.infrastructure,
        providers: [_PipelinesProvider()],
      );
}

final class _PipelinesProvider extends RoleProvider<NoDsl> {
  const _PipelinesProvider();

  @override
  Role<NoDsl> get role => ciRole;

  @override
  RoleOutput render(RoleHookInput<NoDsl> input) {
    final CiPipeline(:checks, :build) = ciRole.pipelineIn(input);
    return RoleOutput(
      files: {
        'ci/pipeline.txt': [
          for (final check in checks) check.command,
          for (final environment in build.environments) ...[
            environment,
            ...build.keys,
            for (final command in build.prepare) command.command,
            build.command.of(environment),
            build.artifact.of(environment),
          ],
          '',
        ].join('\n'),
      },
    );
  }
}

/// A module of the test that gives the env role two keys.
final class _Shop extends SmfModule {
  const _Shop();

  static const id = ModuleId('shop');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The keys of a shop (test)',
        kind: ModuleKinds.infrastructure,
        requires: {envRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        envRole.data(const EnvKey('SHOP_KEY', description: 'The key')),
        envRole.data(const EnvKey('SHOP_URL', description: 'The address')),
      ];
}

/// A registry with an app without every module, next to the app with every
/// module and the app of the app entry alone.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  _Pipelines(),
  ModeModule(ModuleId('other')),
];

/// The app of [_Pipelines] among [_modules], the second of the matrix.
const _ofProvider = 'app_2';

/// Commands of the CI of an app of the tests of a run.
const _commands = MatrixCiCommands(
  checks: ['check one', 'check two'],
  build: MatrixCiBuild(
    commands: ['prepare', 'build'],
    keys: ['FIRST', 'SECOND', 'THIRD'],
    artifact: 'out/app.apk',
  ),
);

/// The first check of an app with the env role.
const _copyOfExample = '[ -f ${EnvRole.dotEnvFile} ] || '
    'cp ${EnvRole.exampleFile} ${EnvRole.dotEnvFile}';

void main() {
  group('matrixCi', () {
    test(
        'gives the commands of the role, the build for the first environment '
        'of the role and for one ABI, and the keys of the app', () async {
      final (:apps, :failed) = await matrixOf(const [
        FlutterCoreModule(),
        DartDefineModule(),
        _Pipelines(),
        _Shop(),
      ]);

      expect(failed, isEmpty);
      final withEnv = apps.singleWhere(
        (app) =>
            app.modules.contains(_Pipelines.id) &&
            app.modules.contains(DartDefineModule.id) &&
            app.everyModuleWith == null,
      );
      final ofApp = matrixCi(withEnv)!;
      const arguments = '--dart-define-from-file=${EnvRole.dotEnvFile}';
      const buildArguments = '$arguments --target-platform android-x64';
      expect(ofApp.checks, [
        _copyOfExample,
        'flutter pub get',
        'dart format --output=none --set-exit-if-changed lib test',
        'flutter analyze',
        'flutter test $arguments',
      ]);
      final environment = AppEntryRole.flavors.first.name;
      expect(ofApp.build.commands, [
        'dart ${CiRole.writeEnvFile}',
        'flutter pub get',
        'flutter build apk --release --flavor $environment $buildArguments',
      ]);
      expect(
        ofApp.build.artifact,
        'build/app/outputs/flutter-apk/app-$environment-release.apk',
      );

      final every = apps.singleWhere((app) => app.everyModuleWith != null);
      expect(matrixCi(every)!.build.keys, ['SHOP_KEY', 'SHOP_URL']);
    });

    test(
        'gives the commands of every app with every module of the CLI, whose '
        'job of CI fails on an app without them', () async {
      final (:apps, :failed) = await everyModuleAppsOf(smfModules);

      expect(failed, isEmpty);
      expect(apps, isNotEmpty);
      for (final app in apps) {
        expect(matrixCi(app), isNotNull, reason: app.name);
      }
    });

    test('gives nothing for an app without the role or without its data',
        () async {
      final (:apps, :failed) = await matrixOf(const [FlutterCoreModule()]);

      expect(failed, isEmpty);
      expect(matrixCi(apps.single), isNull);
      expect(matrixCi(const MatrixApp('by hand', [])), isNull);
    });
  });

  test('the values of a build are one in each form of a value of .env, in turn',
      () {
    expect(_commands.build.variables, {
      'FIRST': 'ci_value',
      'SECOND': 'a value # of CI',
      'THIRD': 'ci_value',
    });
  });

  group(
    'runCiCommands',
    () {
      late Directory temp;
      late String app;

      /// Writes the text of the file at [path] of the app.
      void write(String path, String text) => File('$app/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);

      setUp(() {
        temp = Directory.systemTemp.createTempSync('run_ci_commands_');
        app = '${temp.path}/an app';
        write('.gitignore', '.env\nbuild/\n');
        write('.env', 'KEY=of the developer\n');
        write('.env.example', 'KEY=\n');
        write('lib/main.dart', 'void main() {}\n');
        write('build/left.txt', 'left by a build\n');
      });
      tearDown(() => temp.deleteSync(recursive: true));

      test('runs in a clone with what git has of the app, and nothing else',
          () async {
        final (code, output) = await runCiCommands(app, [
          '[ -f lib/main.dart ] && [ -f .env.example ] && [ -f .gitignore ]',
          '[ ! -e .env ] && [ ! -e build ]',
          'git log --oneline | wc -l | tr -d " "',
        ]);

        expect(output, contains('\n1\n'));
        expect(code, 0, reason: output);
      });

      test(
          'fails on a command that needs a file which git keeps out, names '
          'it, and runs no command after it', () async {
        final (code, output) = await runCiCommands(app, [
          'echo first',
          'cat .env && echo printed',
          'echo after',
        ]);

        expect(code, isNonZero);
        expect(output, contains('first'));
        expect(output, contains('No such file'));
        expect(output, isNot(contains('\nprinted')));
        expect(output, isNot(contains('\nafter')));
        expect(
          output.trim().split('\n').last,
          'This command of CI exited with $code: cat .env && echo printed',
        );
      });

      test('leaves the app as it was, and no clone behind', () async {
        final before = _filesOf(app);

        final (code, output) = await runCiCommands(app, [
          'touch lib/new.dart',
          'rm .gitignore',
          'pwd',
        ]);

        expect(code, 0, reason: output);
        expect(_filesOf(app), before);
        expect(Directory('$app/.git').existsSync(), isFalse);
        final clone = output.trim().split('\n').last;
        expect(clone, endsWith('/app'));
        expect(Directory(clone).existsSync(), isFalse);
      });

      test(
          'leaves the objects of a large app where the clone finds them: the '
          'commit starts no maintenance of git in the background', () async {
        for (var index = 0; index < 1500; index++) {
          write('lib/part_$index.dart', '// Part $index.\n');
        }

        // Git 2.54 packs loose objects a moment after a commit, in a process
        // of its own, when it counts two or more in `objects/17`: a matter of
        // the hashes in an app of a few hundred files, and sure in one of this
        // size. It then removes them while the clone copies them, and adds
        // files while the temporary directory is removed. The repository is
        // next to the clone.
        final (code, output) = await runCiCommands(app, [
          'sleep 2 && ! ls ../repository/objects/pack/*.pack',
        ]);

        expect(code, 0, reason: output);
      });

      test('a command can do what a later command of the clone reads',
          () async {
        final (code, output) = await runCiCommands(app, [
          'cp .env.example .env',
          'grep -q KEY= .env',
        ]);

        expect(code, 0, reason: output);
      });

      test('gives the commands the variables, as they are', () async {
        final (code, output) = await runCiCommands(
          app,
          [r'''[ "$FIRST" = 'a $HOME # value' ]'''],
          environment: {'FIRST': r'a $HOME # value'},
        );

        expect(code, 0, reason: output);
      });

      test('has what a command prints in both of its streams', () async {
        final (_, output) = await runCiCommands(app, [
          'echo to out; echo to error >&2',
        ]);

        expect(output, contains(r'$ echo to out; echo to error >&2'));
        expect(output, contains('to out\n'));
        expect(output, contains('to error\n'));
      });

      test('fails when the commands left no such file as the artifact',
          () async {
        final made = await runCiCommands(
          app,
          ['mkdir -p out && touch out/app.apk'],
          artifact: 'out/app.apk',
        );
        expect(made.$1, 0, reason: made.$2);

        final (code, output) = await runCiCommands(
          app,
          ['mkdir -p out'],
          artifact: 'out/app.apk',
        );
        expect(code, 1);
        expect(
          output.trim().split('\n').last,
          'The commands of CI left no file out/app.apk.',
        );
      });

      test('runs no command when git cannot make the clone', () async {
        final empty = '${temp.path}/empty';
        Directory(empty).createSync();

        final (code, output) = await runCiCommands(empty, ['echo ran']);

        expect(code, isNonZero);
        expect(output, isNot(contains('ran\n')));
        expect(output, contains('so no command of CI ran.'));
      });
    },
    // bash of a runner of Windows may be that of a subsystem without a
    // Flutter SDK, and no job on Windows runs the commands of CI.
    testOn: '!windows',
  );

  group('a run of the matrix', () {
    late List<String> log;
    late List<String> ran;

    setUp(() {
      log = [];
      ran = [];
    });

    Future<int> run(
      List<SmfModule> modules, {
      MatrixCi? ci,
    }) =>
        runMatrix(
          modules,
          directory: '/apps',
          ci: ci,
          commands: MatrixCommands(
            log: log.add,
            create: (arguments, onCreated) async {
              onCreated(
                GeneratedApp(
                  name: arguments[1],
                  path: '/apps/${arguments[1]}',
                ),
              );
              return 0;
            },
            analyze: (directory) async {
              ran.add('analyze $directory');
              return (0, '');
            },
            test: (generated, app, tests, {env}) async {
              ran.add('test ${generated.path}');
              return (0, '');
            },
            ci: (
              directory,
              commands, {
              environment = const {},
              artifact,
            }) async {
              ran.add('ci $directory: ${commands.join(', ')}');
              expect(environment, isEmpty);
              expect(artifact, isNull);
              return (0, 'Ran the commands in $directory');
            },
          ),
        );

    test('runs the checks of an app of a provider after its analysis',
        () async {
      expect(await run(_modules, ci: _onlyOfProvider), 0);

      expect(
        ran,
        containsAllInOrder([
          'analyze /apps/$_ofProvider',
          'ci /apps/$_ofProvider: check one, check two',
        ]),
      );
      expect(ran.where((line) => line.startsWith('ci ')), hasLength(1));
      expect(log, contains('Ran the commands in /apps/$_ofProvider'));
    });

    test('runs nothing without CI, for the app or for the run', () async {
      expect(await run(_modules), 0);
      expect(await run(_modules, ci: (_) => null), 0);

      expect(ran.where((line) => line.startsWith('ci ')), isEmpty);
    });

    test(
        'fails when a command fails, and still runs the tests of the app, '
        'whose failure tells something else', () async {
      final code = await runMatrix(
        _modules,
        directory: '/apps',
        selection: const MatrixSelection(only: {'pipelines'}),
        appTests: MatrixAppTests([
          MatrixAppTest('/tests/all', appliesTo: (_) => true),
        ]),
        ci: (_) => _commands,
        commands: MatrixCommands(
          log: log.add,
          create: (arguments, onCreated) async {
            onCreated(
              GeneratedApp(name: arguments[1], path: '/apps/${arguments[1]}'),
            );
            return 0;
          },
          analyze: (_) async => (0, ''),
          test: (generated, app, tests, {env}) async {
            ran.add('test ${generated.path}');
            return (0, '');
          },
          ci: (directory, commands, {environment = const {}, artifact}) async {
            ran.add('ci $directory');
            return (7, 'A command failed');
          },
        ),
      );

      expect(code, 1);
      expect(ran, ['ci /apps/$_ofProvider', 'test /apps/$_ofProvider']);
      expect(
        log,
        contains(
          endsWith('a command of its CI exited with 7 in a clone of the app.'),
        ),
      );
    });

    test('leaves out the apps with every module', () async {
      final (:apps, failed: _) = await matrixOf(_modules);
      final every = apps.indexWhere((app) => app.everyModuleWith != null);
      expect(every, isNonNegative);

      expect(await run(_modules, ci: (_) => _commands), 0);

      expect(ran, contains('analyze /apps/app_${every + 1}'));
      expect(ran, isNot(contains(startsWith('ci /apps/app_${every + 1}:'))));
      expect(
        ran.where((line) => line.startsWith('ci ')),
        hasLength(apps.length - 1),
      );
    });

    test(
        'leaves out the apps of the other values of a mode option, and keeps '
        'the app of its first value', () async {
      const lock = ModuleId('lock');
      const modules = [
        FlutterCoreModule(),
        ModeModule(lock, provides: {doors}),
        ModeModule(ModuleId('other')),
      ];
      final (:apps, failed: _) = await matrixOf(modules);
      final first = apps.indexWhere(
        (app) =>
            app.modules.contains(lock) &&
            app.modes.isEmpty &&
            app.everyModuleWith == null,
      );
      final other = apps.indexWhere(
        (app) => app.modes.isNotEmpty && app.everyModuleWith == null,
      );
      expect(first, isNonNegative);
      expect(other, isNonNegative);

      expect(await run(modules, ci: (_) => _commands), 0);

      expect(ran, contains(startsWith('ci /apps/app_${first + 1}:')));
      expect(ran, contains('analyze /apps/app_${other + 1}'));
      expect(ran, isNot(contains(startsWith('ci /apps/app_${other + 1}:'))));
    });

    test(
      'by default runs them in a clone of the app, which has no file that '
      'the .gitignore of the app keeps out',
      () async {
        final temp = Directory.systemTemp.createTempSync('run_matrix_ci_');
        addTearDown(() => temp.deleteSync(recursive: true));
        final code = await runMatrix(
          _modules,
          directory: temp.path,
          selection: const MatrixSelection(only: {'pipelines'}),
          ci: (_) => const MatrixCiCommands(
            checks: ['cat .env'],
            build: MatrixCiBuild(commands: [], keys: [], artifact: ''),
          ),
          commands: MatrixCommands(
            log: log.add,
            create: (arguments, onCreated) async {
              final path = '${temp.path}/${arguments[1]}';
              File('$path/.gitignore')
                ..createSync(recursive: true)
                ..writeAsStringSync('.env\n');
              File('$path/.env').writeAsStringSync('KEY=\n');
              onCreated(GeneratedApp(name: arguments[1], path: path));
              return 0;
            },
            analyze: (_) async => (0, ''),
          ),
        );

        expect(code, 1);
        expect(log.last, contains('a command of its CI exited with 1'));
        expect(log, contains(contains('No such file')));
      },
      testOn: '!windows',
    );
  });

  group('runCiOf', () {
    late List<String> log;
    late List<(List<String>, Map<String, String>, String?)> runs;

    setUp(() {
      log = [];
      runs = [];
    });

    Future<int> run({
      required bool build,
      MatrixCi ci = _ciOfEveryApp,
      List<int> codes = const [0, 0],
    }) =>
        runCiOf(
          const MatrixApp('an app', []),
          directory: '/apps/an app',
          ci: ci,
          build: build,
          commands: MatrixCommands(
            log: log.add,
            ci: (
              directory,
              commands, {
              environment = const {},
              artifact,
            }) async {
              expect(directory, '/apps/an app');
              runs.add((commands, environment, artifact));
              return (codes[runs.length - 1], 'Run ${runs.length}');
            },
          ),
        );

    test('runs the checks alone without a build', () async {
      expect(await run(build: false), 0);

      expect(runs, hasLength(1));
      final (commands, environment, artifact) = runs.single;
      expect(commands, ['check one', 'check two']);
      expect(environment, isEmpty);
      expect(artifact, isNull);
      expect(log, ['Run 1']);
    });

    test(
        'with a build, runs it after them on its own, with the values and the '
        'file of the build', () async {
      expect(await run(build: true), 0);

      expect(runs, hasLength(2));
      final (commands, environment, artifact) = runs.last;
      expect(commands, ['prepare', 'build']);
      expect(environment, _commands.build.variables);
      expect(artifact, 'out/app.apk');
      expect(log, ['Run 1', 'Run 2']);
    });

    test('builds nothing after a check that failed', () async {
      expect(await run(build: true, codes: const [3]), 1);

      expect(runs, hasLength(1));
    });

    test('fails on a check that failed without a build', () async {
      expect(await run(build: false, codes: const [3]), 1);
    });

    test('fails on a build that failed', () async {
      expect(await run(build: true, codes: const [0, 3]), 1);
    });

    test('fails on an app without CI, whose run would check nothing', () async {
      expect(await run(build: true, ci: (_) => null), 1);

      expect(runs, isEmpty);
      expect(log, ['an app has no commands of CI to run.']);
    });

    test(
      'by default builds in a clone of its own, without the file that a '
      'check wrote',
      () async {
        final temp = Directory.systemTemp.createTempSync('run_ci_of_');
        addTearDown(() => temp.deleteSync(recursive: true));
        File('${temp.path}/.env.example').writeAsStringSync('KEY=\n');

        final code = await runCiOf(
          const MatrixApp('an app', []),
          directory: temp.path,
          ci: (_) => const MatrixCiCommands(
            checks: ['cp .env.example .env'],
            build: MatrixCiBuild(
              commands: [
                '[ ! -e .env ]',
                r'[ "$KEY" = ci_value ] && touch app.apk',
              ],
              keys: ['KEY'],
              artifact: 'app.apk',
            ),
          ),
          build: true,
          commands: MatrixCommands(log: log.add),
        );

        expect(code, 0, reason: log.join('\n'));
      },
      testOn: '!windows',
    );
  });
}

MatrixCiCommands? _ciOfEveryApp(MatrixApp app) => _commands;

/// [_commands] for the app of [_Pipelines] alone among those of [_modules].
MatrixCiCommands? _onlyOfProvider(MatrixApp app) =>
    app.modules.contains(_Pipelines.id) && app.everyModuleWith == null
        ? _commands
        : null;

/// The paths and texts of the files below [directory].
Map<String, String> _filesOf(String directory) => {
      for (final file
          in Directory(directory).listSync(recursive: true).whereType<File>())
        file.path: file.readAsStringSync(),
    };
