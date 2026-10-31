/// What the matrices of SMF run of the CI of an app: its commands, from the
/// CI role ([matrixCi]).
///
/// It imports, of the packages of SMF, only the module model and the matrix,
/// so that the tools of the matrices of the fixtures take it without the
/// modules of the CLI. It serves the repository of SMF, and its API may change
/// in any release.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// The commands of the CI of [app], from the CI role: those of each push, and
/// those that build the app for the first environment of the role; `null` for
/// an app without the role, and for one that the contract harness did not
/// build, which has no data of its roles.
///
/// The build is for x86_64 alone, as the release app that CI starts on an
/// emulator, so that a job of CI downloads no engine of a release for another
/// ABI, which would show nothing more of the commands. The file that the build
/// writes keeps its name.
MatrixCiCommands? matrixCi(MatrixApp app) {
  final hook = app.hook;
  if (hook == null || !hook.presentRoles.contains(ciRole)) return null;
  final CiPipeline(:checks, :build) = ciRole.pipelineIn(ciRole.hookInput(hook));
  final environment = build.environments.first;
  return MatrixCiCommands(
    checks: [for (final check in checks) check.command],
    build: MatrixCiBuild(
      commands: [
        for (final command in build.prepare) command.command,
        '${build.command.of(environment)} --target-platform android-x64',
      ],
      keys: build.keys,
      artifact: build.artifact.of(environment),
    ),
  );
}
