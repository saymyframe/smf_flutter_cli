// tool/configure_firebase.dart of the app, run with the Dart SDK: a stand-in
// for flutterfire_cli, activated in a pub cache of the test, notes each run and
// writes what flutterfire writes. So the test needs no network and no knob in
// the generated script, which finds flutterfire as on the machine of a user.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The stand-in for flutterfire. It notes its arguments, the variable CI,
/// whether it has a terminal and its directory, as one line of JSON for each
/// run, writes the options unformatted, and adds the options to firebase.json
/// under the project of its arguments, or the one that a user would choose. It
/// exits with the code in FAKE_FLUTTERFIRE_FAILS at the run of the number in
/// FAKE_FLUTTERFIRE_FAILS_AT.
const _standIn = r"""
import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final environment = Platform.environment;
  final log = File(environment['FAKE_FLUTTERFIRE_LOG']!);
  final run = log.existsSync() ? log.readAsLinesSync().length + 1 : 1;
  log.writeAsStringSync(
    '${jsonEncode({
      'arguments': arguments,
      'ci': environment['CI'],
      'terminal': stdin.hasTerminal,
      'directory': Directory.current.resolveSymbolicLinksSync(),
    })}\n',
    mode: FileMode.append,
  );
  if (environment['FAKE_FLUTTERFIRE_FAILS_AT'] == '$run') {
    exitCode = int.parse(environment['FAKE_FLUTTERFIRE_FAILS']!);
    return;
  }
  String? valueOf(String option) {
    String? value;
    for (final argument in arguments) {
      if (argument.startsWith('--$option=')) {
        value = argument.substring(option.length + 3);
      }
    }
    return value;
  }

  final out = valueOf('out')!;
  File(out)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      environment['FAKE_FLUTTERFIRE_OPTIONS'] ?? 'const   options   =   1  ;\n',
    );
  if (environment['FAKE_FLUTTERFIRE_NO_PROJECT'] == '1') return;
  final file = File('firebase.json');
  final json = file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, Object?>
      : {'flutter': {'platforms': {'dart': <String, Object?>{}}}};
  // ignore: avoid_dynamic_calls
  (json['flutter'] as dynamic)['platforms']['dart'][out] = {
    'projectId': valueOf('project') ?? 'chosen-project',
  };
  file.writeAsStringSync(jsonEncode(json));
}
""";

/// The arguments of each run of flutterfire for [flavor] of the app with
/// [identity], in the project [project], with [others] after them.
List<List<String>> _runsOf(
  AppFlavor flavor,
  AppIdentity identity, {
  String? project = 'my-project',
  List<String> others = const [],
}) {
  // flutterfire changes the Xcode project only on macOS.
  final configurations = Platform.isMacOS
      ? flavor.xcodeConfigurations
      : flavor.xcodeConfigurations.take(1);
  var run = 0;
  return [
    for (final configuration in configurations)
      [
        'configure',
        if (project != null)
          '--project=$project'
        else if (run++ > 0)
          '--project=chosen-project',
        '--platforms=android,ios',
        '--overwrite-firebase-options',
        '--out=lib/firebase_options_${flavor.name}.dart',
        '--android-package-name=${flavor.applicationIdIn(identity)}',
        '--android-out=android/app/src/${flavor.name}/google-services.json',
        '--ios-bundle-id=${flavor.bundleIdIn(identity)}',
        '--ios-out=ios/flavors/${flavor.name}/GoogleService-Info.plist',
        '--ios-build-config=$configuration',
        ...others,
      ],
  ];
}

