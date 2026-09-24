import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/nested_route_strategy.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';
import '../../helpers/route_fixtures.dart';

void main() {
  final strategy = NestedRouteStrategy();

  NestedRoute tabs(List<Route> children, {List<RouteGuard> guards = const []}) {
    return NestedRoute(
      shellLink: RouteShellLink.toMainTabsShell(),
      children: children,
      guards: guards,
    );
  }

  group('NestedRouteStrategy', () {
    group('generate', () {
      test('wraps the children in a ShellRoute built with the shell widget',
          () async {
        final route = tabs([
          const Route(
            path: '/home',
            name: 'home',
            screen: RouteScreen('HomeScreen'),
            meta: RouteMeta(icon: 'Icons.home'),
          ),
          const Route(
            path: '/profile',
            screen: RouteScreen('ProfileScreen'),
            meta: RouteMeta(icon: 'Icons.person'),
          ),
        ]);

        final code = strategy.generate(
          route,
          registryContext(shellDeclarations: [mainTabsShell]),
        );

        expect(code, contains('ShellRoute('));
        expect(
          code,
          contains('builder: (_, __, child) => MainTabsShell(child: child),'),
        );
        expect(countOf(code, 'GoRoute('), 2);
        expect(
          code.indexOf("path: '/home'"),
          lessThan(code.indexOf("path: '/profile'")),
        );
        expect(
          await compileErrors('''
$goRouterStubs
class MainTabsShell {
  MainTabsShell({required Object child});
}
class HomeScreen {}
class ProfileScreen {}
abstract final class AppRoutes {
  static const home = 'home';
}

final routes = <RouteBase>[
$code
];
'''),
          isEmpty,
        );
      });

      test('generates each child through the context', () {
        final context = RouteGenerationContext(
          shellDeclarations: [mainTabsShell],
          generateRoute: (route) => '/* child ${(route as Route).path} */',
          generateImports: (_) => [],
        );

        final code = strategy.generate(
          tabs([const Route(path: '/a'), const Route(path: '/b')]),
          context,
        );

        expect(code, contains('/* child /a */\n/* child /b */'));
      });

      test('chains the nested route guards into the ShellRoute redirect', () {
        final code = strategy.generate(
          tabs(
            [const Route(path: '/home', screen: RouteScreen('HomeScreen'))],
            guards: [goRouterGuard('onboardingGuard(context, state)')],
          ),
          registryContext(shellDeclarations: [mainTabsShell]),
        );

        final shellRedirect = code.lastIndexOf('redirect:');
        expect(
          code.indexOf('final r0 = onboardingGuard(context, state);'),
          greaterThan(shellRedirect),
        );
        expectParses('final routes = [$code];');
      });

      test('throws when the linked shell is not declared in the context', () {
        expect(
          () => strategy.generate(
            tabs([const Route(path: '/home')]),
            registryContext(),
          ),
          throwsArgumentError,
        );
      });
    });

    group('imports', () {
      test('lists its own imports before the imports of its children', () {
        final route = NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          imports: [
            const Import.core(ImportAnchor.coreWidgets, 'tabs_scope.dart')
          ],
          children: [
            const Route(
              path: '/home',
              imports: [Import.features('home/home_screen.dart')],
            ),
            const Route(
              path: '/profile',
              imports: [Import.features('profile/profile_screen.dart')],
            ),
          ],
        );

        expect(strategy.imports(route, registryContext()), [
          "import 'package:{{app_name_sc}}/core/widgets/tabs_scope.dart';",
          "import 'package:{{app_name_sc}}/features/home/home_screen.dart';",
          "import 'package:{{app_name_sc}}/features/profile/profile_screen.dart';",
        ]);
      });
    });
  });
}
