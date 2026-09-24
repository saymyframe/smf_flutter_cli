import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

// Values come from loops so the constructors run at test time instead of
// being evaluated as constants.
void main() {
  group('Route', () {
    test('has no params, meta, name, screen, guards or imports by default', () {
      for (final path in ['/home', '/orders/:id']) {
        final route = Route(path: path);

        expect(route.path, path);
        expect(route.parameters, isEmpty);
        expect(route.meta, isNull);
        expect(route.name, isNull);
        expect(route.screen, isNull);
        expect(route.guards, isEmpty);
        expect(route.imports, isEmpty);
      }
    });
  });

  group('NestedRoute', () {
    test('keeps its children and shell, with no guards or imports by default',
        () {
      for (final path in ['/home', '/settings']) {
        final child = Route(path: path);
        final link = RouteShellLink(path);
        final nested = NestedRoute(children: [child], shellLink: link);

        expect(nested.children, [child]);
        expect(nested.shellLink, link);
        expect(nested.guards, isEmpty);
        expect(nested.imports, isEmpty);
        expect(nested.name, isNull);
        expect(nested.screen, isNull);
      }
    });
  });

  group('RouteScreenArgs', () {
    test('passes arguments by name by default', () {
      for (final source in ParameterSource.values) {
        final args = RouteScreenArgs(
          name: 'id',
          sourceName: 'id',
          source: source,
        );

        expect(args.source, source);
        expect(args.isNamed, isTrue);
      }
    });
  });

  group('route parameters', () {
    test('a query param is required unless marked optional', () {
      for (final name in ['page', 'sort']) {
        final required = QueryParam(name, type: int);
        final optional = QueryParam(name, type: int, optional: true);

        expect(required.name, name);
        expect(required.optional, isFalse);
        expect(optional.optional, isTrue);
      }
    });

    test('a path param is never optional', () {
      for (final type in [String, int]) {
        final param = PathParam('id', type: type);

        expect(param.type, type);
        expect(param.optional, isFalse);
      }
    });
  });

  group('RouteMeta', () {
    test('has no label or order by default', () {
      for (final icon in ['Icons.home', 'Icons.star']) {
        final meta = RouteMeta(icon: icon);

        expect(meta.icon, icon);
        expect(meta.label, isNull);
        expect(meta.order, isNull);
      }
    });
  });

  group('guards', () {
    test('a route guard keeps one implementation per routing mode', () {
      for (final code in ['return null;', "return '/login';"]) {
        final redirect = GoRouteRedirect(code: code);
        final autoRoute = AutoRouteGuard(className: 'AuthGuard', code: code);
        final guard = RouteGuard(
          bindings: {
            RoutingMode.goRouter: redirect,
            RoutingMode.autoRouter: autoRoute,
          },
        );

        expect(guard.bindings[RoutingMode.goRouter], redirect);
        expect(guard.bindings[RoutingMode.autoRouter], autoRoute);
        expect(redirect.imports, isEmpty);
        expect(autoRoute.className, 'AuthGuard');
        expect(autoRoute.imports, isEmpty);
      }
    });
  });
}
