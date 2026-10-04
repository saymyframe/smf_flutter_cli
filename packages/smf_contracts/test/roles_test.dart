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
      'uses': <String>{},
    });
    expect(shape(localizationRole), {
      'cardinality': RoleCardinality.atMostOne,
      'requires': <String>{},
      'uses': <String>{},
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

    // A role's socket may also be tagged in its provider's files, as the
    // observers of the router are. The other names are the variables of the
    // render hooks of the templates.
    test('have tags only of their own sockets, and no other mustache', () {
      final known = {
        'facade',
        'guards',
        'locales',
        'mode_key',
        'text_title',
        'text_system',
        'text_light',
        'text_dark',
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
