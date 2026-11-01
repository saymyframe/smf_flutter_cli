import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_github_actions/src/github_actions_module.dart';

/// The section of the module in the README of the app: how to start a build on
/// GitHub, where the values of an environment go in an app with the env role,
/// as [hasEnv] tells, and how to stay on one version of Flutter. What CI runs
/// is in the section of the role.
String readmeSectionOf(CiPipeline pipeline, {required bool hasEnv}) {
  final build = pipeline.build;
  final first = build.environments.first;
  final names = [for (final name in build.environments) '`$name`'];
  final environments =
      '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  final buffer = StringBuffer('''
`${GithubActionsModule.workflowFile}` runs on GitHub once you push the app there. Each push runs the checks of the section "${CiRole.readmeHeading}", which need no setup.

To build an APK, open **Actions**, then **CI**, then **Run workflow**, and pick an environment, or run:

```bash
gh workflow run ci.yml -f environment=$first
```

The file has to be on the default branch of the repository for that. The APK is an artifact of the run.
''');
  if (hasEnv) {
    buffer.write('''

A build takes the values of `${EnvRole.dotEnvFile}` from the variables of the GitHub environment that you picked. Set them in **Settings**, **Environments**, one environment for each of $environments that you build, under **Environment variables**, by the names of the keys${_keysOf(build.keys)}

```bash
gh variable set <KEY> --env $first --body '<value>'
```

Repeat this for each environment that needs it. GitHub documents environment variables on a private repository only for its paid plans, though a private repository on the Free plan takes them with this command too. If yours does not, set **Repository variables** instead, which give every build the same values. A key of your own also needs a line under `env:` of the step that writes `${EnvRole.dotEnvFile}`, as in `MY_SERVICE_KEY: \${{ vars.MY_SERVICE_KEY }}`.
''');
  }
  buffer.write('''

CI runs the latest stable Flutter, so a new release can turn it red with no change in your code: `flutter analyze` fails on a new deprecation, and the format check on a change of the formatter. To stay on the version that you develop with, add `flutter-version: <version>` under `channel: stable` in both jobs, with the version that `flutter --version` prints, and change it when you upgrade.

A build that fails on a download usually passes when you run it again.
''');
  return '$buffer';
}

/// The end of the sentence that names the keys of an app, with [keys] in a
/// list when it has some. With the GitHub CLI, the sentence goes on.
String _keysOf(List<String> keys) {
  const cli = 'With the GitHub CLI:';
  if (keys.isEmpty) return '. $cli';
  return ':\n\n${keys.map((key) => '- `$key`').join('\n')}\n\n$cli';
}
