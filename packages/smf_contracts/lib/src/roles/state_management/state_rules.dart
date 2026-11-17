part of '../state_management.dart';

/// The problems of the data of the module of [input], which the module rule
/// `state_management.shared_state` reports: those of its entries, and
/// [StateBridges] from a module that does not provide the role, or not
/// exactly once from one that does.
///
/// The template of the role checks the entries of the templates of roles,
/// and the entries of two owners with one name.
List<SmfIssue> _checkSharedState(ModuleRuleInput<StateData> input) {
  final module = input.module;
  final origin = ModuleOrigin(module.id);
  final entries = [
    for (final data in input.data)
      if (data.value case final SharedState entry) entry,
  ];
  final bridges = [
    for (final data in input.data)
      if (data.value case final StateBridges given) given,
  ];
  final provides = module.provides.contains(stateManagementRole);
  return [
    for (final problem in _entryProblems(entries, module.id.value))
      SmfIssue(problem, origin: origin),
    if (bridges.isNotEmpty && !provides)
      SmfIssue(
        'The module gives the $stateManagementRole StateBridges, which only a '
        'provider of the role gives.',
        hint: 'Give the role a SharedState for each value that your code '
            'keeps instead.',
        origin: origin,
      ),
    if (provides && bridges.length != 1)
      SmfIssue(
        'A provider of the $stateManagementRole gives it StateBridges once, '
        'but the module gives them ${bridges.length} times.',
        hint: 'Give the role one StateBridges, whose watch() reads a bridge '
            'as a developer of the app does.',
        origin: origin,
      ),
  ];
}

/// The problems with the functions that the entries of the app name: a
/// function missing from its file of the app, one that needs arguments,
/// since the provider of the role calls it without any, and one that does
/// not say that it returns a `ValueListenable` of the type of its entry, as
/// [SharedState.listenableType] writes it.
///
/// The module rule `state_management.shared_state` reports a function
/// outside the app.
List<SmfIssue> _checkListenableFunctions(StructuralRuleInput<StateData> input) {
  final issues = <SmfIssue>[];
  for (final entry in stateManagementRole.sharedStateIn(input.roleInput)) {
    final listenable = entry.state.listenable;
    if (!listenable.import.isAppFile) continue;
    final function = RequiredFunction(
      listenable.name,
      path: 'lib/${listenable.import.uri}',
      returnType: entry.state.listenableType,
    );
    for (final issue in function.checkIn(input.files)) {
      issues.add(
        SmfIssue(
          'The function of the $entry: ${issue.message}',
          hint: 'The provider of the role calls it without arguments, and '
              'follows the ${entry.state.listenableType} that it returns.',
          origin: entry.owner,
          path: issue.path,
        ),
      );
    }
  }
  return issues;
}

/// The entries that the provider of the role does not render: those whose
/// function none of the files of the provider calls or tears off, through
/// an import of the file that declares it.
///
/// So no provider leaves out a value that a module or the template of a
/// role gives the role, and the tests of the feeders need not look into
/// the files of any provider. Without the descriptor of a provider in
/// [input], no file renders the entries and there is nothing to check.
List<SmfIssue> _checkBridgesRendered(StructuralRuleInput<StateData> input) {
  final providers = {
    for (final module in input.modules)
      if (module.provides.contains(stateManagementRole)) module.id,
  };
  if (providers.isEmpty) return const [];
  final files = [
    for (final MapEntry(key: path, value: file) in input.files.entries)
      if (input.owners[path] case ModuleOrigin(:final module)
          when providers.contains(module))
        file,
  ];
  return [
    for (final entry in stateManagementRole.sharedStateIn(input.roleInput))
      if (entry.state.listenable case final listenable
          when !files.any(
        (file) => usesImported(file, listenable.name, listenable.import),
      ))
        SmfIssue(
          'The provider of the $stateManagementRole does not render the '
          '$entry: none of its files calls or tears off $listenable of '
          '${listenable.import.isAppFile ? 'lib/' : ''}'
          '${listenable.import.uri}.',
          hint: 'Give every entry of StateManagementRole.sharedStateIn() a '
              'bridge that follows the listenable of its function.',
          // The role takes one provider.
          origin: ModuleOrigin(providers.single),
        ),
  ];
}
