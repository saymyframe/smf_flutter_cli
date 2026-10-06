@TestOn('vm')
library;

import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The apps of the cases of every module and of every role of [modules],
/// and their apps with every module.
Future<List<ContractResult>> _appsOf(List<SmfModule> modules) async {
  final harness = ContractHarness(ModuleRegistry(modules));
  return [
    for (final result in [
      ...await harness.checkAll(),
      for (final contractCase in harness.casesOfAll())
        await harness.check(contractCase),
    ])
      if (result.app != null) result,
  ];
}

/// The roles whose templates gave the guide for coding agents of the app of
/// [result] a note from their render hooks: one that is none of the
/// contributions of the template.
Set<Role> _rolesWithHookNotesIn(ContractResult result) {
  final contributed = {
    for (final Collected(:origin, :contribution) in result.collection!.all)
      if (contribution
          case SocketContribution(
            socket: AppEntryRole.agentSections,
            entryValue: final AgentNote note,
          ))
        (origin, note.text),
  };
  return {
    for (final (origin, _, note)
        in result.app!.entriesOf(AppEntryRole.agentSections))
      if (origin case RoleTemplateOrigin(:final role)
          when !contributed.contains((origin, note.text)))
        role,
  };
}

void main() {
  // The fixtures have a second provider of most roles, such as a router
  // next to go_router and a DI container next to get_it, each with an id,
  // packages and files of its own. So a note of a role that names what the
  // providers of the CLI happen to share fails here.
  for (final (name, modules) in [
    ('of the fixtures', fixtureModules()),
    ('of several providers', severalProvidersModules()),
  ]) {
    test(
        'in the apps of the registry $name, the note of a role in the guide '
        'for coding agents names nothing that only a module that provides '
        'the role has', () async {
      final results = await _appsOf(modules);

      expect(
        roleNoteProblems(
          results,
          AppEntryRole.agentSections,
          textOf: (note) => note.text,
        ),
        isEmpty,
        reason: 'The note of a role tells what holds whichever module '
            'provides the role. What only a provider has belongs in the note '
            'of that module.',
      );
      // The router role tells of the guards from its render hook, only in
      // an app with one: the registry has such an app, so that note is
      // among those read.
      expect(
        {for (final result in results) ..._rolesWithHookNotesIn(result)},
        contains(routerRole),
      );
    });
  }
}
