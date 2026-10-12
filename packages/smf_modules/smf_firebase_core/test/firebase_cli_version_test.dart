@TestOn('vm')
library;

import 'package:file/memory.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support/fake_machine.dart';

const _dart = '/sdk/bin/dart';
const _firebase = '/opt/npm/bin/firebase';

/// `flutterfire configure` as the steps of the Flutter SDK run it.
const _configure = '$_dart pub global run flutterfire_cli:flutterfire '
    'configure --platforms=android,ios --overwrite-firebase-options '
    '--ios-bundle-id=com.example.my-app '
    '--android-package-name=com.example.my_app';

/// The step of [_RulesModule] as the pipeline runs it.
const _deploy = '$_firebase deploy --only storage';

/// The question whether to install the Firebase CLI, which the check of
/// firebase_core asks.
const _installFirebase = 'Firebase CLI is missing (needed by firebase_core). '
    'Install it with "npm install -g firebase-tools", or see '
    'https://firebase.google.com/docs/cli. Set it up now?';

/// How to update the Firebase CLI.
const _update = 'Update it with "npm install -g firebase-tools" if npm '
    'installed it, or see https://firebase.google.com/docs/cli#update-cli.';

/// The warning that the step of [_RulesModule] is not done, because of
/// [reason].
String _notDeployed(String reason) =>
    'Deploying the rules of the storage is not done, because $reason. Run it '
    'in the app: firebase deploy --only storage';

/// The path of the install script of the Firebase CLI in a command.
final _script = RegExp(r'/[^ ]*/install_firebase_\w+\.sh$');

/// A module of the tests that depends on firebase_core and continues its
/// step with a command of the Firebase CLI, as if its command needed
/// 15.6.0. As a module of another package would, it has the check of the
/// version in its own [Preflight], which its step needs.
final class _RulesModule extends SmfModule {
  const _RulesModule();

  static const id = ModuleId('firebase_rules');

  static const _version = FirebaseCliVersionCheck(minimum: '15.6.0');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Rules of the storage of Firebase',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FirebaseCoreModule.id},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const Preflight([_version]),
        PostGenStep(
          const ToolRef('firebase'),
          const ['deploy', '--only', 'storage'],
          followUpOf: FirebaseCoreModule.configureStep,
          description: 'Deploying the rules of the storage',
          skippable: true,
          external: true,
          needs: [_version.id],
        ),
      ];
}

/// A Mac with a Flutter SDK, flutterfire_cli 1.4.1 and Ruby with the gem
/// xcodeproj, on which `smf create` runs in a terminal; the app goes to
/// `/work/my_app`.
///
/// Its Firebase CLI, with a login that Google accepts, is in the version
/// given as `firebase`. Without one, the machine has no Firebase CLI until
/// the install script puts `firebase` 15.14.0 into `/opt/npm/bin`.
final class _Machine {
  _Machine({String? firebase, List<bool> confirmations = const []})
      : _version = firebase {
    files.directory('/sdk/bin/cache/dart-sdk').createSync(recursive: true);
    files.file('/sdk/bin/cache/flutter.version.json').writeAsStringSync(
          '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2"}',
        );
    for (final tool in [
      '/sdk/bin/flutter',
      _dart,
      '/bin/bash',
      '/bin/ruby',
      if (firebase != null) _firebase,
    ]) {
      files.file(tool).createSync(recursive: true);
    }
    files.directory('/work').createSync();
    files.currentDirectory = '/work';
    fake = FakeMachine(reply: _reply, confirmations: confirmations);
  }

  final files = MemoryFileSystem.test();
  late final FakeMachine fake;
  String? _version;

  SmfProcessResult _reply(Call call) {
    final line = call.line;
    if (_script.hasMatch(line)) {
      files.file(_firebase).createSync(recursive: true);
      _version = '15.14.0';
      return const SmfProcessResult(
        exitCode: 0,
        stdout: 'smf-bin-dir=/opt/npm/bin\n',
      );
    }
    return switch (line) {
      '$_firebase --version' =>
        SmfProcessResult(exitCode: 0, stdout: '$_version\n'),
      '$_firebase login:list --json' => const SmfProcessResult(
          exitCode: 0,
          stdout: '{"status": "success", "result": [{"user": {}}]}',
        ),
      '$_dart pub global list' => const SmfProcessResult(
          exitCode: 0,
          stdout: 'flutterfire_cli 1.4.1\n',
        ),
      _ when line.startsWith("/bin/ruby -e require 'xcodeproj'") =>
        const SmfProcessResult(exitCode: 0, stdout: '1.27.0'),
      _ => const SmfProcessResult(exitCode: 0),
    };
  }

  /// Runs `smf create my_app` with the modules [modules], in their order,
  /// and [options].
  Future<int> create(
    List<String> modules, [
    List<String> options = const [],
  ]) =>
      runSmf(
        [
          'create',
          'my_app',
          '-m',
          modules.join(','),
          '--org',
          'com.example',
          ...options,
        ],
        modules: const [
          FlutterCoreModule(),
          FirebaseCoreModule(),
          _RulesModule(),
        ],
        hostFor: ({required verbose}) => SmfHost(
          prompter: fake.prompter,
          processRunner: fake.processRunner,
          logger: fake.logger,
          fileSystem: files,
          environmentVariables: const {'PATH': '/sdk/bin:/bin:/opt/npm/bin'},
          operatingSystem: HostOperatingSystem.macos,
          hasTerminal: true,
        ),
      );

