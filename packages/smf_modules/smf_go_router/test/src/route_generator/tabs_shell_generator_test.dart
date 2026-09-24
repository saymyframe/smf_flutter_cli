import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/tabs_shell_generator.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';
import '../../helpers/route_fixtures.dart';

void main() {
  group('TabsShellGenerator', () {
    const generator = TabsShellGenerator();

    List<String> tabLines(List<Route> routes) {
      return generator
          .generate(declaration: mainTabsShell, routes: routes)
          .trim()
          .split('\n');
    }

    test('emits a _TabInfo with path, label and icon for each route', () {
      expect(
        tabLines([
          Route(
            path: '/home',
            meta: RouteMeta(label: 'Home', icon: 'Icons.home'),
          ),
        ]),
        ['_TabInfo(path: "/home", label: "Home", icon: Icons.home),'],
      );
    });

    test('omits the label when RouteMeta has none', () {
      expect(
        tabLines([
          Route(path: '/home', meta: RouteMeta(icon: 'Icons.home')),
        ]),
        ['_TabInfo(path: "/home", icon: Icons.home),'],
      );
    });

    test('orders tabs by RouteMeta.order and puts unordered tabs last', () {
      final lines = tabLines([
        Route(path: '/c', meta: RouteMeta(icon: 'Icons.c')),
        Route(path: '/b', meta: RouteMeta(icon: 'Icons.b', order: 1)),
        Route(path: '/d', meta: RouteMeta(icon: 'Icons.d')),
        Route(path: '/a', meta: RouteMeta(icon: 'Icons.a', order: 0)),
      ]);

      expect(
        lines.map((l) => RegExp(r'path: "([^"]+)"').firstMatch(l)!.group(1)),
        ['/a', '/b', '/c', '/d'],
      );
    });

    test('produces entries that fit the tabs list of the shell template', () {
      final code = generator.generate(
        declaration: mainTabsShell,
        routes: [
          Route(
            path: '/home',
            meta: RouteMeta(label: 'Home', icon: 'Icons.home', order: 0),
          ),
          Route(path: '/profile', meta: RouteMeta(icon: 'Icons.person')),
        ],
      );

      expectParses('final _tabs = <_TabInfo>[\n$code];');
    });

    test('returns an empty list body when there are no routes', () {
      expect(
        generator.generate(declaration: mainTabsShell, routes: []),
        isEmpty,
      );
    });

    test('throws a StateError for a tab route without RouteMeta', () {
      expect(
        () => generator.generate(
          declaration: mainTabsShell,
          routes: [Route(path: '/home', name: 'home')],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Route home must define RouteMeta'),
          ),
        ),
      );
    });
  });
}
