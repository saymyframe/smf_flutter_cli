import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

import 'role_support.dart';

const _icon = Fragment(
  'Icons.home',
  imports: [ImportRef('package:flutter/material.dart')],
);

/// The routes of a feature [module] with a destination per name in [tabs],
/// and a route without one.
RoleData<Object> _feature(String module, List<String> tabs) => dataOf(
      routerRole,
      RoutesData([
        for (final tab in tabs)
          Route(
            '/$tab',
            name: tab,
            screen: ScreenRef(
              '${tab[0].toUpperCase()}${tab.substring(1)}Screen',
              import: ImportRef.app('features/$module/$tab.dart'),
            ),
            destination: Destination(label: tab, icon: _icon),
          ),
        Route(
          '/plain',
          name: 'plain',
          screen: ScreenRef(
            'PlainScreen',
            import: ImportRef.app('features/$module/plain.dart'),
          ),
        ),
      ]),
      module: module,
    );

final class _AnyLayout extends LayoutProvider {
  const _AnyLayout();
}

final class _Tabs extends LayoutProvider {
  const _Tabs(this.maxDestinations);

  @override
  final int? maxDestinations;
}

void main() {
  test('the layout reads the destinations of the router in order', () {
    final input = inputOf(
      layoutRole,
      data: [
        _feature('home', ['feed', 'inbox']),
        _feature('settings', ['general']),
      ],
      present: {routerRole},
    );

    expect(
      [for (final route in layoutRole.destinationsIn(input)) route.fullPath],
      ['/home/feed', '/home/inbox', '/settings/general'],
    );
  });

  test('the app shell takes the destinations and the selected branch', () {
    expect(LayoutRole.appShell.path, LayoutRole.appShellFile);
    expect(LayoutRole.appShell.namedParameters, [
      'destinations',
      'currentIndex',
      'onSelect',
      'body',
    ]);
    expect(layoutRole.interface.symbols, [LayoutRole.appShell]);
  });

  group('LayoutProvider', () {
    RoleHookInput<NoDsl> input(int destinations) => inputOf(
          layoutRole,
          data: [
            _feature('home', ['a', 'b']),
            _feature(
              'more',
              [for (var i = 0; i < destinations - 2; i++) 't$i'],
            ),
          ],
          present: {routerRole},
        );

    test('is a provider of the layout role', () {
      expect(const _Tabs(null).role, same(layoutRole));
      expect(const _Tabs(null).maxDestinations, isNull);
    });

    test('accepts any number of destinations without a maximum', () {
      expect(const _AnyLayout().maxDestinations, isNull);
      expect(const _AnyLayout().validate(input(9)), isEmpty);
    });

    test('accepts up to its maximum of destinations', () {
      expect(const _Tabs(5).validate(input(5)), isEmpty);
    });

    test('rejects more destinations and names the first extra one', () {
      final issue = const _Tabs(3).validate(input(4)).single;

      expect(issue.message, contains('can show 3 destinations'));
      expect(issue.message, contains('/more/t1'));
      expect(issue.origin, const ModuleOrigin(ModuleId('more')));
    });
  });

  test('the template generates the destination class', () async {
    final rendered = await renderTemplate(layoutRole, present: {routerRole});

    expect(rendered.files.keys, [LayoutRole.destinationFile]);
    final code = rendered.files[LayoutRole.destinationFile]!;
    expectParses(code);
    expect(code, contains('final class Destination {'));
    expect(code, contains('final IconData icon;'));
    expect(rendered.elsewhere, isEmpty);
  });
}
