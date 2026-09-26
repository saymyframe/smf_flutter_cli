import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, three features, a module with a navigator observer, and a
/// layout.
const List<SmfModule> testModules = [
  FlutterCoreModule(),
  GoRouterModule(),
  CatalogFeature(),
  SettingsFeature(),
  ProfileFeature(),
  ObservingModule(),
  TabsLayout(),
];

/// The import of the icons of the destinations of the features.
const _icons = ImportRef('package:flutter/material.dart', show: ['Icons']);

/// What the contract harness finds for the app of [modules] among
/// [testModules], which has no errors and is rendered.
Future<ContractResult> renderedApp(
  List<ModuleId> modules, {
  Map<String, String?> roleOptions = const {},
}) async {
  final result = await ContractHarness(ModuleRegistry(testModules)).check(
    ContractCase(
      modules.join(', '),
      requested: modules,
      roleOptions: roleOptions,
    ),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// A feature for the tests: a catalog that the app can start on, with
/// routes whose parameters have every type and source a route can have.
///
/// - `/catalog`: the start candidate and the destination Catalog, with
///   optional query parameters of every type;
/// - `/catalog/items/:id` below it, with an `int` path parameter and an
///   optional query parameter, and `/catalog/items/:id/reviews/:reviewId`
///   below that, which passes the `id` of its parent to its screen;
/// - `/catalog/compare`, with required `int` query parameters, and
///   `/catalog/search`, with a required `String` one;
/// - `/catalog/prices/:amount/:exact`, with a `double` and a `bool` path
///   parameter, and `/catalog/tags/:tag`, with a `String` one, whose screens
///   share a file with those of `/catalog/compare` and `/catalog/search`.
final class CatalogFeature extends SmfModule {
  /// Creates the module.
  const CatalogFeature();

  /// The id of the module.
  static const id = ModuleId('catalog');

  static const _folder = 'features/catalog';

  static const _more = ImportRef.app('$_folder/more_screens.dart');

  static const _catalog = Destination(
    label: 'Catalog',
    icon: Fragment('Icons.list', imports: [_icons]),
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A catalog (test)',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('catalog', {
            'lib/$_folder/catalog_screen.dart': screen(id, 'CatalogScreen', {
              'page': 'int?',
              'minPrice': 'double?',
              'onSale': 'bool?',
              'search': 'String?',
            }),
            'lib/$_folder/item_screen.dart': screen(
              id,
              'ItemScreen',
              {'id': 'int', 'variant': 'String?'},
            ),
            'lib/$_folder/review_screen.dart': screen(
              id,
              'ReviewScreen',
              {'id': 'int', 'reviewId': 'String'},
            ),
            'lib/$_folder/more_screens.dart': [
              screen(id, 'CompareScreen', {'left': 'int', 'right': 'int'}),
              screen(
                id,
                'PriceScreen',
                {'amount': 'double', 'exact': 'bool'},
                imports: false,
              ),
              screen(id, 'TagScreen', {'tag': 'String'}, imports: false),
              screen(id, 'SearchScreen', {'q': 'String'}, imports: false),
            ].join('\n'),
          }),
        ),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: 'catalog',
              screen: ScreenRef(
                'CatalogScreen',
                import: ImportRef.app('$_folder/catalog_screen.dart'),
              ),
              destination: _catalog,
              startCandidate: true,
              params: [
                RouteParam.query('page', type: int, optional: true),
                RouteParam.query('minPrice', type: double, optional: true),
                RouteParam.query('onSale', type: bool, optional: true),
                RouteParam.query('search', type: String, optional: true),
              ],
              children: [
                Route(
                  'items/:id',
                  name: 'item',
                  screen: ScreenRef(
                    'ItemScreen',
                    import: ImportRef.app('$_folder/item_screen.dart'),
                  ),
                  params: [
                    RouteParam.path('id', type: int),
                    RouteParam.query('variant', type: String, optional: true),
                  ],
                  children: [
                    Route(
                      'reviews/:reviewId',
                      name: 'review',
                      screen: ScreenRef(
                        'ReviewScreen',
                        import: ImportRef.app('$_folder/review_screen.dart'),
                      ),
                      params: [
                        RouteParam.path('id', type: int),
                        RouteParam.path('reviewId', type: String),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Route(
              '/compare',
              name: 'compare',
              screen: ScreenRef('CompareScreen', import: _more),
              params: [
                RouteParam.query('left', type: int),
                RouteParam.query('right', type: int),
              ],
            ),
            Route(
              '/prices/:amount/:exact',
              name: 'price',
              screen: ScreenRef('PriceScreen', import: _more),
              params: [
                RouteParam.path('amount', type: double),
                RouteParam.path('exact', type: bool),
              ],
            ),
            Route(
              '/tags/:tag',
              name: 'tag',
              screen: ScreenRef('TagScreen', import: _more),
              params: [RouteParam.path('tag', type: String)],
            ),
            Route(
              '/search',
              name: 'search',
              screen: ScreenRef('SearchScreen', import: _more),
              params: [RouteParam.query('q', type: String)],
            ),
          ]),
        ),
      ];
}

/// A feature for the tests with a route, `/settings`, the destination
/// Settings, and a child of it, `/settings/about`, neither of which is a
/// start candidate.
final class SettingsFeature extends SmfModule {
  /// Creates the module.
  const SettingsFeature();

  /// The id of the module.
  static const id = ModuleId('settings');

  static const _file = 'features/settings/settings_screen.dart';

  static const _about = 'features/settings/about_screen.dart';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Settings (test)',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('settings', {
            'lib/$_file': screen(id, 'SettingsScreen', const {}),
            'lib/$_about': screen(id, 'AboutScreen', const {}),
          }),
        ),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: 'settings',
              screen: ScreenRef('SettingsScreen', import: ImportRef.app(_file)),
              destination: Destination(
                label: 'Settings',
                icon: Fragment('Icons.settings', imports: [_icons]),
              ),
              children: [
                Route(
                  'about',
                  name: 'about',
                  screen: ScreenRef(
                    'AboutScreen',
                    import: ImportRef.app(_about),
                  ),
                ),
              ],
            ),
          ]),
        ),
      ];
}