  /// The commands of the Firebase CLI and of flutterfire that ran, and the
  /// install script of the Firebase CLI.
  List<String> get commands => [
        for (final call in fake.calls)
          if (call.line.startsWith(_firebase) ||
              call.line == _configure ||
              _script.hasMatch(call.line))
            call.line.replaceFirst(_script, '<script>'),
      ];

  /// The warnings that the run printed.
  List<String> get warnings => _reports('warn: ');

  /// What the run printed as information, such as the lines of `--explain`.
  List<String> get infos => _reports('info: ');

  List<String> _reports(String kind) => [
        for (final report in fake.reports)
          if (report.startsWith(kind)) report.substring(kind.length),
      ];
}

/// The two orders in which the modules of an app may come: the module that
/// needs the version after firebase_core, and before it, as when the user
/// names only that module and the pipeline adds firebase_core for it.
const _orders = [
  ['firebase_core', 'firebase_rules'],
  ['firebase_rules'],
];

void main() {
  for (final modules in _orders) {
    group('with -m ${modules.join(',')}', () {
      test(
          'a Firebase CLI in the lowest version or a later one runs the step '
          'that needs it, after flutterfire configure', () async {
        for (final version in ['15.6.0', '15.14.0', '16.0.0']) {
          final machine = _Machine(firebase: version, confirmations: [true]);

          final code = await machine.create(modules);

          expect(
            code,
            SmfExitCodes.success,
            reason: machine.fake.reports.join('\n'),
          );
          expect(
            machine.commands,
            containsAllInOrder([_configure, _deploy]),
            reason: version,
          );
          expect(machine.warnings, isEmpty, reason: version);
        }
      });

      test(
          'an older Firebase CLI holds back only the step that needs the '
          'version, and nothing offers to update it', () async {
        const older = 'Firebase CLI 15.6.0 or later is needed, but $_firebase '
            'is 15.5.1';
        final machine = _Machine(firebase: '15.5.1', confirmations: [true]);

        final code = await machine.create(modules);

        expect(
          code,
          SmfExitCodes.success,
          reason: machine.fake.reports.join('\n'),
        );
        // Only the question of flutterfire configure, which the older
        // Firebase CLI can run.
        expect(machine.fake.questions, [
          startsWith('Configuring Firebase with flutterfire ('),
        ]);
        expect(machine.commands, contains(_configure));
        expect(machine.commands, isNot(contains(_deploy)));
        expect(machine.warnings, [
          endsWith('$older. $_update'),
          _notDeployed(older),
        ]);
      });

      test('--explain shows the older Firebase CLI, and offers nothing',
          () async {
        final machine = _Machine(firebase: '15.5.1');

        final code = await machine.create(modules, ['--explain']);

        expect(
          code,
          SmfExitCodes.success,
          reason: machine.fake.reports.join('\n'),
        );
        final lines = machine.infos;
        final check = lines.indexOf(
          '  ✗ Firebase CLI 15.6.0 or later (for firebase_rules): $_firebase '
          'is 15.5.1',
        );
        expect(check, isNonNegative, reason: lines.join('\n'));
        // How to update it, and no line that a run would offer to.
        expect(
          lines.skip(check + 1).takeWhile((line) => line.startsWith('    ')),
          ['    $_update'],
        );
        // The check of the Firebase CLI itself comes first, wherever the
        // user named its module: the check of the version builds on it.
        expect(
          lines.indexOf('  ✓ Firebase CLI (for firebase_core)'),
          inInclusiveRange(0, check - 1),
          reason: lines.join('\n'),
        );
        expect(machine.fake.questions, isEmpty);
      });

      test(
          'on a machine without the Firebase CLI, the installation that the '
          'check of firebase_core offers gives the module its version too',
          () async {
        final machine = _Machine(confirmations: [true, true]);

        final code = await machine.create(modules);

        expect(
          code,
          SmfExitCodes.success,
          reason: machine.fake.reports.join('\n'),
        );
        // One question about the Firebase CLI, of the check that can
        // install it.
        expect(machine.fake.questions, [
          _installFirebase,
          startsWith('Configuring Firebase with flutterfire ('),
        ]);
        expect(
          machine.commands,
          containsAllInOrder(['/bin/bash <script>', _configure, _deploy]),
        );
        expect(machine.warnings, isEmpty);
      });

      test(
          'a user who declines the installation is asked once, and the step '
          'is left for later with flutterfire configure', () async {
        final machine = _Machine(confirmations: [false]);

        final code = await machine.create(modules);

        expect(
          code,
          SmfExitCodes.success,
          reason: machine.fake.reports.join('\n'),
        );
        expect(machine.fake.questions, [_installFirebase]);
        expect(machine.commands, isEmpty);
        expect(
          machine.warnings,
          containsAll([
            endsWith(
              'Firebase CLI 15.6.0 or later is missing. Install it with "npm '
              'install -g firebase-tools", or see '
              'https://firebase.google.com/docs/cli.',
            ),
            _notDeployed(
              'it runs after "Configuring Firebase with flutterfire", which '
              'is not done',
            ),
          ]),
        );
      });
    });
  }
}
