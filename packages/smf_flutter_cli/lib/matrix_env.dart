/// How the apps of the matrices of SMF get the values that their modules
/// read, which a developer fills in after generating an app: from the env
/// role ([matrixEnv]). It also has the arguments with which CI starts an app
/// as a release, from the app entry role ([startReleaseBuildArguments]).
///
/// It imports, of the packages of SMF, only the module model and the
/// matrix, so that the tools of the matrices of the fixtures take it
/// without the modules of the CLI. It serves the repository of SMF, and its
/// API may change in any release.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// The name of the value of the build with which the start of an app on a
/// device tells the probe of the flavor of the app that it asked for a flavor
/// (`app_tests/flavors`). A build without it asks for none.
const startFlavorDefine = 'SMF_START_FLAVOR';

/// The arguments of the `flutter` tool that a build of an app as a release
/// takes too when CI starts it on a device, which the script of CI reads
/// (`startReleaseArgumentsFile`): the flavor that the app entry role names
/// for a release, since a command without `--flavor` builds its default
/// flavor in release mode too, and the same flavor for the probe of the
/// flavor, which sees whether it reached the app. So the script names no
/// flavor, and the release app that it starts is the one that a user gets.
final List<String> startReleaseBuildArguments = [
  '--flavor',
  AppEntryRole.releaseFlavor.name,
  '--dart-define=$startFlavorDefine=${AppEntryRole.releaseFlavor.name}',
];

/// How the apps of the matrices of SMF get their values, from the env
/// role: its file of the values, `.env`, into which the matrix writes the
/// values that the tests of an app give it (`MatrixAppTest.envValues`); the
/// arguments of `flutter test` that the provider of the role in an app
/// gives the role; and the keys of an app, each with the module that gives
/// it. An app without the role has no arguments and no keys.
///
/// The tools of the matrices of the CLI, of the fixtures, of the app of
/// several providers and of the apps whose tests must fail give it to the
/// runs and to the report of their tests, which know no role themselves.
const matrixEnv = MatrixEnv(
  file: EnvRole.dotEnvFile,
  toolArguments: _envToolArgumentsOf,
  keys: _envKeysOf,
);

/// The arguments of the commands of the `flutter` tool that the provider of
/// the env role of [app] gives the role, from the data of the roles of the
/// app; none for an app that the contract harness did not build, which has
/// no such data.
List<String> _envToolArgumentsOf(MatrixApp app) => switch (app.hook) {
      final hook? => envRole.toolArgumentsIn(envRole.hookInput(hook)),
      null => const [],
    };

/// The keys of the env role in [app], each with the module that gives it,
/// from the data of the roles of the app; none for an app that the contract
/// harness did not build.
Map<String, ModuleId> _envKeysOf(MatrixApp app) => switch (app.hook) {
      final hook? => {
          for (final key in envRole.keysIn(envRole.hookInput(hook)))
            // Only modules give the role keys: its template refuses a key
            // of the template of a role, and the harness builds no app with
            // one.
            key.name: (key.owner as ModuleOrigin).module,
        },
      null => const {},
    };
