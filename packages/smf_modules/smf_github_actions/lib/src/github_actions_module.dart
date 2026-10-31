import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_github_actions/src/agents.dart';
import 'package:smf_github_actions/src/readme.dart';
import 'package:smf_github_actions/src/workflow.dart';

/// The module that gives the app its CI on GitHub Actions, and so provides the
/// CI role.
///
/// Its render hook writes what [CiRole.pipelineIn] gives into [workflowFile].
/// The file comes from [RoleOutput.files], since a brick would take
/// `${{ … }}` for its own tag. On each push, a job runs the checks. From the
/// Actions tab of the repository, or with `gh workflow run`, a developer
/// builds the Android app for an environment. The variables of the environment
/// of that name on GitHub give a build its values.
///
/// The module also writes the section [readmeHeading] of the README of the
/// app, and a note in the section of the role in the guide for coding agents.
final class GithubActionsModule extends SmfModule {
  /// Creates the module.
  const GithubActionsModule();

  /// The id of the module.
  static const id = ModuleId('github_actions');

  /// The path of the workflow in the app.
  static const workflowFile = '.github/workflows/ci.yml';

  /// The heading of the section of the module in the README of the app.
  static const readmeHeading = 'GitHub Actions';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'CI on GitHub Actions',
        kind: ModuleKinds.infrastructure,
        providers: [_GithubActionsProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        AppEntryRole.agentSections.entry(
          ciRole.description,
          AgentNote(agentNote),
        ),
        AppEntryRole.agentSections.entry(
          ciRole.description,
          AgentNote(envAgentNote),
          when: const {envRole},
        ),
      ];
}

/// The provider of the CI role: its render hook writes the workflow and the
/// section of the README, from the pipeline of the app.
final class _GithubActionsProvider extends RoleProvider<NoDsl> {
  const _GithubActionsProvider();

  @override
  Role<NoDsl> get role => ciRole;

  @override
  RoleOutput render(RoleHookInput<NoDsl> input) {
    final pipeline = ciRole.pipelineIn(input);
    return RoleOutput(
      files: {GithubActionsModule.workflowFile: workflowOf(pipeline)},
      fragments: [
        AppEntryRole.readmeSections.entry(
          GithubActionsModule.readmeHeading,
          readmeSectionOf(pipeline, hasEnv: input.has(envRole)),
        ),
      ],
    );
  }
}