void main() {
  final identity = ContractHarness.defaultContext.appIdentity;
  const configureScript = FirebaseCoreModule.configureScript;
  const hooks = FirebaseCoreModule.configuredHooksDirectory;
  const dev = AppEntryRole.defaultFlavor;
  const prod = AppEntryRole.releaseFlavor;

  late String script;
  late Directory root;
  late String pubCache;

  setUpAll(() async {
    const modules = [FlutterCoreModule(), FirebaseCoreModule()];
    final result = await ContractHarness(ModuleRegistry(modules)).check(
      const ContractCase('firebase_core', requested: [FirebaseCoreModule.id]),
    );
    expect(result.errors, isEmpty);
    script = result.app!.files[configureScript]!.text;

    root = Directory.systemTemp.createTempSync('smf_configure_script');
    pubCache = '${root.path}/pub_cache';
    final standIn = Directory('${root.path}/flutterfire_cli')..createSync();
    File('${standIn.path}/pubspec.yaml').writeAsStringSync('''
name: flutterfire_cli
version: 1.4.1
environment:
  sdk: ">=3.6.0 <4.0.0"
executables:
  flutterfire: flutterfire
''');
    File('${standIn.path}/bin/flutterfire.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(_standIn);
    final activated = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'global', 'activate', '--source', 'path', standIn.path],
      environment: {'PUB_CACHE': pubCache},
    );
    expect(activated.exitCode, 0, reason: '${activated.stderr}');
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  /// A new app with the script, in a directory with a space and a letter
  /// beyond ASCII in its name, as the jobs of CI have it.
  Directory newApp({String? scriptText}) {
    final parent = root.createTempSync('apps é ');
    final app = Directory('${parent.path}/my_app')..createSync();
    File('${app.path}/$configureScript')
      ..createSync(recursive: true)
      ..writeAsStringSync(scriptText ?? script);
    return app;
  }

  /// A hook of [app] named [name] that notes its name in `hooks.log` and what
  /// it finds in the options of [flavor], and exits with [code].
  void addHook(
    Directory app,
    String name, {
    int code = 0,
    AppFlavor flavor = dev,
  }) {
    File('${app.path}/$hooks/$name')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
import 'dart:io';

void main() {
  File('hooks.log').writeAsStringSync(
    '$name in \${Directory.current.resolveSymbolicLinksSync()}: '
    '\${File('lib/firebase_options_${flavor.name}.dart').readAsStringSync()}',
    mode: FileMode.append,
  );
  exitCode = $code;
}
''');
  }

  /// The environment of a run in [app].
  Map<String, String> environmentOf(
    Directory app,
    Map<String, String> others,
  ) =>
      {
        'PUB_CACHE': pubCache,
        'FAKE_FLUTTERFIRE_LOG': '${app.path}.log',
        ...others,
      };

  /// Runs the script in [app] without a terminal.
  Future<ProcessResult> runScript(
    Directory app,
    List<String> arguments, {
    Map<String, String> environment = const {},
  }) =>
      Process.run(
        Platform.resolvedExecutable,
        [configureScript, ...arguments],
        workingDirectory: app.path,
        environment: environmentOf(app, environment),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  /// What the stand-in noted of each run in [app].
  List<Map<String, Object?>> runsIn(Directory app) {
    final log = File('${app.path}.log');
    return !log.existsSync()
        ? const []
        : [
            for (final line in log.readAsLinesSync())
              jsonDecode(line) as Map<String, Object?>,
          ];
  }

  /// The arguments of each run in [app].
  List<Object?> argumentsIn(Directory app) =>
      [for (final run in runsIn(app)) run['arguments']];

  /// The hooks that ran in [app], and what each found.
  String hooksLogOf(Directory app) {
    final file = File('${app.path}/hooks.log');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  group('in a run without a terminal', () {
    for (final flavor in AppEntryRole.flavors) {
      test(
          'runs flutterfire with the ids and the files of ${flavor.name}, '
          'once for each build configuration on macOS and once elsewhere, '
          'in the directory of the app', () async {
        final app = newApp();

        final result = await runScript(app, [
          flavor.name,
          '--project=my-project',
        ]);

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(argumentsIn(app), _runsOf(flavor, identity));
        final directory = app.resolveSymbolicLinksSync();
        for (final run in runsIn(app)) {
          expect(run['directory'], directory);
          // So that flutterfire fails rather than wait for an answer.
          expect(run['ci'], 'true');
          expect(run['terminal'], isFalse);
        }
        expect(
          result.stdout,
          contains(
            'Configured the flavor ${flavor.name} for the Firebase project '
            'my-project.',
          ),
        );
      });
    }

    test('takes the project in each form that flutterfire reads, the last one',
        () async {
      for (final arguments in const [
        ['--project=my-project'],
        ['--project', 'my-project'],
        ['-p', 'my-project'],
        ['-pmy-project'],
        ['--project=another', '-p', 'my-project'],
      ]) {
        final app = newApp();

        final result = await runScript(app, [dev.name, ...arguments]);

        expect(result.exitCode, 0, reason: '$arguments ${result.stderr}');
        expect(argumentsIn(app), _runsOf(dev, identity), reason: '$arguments');
      }
    });

    test('gives the other arguments to flutterfire as they are', () async {
      final app = newApp();
      const others = ['--account=me@example.com', '--service-account', 'a b'];

      final result = await runScript(
        app,
        [dev.name, '--project=my-project', ...others],
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(argumentsIn(app), _runsOf(dev, identity, others: others));
    });

    test(
        'with --platforms=android, runs flutterfire once and gives it nothing '
        'of iOS, on macOS too', () async {
      for (final platforms in const [
        ['--platforms=android'],
        ['--platforms', 'android'],
      ]) {
        final app = newApp();

        final result = await runScript(
          app,
          [dev.name, '--project=my-project', ...platforms],
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(argumentsIn(app), [
          [
            'configure',
            '--project=my-project',
            '--platforms=android,ios',
            '--overwrite-firebase-options',
            '--out=lib/firebase_options_dev.dart',
            '--android-package-name=${dev.applicationIdIn(identity)}',
            '--android-out=android/app/src/dev/google-services.json',
            ...platforms,
          ],
        ]);
      }
    });

    test('with --platforms=ios, gives flutterfire nothing of Android',
        () async {
      final app = newApp();

      final result = await runScript(
        app,
        [dev.name, '--project=my-project', '--platforms=ios'],
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final runs = argumentsIn(app);
      expect(runs, hasLength(Platform.isMacOS ? 3 : 1));
      for (final run in runs.cast<List<Object?>>()) {
        expect(run, isNot(contains(startsWith('--android'))));
        expect(run, contains('--ios-bundle-id=${dev.bundleIdIn(identity)}'));
      }
    });

    test('stops before any run without a project, since nobody can answer',
        () async {
      final app = newApp();

      final result = await runScript(app, [dev.name]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('--project=<id>'));
      expect(runsIn(app), isEmpty);
    });

    test('stops at a project option without a value', () async {
      for (final arguments in const [
        ['--project'],
        ['-p'],
        ['--project='],
      ]) {
        final app = newApp();

        final result = await runScript(app, [dev.name, ...arguments]);

        expect(result.exitCode, 1, reason: '$arguments');
        expect(result.stderr, contains('needs the id of a Firebase project'));
        expect(runsIn(app), isEmpty);
      }
    });

    test('stops without a flavor or at an unknown one, and names the flavors',
        () async {
      final names = AppEntryRole.flavors.map((flavor) => flavor.name).join('|');
      for (final arguments in const [
        <String>[],
        ['other', '--project=my-project'],
        ['--project=my-project'],
      ]) {
        final app = newApp();

        final result = await runScript(app, arguments);

        expect(result.exitCode, 1, reason: '$arguments');
        expect(result.stderr, contains('<$names>'));
        expect(runsIn(app), isEmpty);
      }
    });

    test('stops at an id that flutterfire refuses, and says what to do',
        () async {
      // flutterfire allows no underscore in the first part of an application
      // id, as for --org my_org, and would otherwise read the id of another
      // flavor from the files of the app.
      final android = newApp(
        scriptText: script.replaceAll(
          identity.androidApplicationId,
          'my_org.contract_app',
        ),
      );
      final refusedAndroid = await runScript(
        android,
        [dev.name, '--project=my-project'],
      );
      expect(refusedAndroid.exitCode, 1);
      expect(
        refusedAndroid.stderr,
        allOf(contains('my_org.contract_app.dev'), contains('another org')),
      );
      expect(runsIn(android), isEmpty);
      // But a run for the other platform does not need it.
      final onlyIos = await runScript(
        android,
        [dev.name, '--project=my-project', '--platforms=ios'],
      );
      expect(onlyIos.exitCode, 0, reason: '${onlyIos.stderr}');

      // No hyphen at the end of a part of a bundle id, as for --org com.acme_.
      final ios = newApp(
        scriptText: script.replaceAll(
          identity.iosBundleId,
          'com.acme-.contract-app',
        ),
      );
      final refusedIos = await runScript(
        ios,
        [dev.name, '--project=my-project'],
      );
      expect(refusedIos.exitCode, 1);
      expect(
        refusedIos.stderr,
        allOf(contains('com.acme-.contract-app.dev'), contains('another org')),
      );
      expect(runsIn(ios), isEmpty);
    });

    test(
        'stops at the first run of flutterfire that fails, with its exit '
        'code, runs nothing after it, and tells what stays', () async {
      final runs = Platform.isMacOS ? 2 : 1;
      final app = newApp();
      addHook(app, 'a.dart');

      final result = await runScript(
        app,
        [dev.name, '--project=my-project'],
        environment: {
          'FAKE_FLUTTERFIRE_FAILS_AT': '$runs',
          'FAKE_FLUTTERFIRE_FAILS': '7',
        },
      );

      expect(result.exitCode, 7);
      expect(runsIn(app), hasLength(runs));
      expect(
        result.stderr,
        allOf(
          contains('flutterfire failed for the flavor dev (exit code 7)'),
          contains('running this script again does the rest'),
          contains('the section Firebase of README.md'),
        ),
      );
      expect(hooksLogOf(app), isEmpty);
      expect(result.stdout, isNot(contains('Configured the flavor')));
    });

    test('formats the options of the flavor, and only those, before the hooks',
        () async {
      final app = newApp();
      addHook(app, 'a.dart', flavor: prod);
      final other = File('${app.path}/lib/firebase_options_dev.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('const   other   =   1  ;\n');

      final result = await runScript(
        app,
        [prod.name, '--project=my-project'],
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        File('${app.path}/lib/firebase_options_prod.dart').readAsStringSync(),
        'const options = 1;\n',
      );
      expect(other.readAsStringSync(), 'const   other   =   1  ;\n');
      expect(hooksLogOf(app), endsWith(': const options = 1;\n'));
    });

    test(
        'only warns when the options do not format, and goes on with the '
        'hooks', () async {
      final app = newApp();
      addHook(app, 'a.dart');
      const broken = 'const options = ;\n';

      final result = await runScript(
        app,
        [dev.name, '--project=my-project'],
        environment: {'FAKE_FLUTTERFIRE_OPTIONS': broken},
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        result.stderr,
        contains(
          'Warning: dart format left lib/firebase_options_dev.dart as '
          'flutterfire wrote it',
        ),
      );
      expect(hooksLogOf(app), endsWith(': $broken'));
      expect(result.stdout, contains('Configured the flavor dev'));
    });

    test(
        'runs each Dart file of the hooks directory after the last run, by '
        'the order of the names, in the directory of the app', () async {
      final app = newApp();
      addHook(app, 'b.dart');
      addHook(app, 'a.dart');
      File('${app.path}/$hooks/notes.txt').writeAsStringSync('no hook');
      Directory('${app.path}/$hooks/directory.dart').createSync();

      final result = await runScript(app, [dev.name, '--project=my-project']);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final directory = app.resolveSymbolicLinksSync();
      expect(
        hooksLogOf(app).split('const options = 1;\n'),
        ['a.dart in $directory: ', 'b.dart in $directory: ', ''],
      );
      expect(runsIn(app), hasLength(Platform.isMacOS ? 3 : 1));
    });

    test(
        'needs no hooks directory, as an app has none whose modules have '
        'nothing to do after flutterfire', () async {
      final app = newApp();

      final result = await runScript(app, [dev.name, '--project=my-project']);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(Directory('${app.path}/$hooks').existsSync(), isFalse);
      expect(result.stdout, contains('Configured the flavor dev'));
    });

    test('stops at a hook that fails, with its exit code', () async {
      final app = newApp();
      addHook(app, 'a.dart', code: 3);
      addHook(app, 'b.dart');

      final result = await runScript(app, [dev.name, '--project=my-project']);

      expect(result.exitCode, 3);
      expect(hooksLogOf(app), startsWith('a.dart'));
      expect(hooksLogOf(app), isNot(contains('b.dart')));
      expect(
        result.stderr,
        allOf(
          contains('a.dart failed (exit code 3)'),
          contains('running this script again runs it again'),
        ),
      );
      expect(result.stdout, isNot(contains('Configured the flavor')));
    });
  });

  group(
    'in a terminal',
    () {
      /// Runs the script in [app] under `script`, which gives it a terminal.
      Future<ProcessResult> runInTerminal(
        Directory app,
        List<String> arguments, {
        Map<String, String> environment = const {},
      }) async {
        final command = [
          Platform.resolvedExecutable,
          configureScript,
          ...arguments,
        ];
        return Process.run(
          'script',
          Platform.isMacOS
              ? ['-q', '/dev/null', ...command]
              : [
                  '-qec',
                  command.map((word) => "'$word'").join(' '),
                  '/dev/null',
                ],
          workingDirectory: app.path,
          environment: environmentOf(app, environment),
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
      }

      test(
          'leaves the project to flutterfire in its first run, and gives the '
          'next runs the project that it wrote', () async {
        final app = newApp();

        final result = await runInTerminal(app, [dev.name]);

        expect(result.exitCode, 0, reason: '${result.stdout}');
        expect(argumentsIn(app), _runsOf(dev, identity, project: null));
        for (final run in runsIn(app)) {
          // flutterfire keeps its questions.
          expect(run['terminal'], isTrue);
        }
        expect(
          result.stdout,
          contains(
            'Configured the flavor dev for the Firebase project chosen-project',
          ),
        );
      });

      test(
          'stops when flutterfire succeeded and firebase.json names no project '
          'for the flavor', () async {
        final app = newApp();

        final result = await runInTerminal(
          app,
          [dev.name],
          environment: {'FAKE_FLUTTERFIRE_NO_PROJECT': '1'},
        );

        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(
          result.stdout,
          contains('names no Firebase project for the flavor dev'),
        );
        expect(runsIn(app), hasLength(1));
      });
    },
    skip: Platform.isWindows ? 'Windows has no command script.' : null,
  );
}
