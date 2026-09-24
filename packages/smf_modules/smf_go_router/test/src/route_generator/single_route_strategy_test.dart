import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/single_route_strategy.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';
import '../../helpers/route_fixtures.dart';

void main() {
  final strategy = SingleRouteStrategy();

  String generate(Route route) => strategy.generate(route, registryContext());

  /// Type-checks [route]'s generated code against go_router stubs plus
  /// [declarations] (screens, AppRoutes, guard functions).
  Future<List<String>> compile(Route route, String declarations) {
    return compileErrors('''
$goRouterStubs
$declarations

final routes = <RouteBase>[
${generate(route)}
];
''');
  }

  group('SingleRouteStrategy', () {
    group('generate', () {
      test('emits a GoRoute with path, AppRoutes name and screen builder',
          () async {
        final route = Route(
          path: '/settings',
          name: 'settings',
          screen: RouteScreen('SettingsScreen'),
        );

        final code = generate(route);

        expect(code, contains("path: '/settings',"));
        expect(code, contains('name: AppRoutes.settings,'));
        expect(
          code,
          contains('builder: (context, state) => SettingsScreen(),'),
        );
        expect(
          await compile(route, '''
class SettingsScreen {}
abstract final class AppRoutes {
  static const settings = 'settings';
}
'''),
          isEmpty,
        );
      });

      test('omits the name when the route has none or an empty one', () {
        for (final name in [null, '']) {
          final code = generate(
            Route(path: '/about', name: name, screen: RouteScreen('About')),
          );

          expect(code, isNot(contains('name:')), reason: 'name: $name');
          expectParses('final routes = [$code];');
        }
      });

      test('omits the builder when the route has no screen', () {
        final code = generate(Route(path: '/redirect-only'));

        expect(code, isNot(contains('builder:')));
        expect(code, contains('redirect:'));
        expectParses('final routes = [$code];');
      });

      test('emits a redirect that allows navigation when there are no guards',
          () {
        final code = generate(Route(path: '/open', screen: RouteScreen('X')));

        expect(code, contains('redirect:'));
        expect(code, contains('return null;'));
        expect(code, isNot(contains('final r0')));
      });

      test('chains the route guards into its redirect', () async {
        final route = Route(
          path: '/account',
          screen: RouteScreen('AccountScreen'),
          guards: [goRouterGuard('authGuard(context, state)')],
        );

        final code = generate(route);

        expect(code, contains('final r0 = authGuard(context, state);'));
        expect(code, contains('if (r0 != null) return r0;'));
        expect(
          await compile(route, '''
class AccountScreen {}
String? authGuard(BuildContext context, GoRouterState state) => null;
'''),
          isEmpty,
        );
      });

      test('throws when a guard has no go_router binding', () {
        expect(
          () => generate(
            Route(path: '/account', guards: [autoRouterOnlyGuard()]),
          ),
          throwsArgumentError,
        );
      });
    });

    group('screen arguments', () {
      test('reads path parameters from state.pathParameters', () {
        final code = generate(
          Route(
            path: '/users/:userId',
            parameters: [PathParam('userId', type: String)],
            screen: RouteScreen(
              'UserScreen',
              screenArguments: [
                RouteScreenArgs(
                  name: 'id',
                  sourceName: 'userId',
                  source: ParameterSource.path,
                ),
              ],
            ),
          ),
        );

        expect(
          code,
          contains("UserScreen(id: state.pathParameters['userId']!)"),
        );
      });

      test('reads query parameters from state.uri.queryParameters', () {
        final code = generate(
          Route(
            path: '/search',
            parameters: [QueryParam('q', type: String)],
            screen: RouteScreen(
              'SearchScreen',
              screenArguments: [
                RouteScreenArgs(
                  name: 'query',
                  sourceName: 'q',
                  source: ParameterSource.query,
                ),
              ],
            ),
          ),
        );

        expect(
          code,
          contains("SearchScreen(query: state.uri.queryParameters['q']!)"),
        );
      });

      test('parses int, double and bool parameters', () {
        final code = generate(
          Route(
            path: '/products/:id',
            parameters: [
              PathParam('id', type: int),
              QueryParam('price', type: double),
              QueryParam('featured', type: bool),
            ],
            screen: RouteScreen(
              'ProductScreen',
              screenArguments: [
                RouteScreenArgs(
                  name: 'id',
                  sourceName: 'id',
                  source: ParameterSource.path,
                ),
                RouteScreenArgs(
                  name: 'price',
                  sourceName: 'price',
                  source: ParameterSource.query,
                ),
                RouteScreenArgs(
                  name: 'featured',
                  sourceName: 'featured',
                  source: ParameterSource.query,
                ),
              ],
            ),
          ),
        );

        expect(code, contains("id: int.parse(state.pathParameters['id']!)"));
        expect(
          code,
          contains(
            "price: double.parse(state.uri.queryParameters['price']!)",
          ),
        );
        expect(
          code,
          contains(
            "featured: state.uri.queryParameters['featured']! == \"true\"",
          ),
        );
      });

      test('passes positional arguments without a name', () {
        final code = generate(
          Route(
            path: '/users/:id',
            parameters: [PathParam('id', type: String)],
            screen: RouteScreen(
              'UserScreen',
              screenArguments: [
                RouteScreenArgs(
                  name: 'id',
                  sourceName: 'id',
                  source: ParameterSource.path,
                  isNamed: false,
                ),
              ],
            ),
          ),
        );

        expect(code, contains("UserScreen(state.pathParameters['id']!)"));
      });

      test('passes an optional String query parameter through as nullable', () {
        final code = generate(
          Route(
            path: '/search',
            parameters: [QueryParam('q', type: String, optional: true)],
            screen: RouteScreen(
              'SearchScreen',
              screenArguments: [
                RouteScreenArgs(
                  name: 'query',
                  sourceName: 'q',
                  source: ParameterSource.query,
                ),
              ],
            ),
          ),
        );

        expect(
          code,
          contains("SearchScreen(query: state.uri.queryParameters['q'])"),
        );
      });

      test('generates a builder that type-checks against the screen', () async {
        final route = Route(
          path: '/products/:id/:slug',
          name: 'product',
          parameters: [
            PathParam('id', type: int),
            PathParam('slug', type: String),
            QueryParam('price', type: double),
            QueryParam('featured', type: bool),
            QueryParam('ref', type: String, optional: true),
          ],
          screen: RouteScreen(
            'ProductScreen',
            screenArguments: [
              RouteScreenArgs(
                name: 'id',
                sourceName: 'id',
                source: ParameterSource.path,
              ),
              RouteScreenArgs(
                name: 'slug',
                sourceName: 'slug',
                source: ParameterSource.path,
                isNamed: false,
              ),
              RouteScreenArgs(
                name: 'price',
                sourceName: 'price',
                source: ParameterSource.query,
              ),
              RouteScreenArgs(
                name: 'featured',
                sourceName: 'featured',
                source: ParameterSource.query,
              ),
              RouteScreenArgs(
                name: 'ref',
                sourceName: 'ref',
                source: ParameterSource.query,
              ),
            ],
          ),
        );

        expect(
          await compile(route, '''
abstract final class AppRoutes {
  static const product = 'product';
}
class ProductScreen {
  ProductScreen(
    String slug, {
    required int id,
    required double price,
    required bool featured,
    String? ref,
  });
}
'''),
          isEmpty,
        );
      });

      test(
        'passes optional int and double query parameters as nullable numbers',
        () async {
          final route = Route(
            path: '/catalog',
            parameters: [
              QueryParam('page', type: int, optional: true),
              QueryParam('minPrice', type: double, optional: true),
            ],
            screen: RouteScreen(
              'CatalogScreen',
              screenArguments: [
                RouteScreenArgs(
                  name: 'page',
                  sourceName: 'page',
                  source: ParameterSource.query,
                ),
                RouteScreenArgs(
                  name: 'minPrice',
                  sourceName: 'minPrice',
                  source: ParameterSource.query,
                ),
              ],
            ),
          );

          expect(
            await compile(route, '''
class CatalogScreen {
  CatalogScreen({int? page, double? minPrice});
}
'''),
            isEmpty,
          );
        },
        skip: 'Bug: optional int/double params generate int.parse(String?), '
            'which does not compile',
      );

      test('throws when a screen argument has no matching route parameter', () {
        final route = Route(
          path: '/users/:id',
          screen: RouteScreen(
            'UserScreen',
            screenArguments: [
              RouteScreenArgs(
                name: 'id',
                sourceName: 'id',
                source: ParameterSource.path,
              ),
            ],
          ),
        );

        expect(
          () => generate(route),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Missing RouteParameter for screen argument id'),
            ),
          ),
        );
      });
    });

    group('imports', () {
      test('resolves the route imports in declaration order', () {
        final imports = strategy.imports(
          Route(
            path: '/home',
            imports: [
              Import.features('home/home_screen.dart'),
              Import.core(ImportAnchor.coreWidgets, 'app_bar.dart'),
              Import.direct("import 'package:intl/intl.dart'"),
            ],
          ),
          registryContext(),
        );

        expect(imports, [
          "import 'package:{{app_name_sc}}/features/home/home_screen.dart';",
          "import 'package:{{app_name_sc}}/core/widgets/app_bar.dart';",
          "import 'package:intl/intl.dart';",
        ]);
      });

      test('returns no imports when the route declares none', () {
        expect(
          strategy.imports(Route(path: '/home'), registryContext()),
          isEmpty,
        );
      });
    });
  });
}
