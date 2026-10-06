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

/// What the check of the notes of the roles names once [sentence] stands in
/// the first note of [role] in the guides of the apps of [results], each
/// thing as the note gives it.
List<String> _namedWith(
  Iterable<ContractResult> results,
  Role role,
  String sentence,
) {
  final target = [
    for (final result in results)
      for (final (origin, _, note)
          in result.app!.entriesOf(AppEntryRole.agentSections))
        if (origin == RoleTemplateOrigin(role)) note.text,
  ].first;
  final named = RegExp(r' names (`[^`]+`|\S+?)(?:,| in its text)');
  return [
    for (final line in roleNoteProblems(
      results,
      AppEntryRole.agentSections,
      textOf: (note) =>
          note.text == target ? '${note.text}\n$sentence' : note.text,
    ))
      named.firstMatch(line)![1]!,
  ];
}

/// Sentences that a note of a role may have in the apps of both registries:
/// names of Dart and of Flutter that only the file of a fixture has there.
const _accepted = <(Role, String)>[
  (themeRole, '- The mode is `ThemeMode.light` or `ThemeMode.dark`.'),
  (
    routerRole,
    '- Close a dialog with `Navigator.of(context).pop()`. '
        '`ModalRoute.of(context)` gives the page on top, and `int.tryParse` '
        'reads a number of a path.',
  ),
  (
    diRole,
    '- A factory may return a `FutureOr`, and a service is found by its '
        '`Type`.',
  ),
  (eventsRole, '- Keep no `StreamController` of your own for the events.'),
];

void main() {
  // The fixtures have a provider of their own for most roles, such as a
  // router next to go_router and a DI container next to get_it, each with
  // an id, packages and files of its own. So a note of a role that names
  // what the providers of the CLI happen to share fails here.
  for (final (name, modules) in [
    ('of the fixtures', fixtureModules()),
    ('of several providers', severalProvidersModules()),
  ]) {
    final hasFixtureRouter = modules.any(
      (module) => module.descriptor.id == const ModuleId('fake_router'),
    );
    group('in the apps of the registry $name, the note of a role', () {
      late List<ContractResult> results;

      setUpAll(() async => results = await _appsOf(modules));

      test('names nothing of the modules behind the roles', () {
        expect(
          roleNoteProblems(
            results,
            AppEntryRole.agentSections,
            textOf: (note) => note.text,
          ),
          isEmpty,
          reason: 'The note of a role tells what holds whichever modules '
              'provide the roles. These lines are about the apps of the '
              'registry $name, whose modules are the fixtures of '
              '`packages/smf_pipeline/test/fixtures/` and some modules of '
              'the CLI: a module that a line names, such as fake_router, '
              'may be a fixture, which the registry of the CLI has not. If '
              'the check takes a name of Dart or of Flutter for one of a '
              'package, pass it in `allowed` with the reason.',
        );
        // The router role tells of the guards from its render hook, only in
        // an app with one: the registry has such an app, so that note is
        // among those read.
        expect(
          {for (final result in results) ..._rolesWithHookNotesIn(result)},
          contains(routerRole),
        );
      });

      test(
          'may name Dart and Flutter, also what only the file of a fixture '
          'has of them', () {
        for (final (role, sentence) in _accepted) {
          expect(
            _namedWith(results, role, sentence),
            isEmpty,
            reason: 'The $role: $sentence',
          );
        }
      });

      test('may not name go_router or what its file has of its package', () {
        expect(
          _namedWith(
            results,
            routerRole,
            '- Navigate with the facade, never with a `redirect` of the '
            '`GoRouter` of go_router.',
          ),
          ['`GoRouter`', 'go_router'],
        );
      });

      // What only a registry with the fixture router can tell.
      if (hasFixtureRouter) {
        test(
            'may not name the fixture router, its files or what they '
            'declare', () {
          expect(
            _namedWith(
              results,
              routerRole,
              '- The `_FixtureDelegate` builds the pages, and a screen has a '
              '`FixtureScreen` annotation from '
              '`lib/core/router/fixture_annotations.dart`, as fake_router '
              'wants.',
            ),
            [
              '`_FixtureDelegate`',
              '`FixtureScreen`',
              '`lib/core/router/fixture_annotations.dart`',
              'fake_router',
            ],
          );
        });
      }
    });
  }
}
