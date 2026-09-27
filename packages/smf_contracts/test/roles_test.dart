import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

/// Every built-in role.
const List<Role> _roles = [
  appEntryRole,
  stateManagementRole,
  routerRole,
  layoutRole,
  diRole,
  eventsRole,
  analyticsRole,
  crashReportingRole,
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
    for (final role in _roles) {
      final interface = role.interface;
      for (final file in [
        ...interface.files,
        for (final symbol in interface.symbols) symbol.path,
      ]) {
        expect(file, matches(RegExp(r'^lib/[a-z0-9_/]+\.dart$')), reason: file);
      }
    }
  });

  group('the templates of the roles', () {
    final withTemplates = [
      for (final role in _roles)
        if (role.template != null) role,
    ];

    test('exist for every role that generates files', () {
      expect(
        [for (final role in withTemplates) role.id],
        ['router', 'layout', 'di', 'events', 'analytics', 'crash_reporting'],
      );
    });

    test('generate exactly the files of their interfaces', () {
      for (final role in withTemplates) {
        final bricks = role.template!
            .contribute(testContext)
            .whereType<BrickContribution>()
            .toList();

        expect(bricks, hasLength(1), reason: role.id);
        expect(bricks.single.bundle.hooks, isEmpty, reason: role.id);
        expect(
          templatesOf(bricks.single.bundle).keys.toSet(),
          role.interface.files.toSet(),
          reason: role.id,
        );
      }
    });

    // A role's socket may also be tagged in its provider's files, as the
    // observers of the router are.
    test('have tags only of their own sockets, and no other mustache', () {
      final known = {'facade'};
      for (final role in withTemplates) {
        final brick = role.template!
            .contribute(testContext)
            .whereType<BrickContribution>()
            .single;
        final ownTags = {for (final socket in role.sockets) ...socket.tags};
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
    });
  });
}
