import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_github_actions/src/github_actions_module.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the CI role, after what the role says there. Its first line
/// names the host, as the note of a provider that wraps a package names the
/// package.
const agentNote = '''
With `GitHub Actions`:

- `${GithubActionsModule.workflowFile}` has the two jobs: `checks`, on each push, and `build`, which a developer starts for an environment.
- Never put `\${{ … }}` in a `run:` line, which would make a value a part of the script. Pass the value through `env:` of the step, and read it as a variable of the shell.
- Each `uses:` line is pinned to a full commit, with its tag in a comment after it. To update an action, change the two together.
''';

/// The note of the module in an app with the env role.
const envAgentNote = '''
- A new key of `${EnvRole.dotEnvFile}` needs a line under `env:` of the step of `build` that runs `${CiRole.writeEnvFile}`, as in `MY_SERVICE_KEY: \${{ vars.MY_SERVICE_KEY }}`. Without it, a build leaves that value empty.
''';
