// Runs actionlint over the workflow of the module, for what GitHub refuses and
// a parse of its YAML does not see, such as a key that a job does not have or a
// context that does not exist where an expression reads it. A developer meets
// such a mistake only as an invalid workflow on the first push of the app.
//
// It needs the binary of actionlint, so it runs only where SMF_ACTIONLINT has
// its path, as in the job of the checks of CI, which downloads the version that
// the workflow pins.
@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_github_actions/smf_github_actions.dart';
import 'package:test/test.dart';

import 'support/apps.dart';

/// What actionlint says of [workflow], the text of a workflow, in a directory
/// of its own. It checks with its own rules alone, on every machine: it would
/// also run shellcheck and pyflakes when it finds them on the `PATH`, and the
/// versions of those are not pinned. The commands of the workflow run for real
/// in the jobs of the apps.
Future<ProcessResult> _actionlint(String actionlint, String workflow) async {
  final directory = await Directory.systemTemp.createTemp('smf_actionlint');
  addTearDown(() => directory.delete(recursive: true));
  await File('${directory.path}/${GithubActionsModule.workflowFile}')
      .create(recursive: true)
      .then((file) => file.writeAsString(workflow));
  return Process.run(
    actionlint,
    [
      '-no-color',
      '-shellcheck=',
      '-pyflakes=',
      GithubActionsModule.workflowFile,
    ],
    workingDirectory: directory.path,
  );
}

void main() {
  final actionlint = Platform.environment['SMF_ACTIONLINT'];

  group(
    'actionlint',
    skip: actionlint == null ? 'Set SMF_ACTIONLINT to its binary.' : null,
    () {
      final apps = {
        'without the env role': withoutEnv,
        'with the env role and no keys': withEnv,
        'with the env role and keys': withKeys,
      };
      for (final MapEntry(key: name, value: modules) in apps.entries) {
        test('takes the workflow of the app $name', () async {
          final result = await _actionlint(
            actionlint!,
            workflowTextOf(await renderedApp(modules)),
          );

          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}${result.stderr}',
          );
        });
      }

      // So that the tests above do not pass for want of a check, as with a
      // binary that runs and looks at nothing.
      test('refuses a key that a job of the workflow does not have', () async {
        final workflow = workflowTextOf(await renderedApp(withKeys));
        expect(workflow, contains('timeout-minutes:'));

        final result = await _actionlint(
          actionlint!,
          workflow.replaceFirst('timeout-minutes:', 'timeout-minute:'),
        );

        expect(result.exitCode, 1, reason: '${result.stderr}');
        expect(result.stdout, contains('timeout-minute'));
      });
    },
  );
}
