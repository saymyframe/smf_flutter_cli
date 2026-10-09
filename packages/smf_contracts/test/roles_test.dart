import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

/// Every built-in role.
const List<Role> _roles = [
  appEntryRole,
  stateManagementRole,
  routerRole,
  layoutRole,
  localizationRole,
  diRole,
  eventsRole,
  preferencesRole,
  analyticsRole,
  crashReportingRole,
  authRole,
  settingsScreenRole,
  themeRole,
];

final RegExp _mustache = RegExp(r'\{\{\{?\s*([^}]*?)\s*\}?\}\}');

void main() {
  test('the roles have distinct snake_case ids and presence flags', () {
    final ids = [for (final role in _roles) role.id];

    expect(ids.toSet(), hasLength(ids.length));
    for (final role in _roles) {
      expect(SmfNames.isSnakeCase(role.id), isTrue, reason: role.id);
      expect(role.presenceFlag, 'has_${role.id}');
      expect(role.description, isNotEmpty);
    }
  });

  test('messages name the roles by their descriptions', () {
    final names = [for (final role in _roles) '$role'];

    expect(names, [
      'app entry role',
      'state management role',
      'router role',
      'layout role',
      'localization role',
      'dependency injection role',
      'events role',
      'preferences role',
      'analytics role',
      'crash reporting role',
      'authentication role',
      'settings screen role',
      'theme role',
    ]);
  });

  test('the roles have the cardinalities and relations of the plan', () {
    Map<String, Object> shape(Role role) => {
          'cardinality': role.cardinality,
          'requires': {for (final other in role.requires) other.id},
          'uses': {for (final other in role.uses) other.id},
        };

    expect(shape(stateManagementRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': <String>{},
      'uses': <String>{},
    });
    expect(shape(routerRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': <String>{},
      'uses': {'layout'},
    });
    expect(shape(layoutRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': {'router'},
      'uses': {'localization'},
    });
    expect(shape(localizationRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': {'preferences'},
      'uses': {'settings_screen'},
    });
    expect(shape(diRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': <String>{},
      'uses': <String>{},
    });
    expect(shape(eventsRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': <String>{},
      'uses': {'di'},
    });
    expect(shape(preferencesRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': <String>{},
      'uses': {'di'},
    });
    expect(shape(analyticsRole), {
      'cardinality': RoleCardinality.many,
      'requires': <String>{},
      'uses': {'di', 'router'},
    });
    expect(shape(crashReportingRole), {
      'cardinality': RoleCardinality.many,
      'requires': <String>{},
      'uses': {'di'},
    });
    // The auth role works with no other role, not with a DI container
    // either: the code of an app reaches sign-in through the session that
    // the role generates, a top-level variable.
    expect(shape(authRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': <String>{},
      'uses': <String>{},
    });
    expect(shape(settingsScreenRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': {'router'},
      'uses': <String>{},
    });
    expect(shape(themeRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': {'preferences'},
      'uses': {'settings_screen', 'localization'},
    });
  });

  test('only the app entry is open to all modules', () {
    for (final role in _roles) {
      expect(
        role.openToAllModules,
        identical(role, appEntryRole),
        reason: role.id,
      );
    }
  });

  test('the sockets of all roles are owned, valid and have distinct tags', () {
    final tags = <String>[];
    for (final role in _roles) {
      for (final socket in role.sockets) {
        expect(socket.role, same(role), reason: '$socket');
        expect(socket.problems(), isEmpty, reason: '$socket');
        tags.addAll(socket.tags);
      }
      for (final family in role.socketFamilies) {
        expect(family.role, same(role), reason: family.name);
        tags.add(family.tagPrefix);
      }
    }
    expect(tags.toSet(), hasLength(tags.length));
    for (final tag in tags) {
      for (final other in tags) {
        if (tag != other && other.startsWith(tag) && tag.endsWith('__')) {
          fail('The family prefix $tag covers the tag $other');
        }
      }
    }
  });

  test('the role interfaces name files of the app', () {
    final dartFile = RegExp(r'^lib/[a-z0-9_/]+\.dart$');
    // A file for those who work on the app, such as the guide for coding
    // agents, is at its root.
    final rootFile = RegExp(r'^[A-Z]+\.md$');
    for (final role in _roles) {
      final interface = role.interface;
      for (final file in interface.files) {
        expect(
          file,
          anyOf(matches(dartFile), matches(rootFile)),
          reason: file,
        );
      }
      for (final symbol in interface.symbols) {
        expect(symbol.path, matches(dartFile), reason: symbol.path);
      }
    }
  });

  group('the templates of the roles', () {
    final withTemplates = [
      for (final role in _roles)
        if (role.template != null) role,
    ];

    /// The bricks of the template of [role].
    List<BrickContribution> bricksOf(Role role) => role.template!
        .contribute(testContext)
        .whereType<BrickContribution>()
        .toList();

    test(
        'exist for every role that generates files, or that checks the data '
        'of all its contributors', () {
      expect(
        [for (final role in withTemplates) role.id],
        [
          'app_entry',
          'router',
          'layout',
          'localization',
          'di',
          'events',
          'preferences',
          'analytics',
          'crash_reporting',
          'auth',
          'settings_screen',
          'theme',
        ],
      );
    });

    test(
        'generate exactly the files of their interfaces in every app, and '
        'other files only in the apps with the roles of a brick', () {
      for (final role in withTemplates) {
        final bricks = bricksOf(role);
        final always = [
          for (final brick in bricks)
            if (brick.when.isEmpty) brick,
        ];

        // One brick for every app with the role, or none for a role that
        // guarantees no file, such as the settings screen, whose template
        // only checks its data.
        expect(
          always,
          hasLength(role.interface.files.isEmpty ? 0 : 1),
          reason: role.id,
        );
        for (final brick in always) {
          expect(
            templatesOf(brick.bundle).keys.toSet(),
            role.interface.files.toSet(),
            reason: role.id,
          );
        }
        // A file that only some apps have is in a brick of its own, which
        // names the roles of those apps, among the roles that the role
        // requires or uses. The role does not guarantee such a file.
        for (final brick in bricks) {
          expect(brick.bundle.hooks, isEmpty, reason: role.id);
          if (brick.when.isEmpty) continue;
          expect(
            role.visibleRoles,
            containsAll(brick.when),
            reason: '${role.id}: ${brick.bundle.name}',
          );
          expect(
            templatesOf(brick.bundle).keys.toSet().intersection(
                  role.interface.files.toSet(),
                ),
            isEmpty,
            reason: '${role.id}: ${brick.bundle.name}',
          );
        }
      }
    });

    // The roles whose templates have nothing to tell a coding agent, each
    // with the reason. The template of every other role has a note in the
    // guide for coding agents. `test/agent_notes_test.dart` of
    // `smf_flutter_cli` has such a list too, for the apps of the CLI.
    const withoutNote = <Role, String>{};
    final withNotes = [
      for (final role in withTemplates)
        if (!withoutNote.containsKey(role)) role,
    ];

    /// The notes of the template of [role] for the guide for coding agents.
    List<SocketContribution> notesOf(Role role) => [
          for (final contribution in role.template!
              .contribute(testContext)
              .whereType<SocketContribution>())
            if (contribution.socket == AppEntryRole.agentSections) contribution,
        ];

    test(
        'say in the guide for coding agents what their roles guarantee, '
        'under the descriptions of the roles', () {
      const socket = AppEntryRole.agentSections;
      for (final MapEntry(key: role, value: reason) in withoutNote.entries) {
        expect(
          notesOf(role),
          isEmpty,
          reason: 'The $role is in `withoutNote` ("$reason"), but its '
              'template has a note. Remove it from `withoutNote`.',
        );
      }
      for (final role in withNotes) {
        final notes = notesOf(role);

        // One note in every app with the role.
        expect(
          notes.where((note) => note.when.isEmpty),
          hasLength(1),
          reason: 'The template of the $role contributes one note for every '
              'app with the role, an `AgentNote.ofRole` for '
              '`AppEntryRole.agentSections` under the description of the '
              'role, with what the role guarantees whichever module '
              'provides it. A role with nothing to tell a coding agent goes '
              'into `withoutNote` of this test and into `_withoutNote` of '
              '`test/agent_notes_test.dart` of `smf_flutter_cli`, with the '
              'reason. The convention of the notes is in the AGENTS.md of '
              'the repository, under "Every app gets `AGENTS.md`".',
        );
        for (final note in notes) {
          expect(note.entryKey, role.description, reason: role.id);
          expect(
            (note.entryValue! as AgentNote).isOfRole,
            isTrue,
            reason: role.id,
          );
          // A note of what only some apps with the role have, such as the
          // file of a setting in an app with a settings screen, names the
          // roles of those apps, among the roles that the role requires or
          // uses.
          expect(role.visibleRoles, containsAll(note.when), reason: role.id);
          expect(socket.problemsWith(note), isEmpty, reason: role.id);
        }
      }
    });

    test('name in the guide only files that their roles guarantee', () {
      const socket = AppEntryRole.agentSections;
      for (final role in withNotes) {
        for (final note in notesOf(role)) {
          // An app with nothing but what the app entry, the role, the
          // roles it requires and the roles of the note guarantee: the
          // files of their templates and those of the symbols of their
          // providers, and the files that the template of the role
          // generates in an app with the roles of the note.
          final guaranteed = {
            for (final present in {
              appEntryRole,
              role,
              ...role.requires,
              ...note.when,
            }) ...[
              ...present.interface.files,
              for (final symbol in present.interface.symbols) symbol.path,
            ],
            for (final brick in bricksOf(role))
              if (note.when.containsAll(brick.when))
                ...templatesOf(brick.bundle).keys,
          };
          final sections = socket.render([
            socket.entry(role.description, note.entryValue! as AgentNote),
          ])[socket.tag];
          final issues = appEntryRole.checkStructure(
            StructuralRuleRequest(
              hook: const RoleHookRequest(
                data: [],
                presentRoles: {appEntryRole},
                context: testContext,
              ),
              files: const {},
              texts: {AppEntryRole.agentsFile: '# AGENTS.md\n$sections\n'},
              owners: {
                for (final path in guaranteed)
                  path: const RoleTemplateOrigin(appEntryRole),
              },
            ),
          );

          expect(
            [for (final issue in issues) issue.message],
            isEmpty,
            reason: '${role.id}, in an app with ${note.when}',
          );
        }
      }
    });

    // A role's socket may also be tagged in its provider's files, as the
    // observers of the router are. The other names are the variables of the
    // render hooks of the templates.
    test('have tags only of their own sockets, and no other mustache', () {
      final known = {
        'facade',
        'guards',
        'destinations',
        'labels',
        'locales',
        'locale_key',
        'locale_names',
        'text_language',
        'mode_key',
        'text_title',
        'text_system',
        'text_light',
        'text_dark',
        'auth_mode',
      };
      for (final role in withTemplates) {
        final ownTags = {for (final socket in role.sockets) ...socket.tags};
        for (final brick in bricksOf(role)) {
          for (final MapEntry(key: path, value: text)
              in templatesOf(brick.bundle).entries) {
            for (final match in _mustache.allMatches(text)) {
              final name = match.group(1)!;
              final triple = match.group(0)!.startsWith('{{{');
              expect(triple, isTrue, reason: '$path: ${match.group(0)}');
              expect(
                ownTags.contains(name) || known.contains(name),
                isTrue,
                reason: '$path: unknown {{{$name}}}',
              );
            }
          }
        }
      }
    });
  });
}
