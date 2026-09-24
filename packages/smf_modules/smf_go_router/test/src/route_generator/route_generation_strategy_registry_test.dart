import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy_registry.dart';
import 'package:test/test.dart';

import '../../helpers/route_fixtures.dart';

class _UnknownRoute extends BaseRoute {
  const _UnknownRoute();
}

void main() {
  group('RouteGenerationStrategyRegistry', () {
    final context = registryContext(shellDeclarations: [mainTabsShell]);

    test('generates a GoRoute for a Route', () {
      final code = RouteGenerationStrategyRegistry.generate(
        const Route(path: '/home'),
        context,
      );

      expect(code, contains('GoRoute('));
      expect(code, isNot(contains('ShellRoute(')));
    });

    test('generates a ShellRoute for a NestedRoute', () {
      final code = RouteGenerationStrategyRegistry.generate(
        NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          children: [const Route(path: '/home')],
        ),
        context,
      );

      expect(code, contains('ShellRoute('));
    });

    test('collects imports with the strategy of the route type', () {
      final route = NestedRoute(
        shellLink: RouteShellLink.toMainTabsShell(),
        children: [
          const Route(
            path: '/home',
            imports: [Import.features('home/home.dart')],
          ),
        ],
      );

      expect(RouteGenerationStrategyRegistry.imports(route, context), [
        "import 'package:{{app_name_sc}}/features/home/home.dart';",
      ]);
    });

    test('rejects route types without a strategy', () {
      expect(
        () => RouteGenerationStrategyRegistry.generate(
          const _UnknownRoute(),
          context,
        ),
        throwsUnsupportedError,
      );
      expect(
        () => RouteGenerationStrategyRegistry.imports(
          const _UnknownRoute(),
          context,
        ),
        throwsUnsupportedError,
      );
    });
  });
}