/// A feature for the tests with one route, `/profile`, the destination
/// Profile, which the app can start on too.
final class ProfileFeature extends SmfModule {
  /// Creates the module.
  const ProfileFeature();

  /// The id of the module.
  static const id = ModuleId('profile');

  static const _file = 'features/profile/profile_screen.dart';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A profile (test)',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('profile', {
            'lib/$_file': screen(id, 'ProfileScreen', const {}),
          }),
        ),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: 'profile',
              screen: ScreenRef('ProfileScreen', import: ImportRef.app(_file)),
              destination: Destination(
                label: 'Profile',
                icon: Fragment('Icons.person', imports: [_icons]),
              ),
              startCandidate: true,
            ),
          ]),
        ),
      ];
}

/// A layout for the tests, whose `AppShell` shows the screen of the selected
/// destination and nothing else.
final class TabsLayout extends SmfModule {
  /// Creates the module.
  const TabsLayout();

  /// The id of the module.
  static const id = ModuleId('tabs');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A main navigation (test)',
        kind: ModuleKinds.layout,
        providers: [_TabsProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('tabs', {
            LayoutRole.appShellFile: [
              "import 'package:flutter/widgets.dart';",
              '',
              "import 'destination.dart';",
              '',
              '/// The main navigation of the tests.',
              'class AppShell extends StatelessWidget {',
              '  /// Creates the main navigation.',
              '  const AppShell({',
              '    required this.destinations,',
              '    required this.currentIndex,',
              '    required this.onSelect,',
              '    required this.body,',
              '    super.key,',
              '  });',
              '',
              '  /// The destinations.',
              '  final List<Destination> destinations;',
              '',
              '  /// The index of the selected destination.',
              '  final int currentIndex;',
              '',
              '  /// Selects the destination at an index.',
              '  final ValueChanged<int> onSelect;',
              '',
              '  /// The screen of the selected destination.',
              '  final Widget body;',
              '',
              '  @override',
              '  Widget build(BuildContext context) => body;',
              '}',
              '',
            ].join('\n'),
          }),
        ),
      ];
}

/// The layout role, with any number of destinations.
final class _TabsProvider extends LayoutProvider {
  const _TabsProvider();
}

/// A module that watches the navigation of the app when it has a router,
/// as analytics would.
final class ObservingModule extends SmfModule {
  /// Creates the module.
  const ObservingModule();

  /// The id of the module.
  static const id = ModuleId('observing');

  static const _file = ImportRef.app('core/observing/test_observer.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A navigator observer (test)',
        kind: ModuleKinds.infrastructure,
        uses: {routerRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('observing', {
            'lib/core/observing/test_observer.dart':
                "import 'package:flutter/widgets.dart';\n"
                    '\n'
                    '/// Watches the navigation of the app.\n'
                    'final class TestObserver extends NavigatorObserver {}\n',
          }),
        ),
        const SocketContribution.item(
          RouterRole.observers,
          Fragment('() => TestObserver()', imports: [_file]),
          when: {routerRole},
        ),
      ];
}

/// The template of the screen [name] of the feature [feature], whose
/// constructor takes [params], a type by name, with the tags of the
/// annotations of the class and of each parameter; with the import of the
/// widgets unless [imports] is `false`, for a screen after the first of its
/// file.
String screen(
  ModuleId feature,
  String name,
  Map<String, String> params, {
  bool imports = true,
}) {
  final screenTag =
      RouterRole.screenAnnotations((feature: feature, screen: name)).tag;
  String paramTag(String param) => RouterRole.paramAnnotations(
        (feature: feature, screen: name, param: param),
      ).tag;
  return [
    if (imports) "import 'package:flutter/widgets.dart';\n",
    '/// A screen of the tests.',
    '{{{$screenTag}}}',
    'class $name extends StatelessWidget {',
    '  /// Creates the screen.',
    '  const $name({',
    '    super.key,',
    for (final MapEntry(key: param, value: type) in params.entries) ...[
      '    {{{${paramTag(param)}}}}',
      '    ${type.endsWith('?') ? '' : 'required '}this.$param,',
    ],
    '  });',
    for (final MapEntry(key: param, value: type) in params.entries) ...[
      '',
      '  /// A value of the location.',
      '  final $type $param;',
    ],
    '',
    '  @override',
    '  Widget build(BuildContext context) => const SizedBox();',
    '}',
    '',
  ].join('\n');
}

/// A mason bundle named [name] with the text [files] by path.
MasonBundle bundleOf(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );
