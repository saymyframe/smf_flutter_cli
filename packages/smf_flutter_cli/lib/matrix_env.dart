/// How the apps of the matrices of SMF get the values that their modules
/// read, which a developer fills in after generating an app: from the env
/// role ([matrixEnv]).
///
/// It imports, of the packages of SMF, only the module model and the
/// matrix, so that the tools of the matrices of the fixtures take it
/// without the modules of the CLI. It serves the repository of SMF, and its
/// API may change in any release.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// How the apps of the matrices of SMF get their values, from the env
/// role: its file of the values, `.env`, into which the matrix writes the
/// values that the tests of an app give it (`MatrixAppTest.envValues`); the
/// arguments of `flutter test` that the provider of the role in an app
/// gives the role; and the keys of an app, each with the module or the role
/// whose template gives it. An app without the role has no arguments and no
/// keys.
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

/// The keys of the env role in [app], each with who gives it, from the data
/// of the roles of the app; none for an app that the contract harness did
/// not build.
Map<String, MatrixEnvKeyOwner> _envKeysOf(MatrixApp app) => switch (app.hook) {
      final hook? => {
          for (final key in envRole.keysIn(envRole.hookInput(hook)))
            key.name: _ownerOf(key.owner),
        },
      null => const {},
    };

/// The owner of a key whose origin is [origin]: only modules and the
/// templates of roles give the role keys.
MatrixEnvKeyOwner _ownerOf(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => (module: module, role: null),
      _ => (module: null, role: (origin as RoleTemplateOrigin).role.id),
    };
