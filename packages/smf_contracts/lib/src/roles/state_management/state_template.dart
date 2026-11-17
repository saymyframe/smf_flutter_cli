part of '../state_management.dart';

/// The note of the state management role in the guide for coding agents,
/// whichever module provides the role: that the values that controllers
/// keep reach the state manager through bridges, which the note of the
/// provider names, also a value that only a backend changes, and that code
/// changes such a value only through its controller.
const _agentNote = '''
- A value that a controller of a role or of a module keeps and screens read, such as the theme mode, reaches the state manager through a bridge of its own once the app has that controller, and the note of the provider names the file of the bridges then. So does a value that only a backend changes, such as the values of remote config in an app with that role; no code of the app changes it. A widget reads such a value through its bridge. Code changes any other such value only through its controller, which the doc of the bridge names, and never in a build.
''';

/// Who answers for [entry], which has the name of [earlier], an entry before
/// it in the order of [StateManagementRole.sharedStateIn]: its owner, unless
/// that is the template of a role, whose error stops the run. Lenient mode
/// can leave out a module, which comes before every template in that order.
ContributionOrigin _atFault(AppSharedState earlier, AppSharedState entry) =>
    entry.owner is RoleTemplateOrigin ? earlier.owner : entry.owner;

/// The template of the [StateManagementRole]: its note for coding agents,
/// and the checks of the data of the role that the module rules cannot
/// make.
final class _StateManagementTemplate extends RoleTemplate<StateData> {
  const _StateManagementTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        AppEntryRole.agentSections.entry(
          stateManagementRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];

  /// Checks what the module rule `state_management.shared_state` cannot see
  /// from one module: the entries of the templates of roles, which that
  /// rule does not read, [StateBridges] from such a template, which only a
  /// provider gives, and the entries of two owners with one name.
  @override
  List<SmfIssue> validate(RoleHookInput<StateData> input) {
    final issues = <SmfIssue>[];
    final ofTemplates = <RoleTemplateOrigin, List<SharedState>>{};
    for (final data in input.data) {
      // Every data that a hook gets has an origin.
      if (data.origin case final RoleTemplateOrigin template) {
        switch (data.value) {
          case final SharedState entry:
            (ofTemplates[template] ??= []).add(entry);
          case StateBridges():
            issues.add(
              SmfIssue(
                'The template of the ${template.role} gives the '
                '$stateManagementRole StateBridges, which only a provider of '
                'the role gives.',
                origin: template,
              ),
            );
        }
      }
    }
    for (final MapEntry(key: template, value: entries) in ofTemplates.entries) {
      for (final problem in _entryProblems(entries, template.role.id)) {
        issues.add(SmfIssue(problem, origin: template));
      }
    }

    // An entry starts with the id of its owner, but the id of one owner
    // can start the name of an entry of another, as the role push starts
    // the entry pushAddressLabel of a module push_address.
    final byName = <String, AppSharedState>{};
    for (final entry in stateManagementRole.sharedStateIn(input)) {
      final named = byName.putIfAbsent(entry.name, () => entry);
      if (named.owner != entry.owner) {
        issues.add(
          SmfIssue(
            'Both ${_named(named.owner)} and ${_named(entry.owner)} give the '
            '$stateManagementRole the entry ${entry.name}.',
            hint: 'Rename one of the entries.',
            origin: _atFault(named, entry),
          ),
        );
      }
    }
    return issues;
  }
}
