import 'package:smf_contracts/lego.dart';

/// The code of the routes of an app for go_router: the items of the list of
/// routes of its `GoRouter`, the location it opens with, and the check of
/// the values of a location that the routes use.
final class GoRoutes {
  GoRoutes._({
    required this.routes,
    required this.valueChecks,
    required this.initialLocation,
  });

  /// Renders the routes of [facade] for an app that starts on [start], or
  /// on the fallback screen of the app entry if it is `null`, with a main
  /// navigation if [mainNavigation] is set, as a layout provides.
  ///
  /// The path `/` redirects to the start route, or shows the fallback
  /// screen. Every route of the facade becomes a `GoRoute` named by its
  /// full name, such as `home.details`, which navigator observers report as
  /// the name of the screen, with its children below it; a top-level route
  /// has its full path, a child its path relative to its parent. The
  /// screens are imported with prefixes of their own: `screen0`, `screen1`,
  /// and so on.
  ///
  /// With a main navigation and destinations, the destinations go into a
  /// `StatefulShellRoute.indexedStack`, a branch for each, in their order,
  /// with the routes below them: its builder shows the `AppShell` of the
  /// layout with the destinations as constants, the index of the selected
  /// branch, and `goBranch` to select another. It comes right after `/`, so
  /// the router matches the destinations first, and the other top-level
  /// routes follow it, outside the main navigation. Each branch starts on
  /// its destination and creates observers of its own, and so does the
  /// root navigator; the branches do not notify the observers of the root
  /// navigator, which would see their pages twice otherwise.
  ///
  /// A screen gets the values of its parameters from the location, parsed
  /// with `tryParse`: a path parameter from the path, including one of a
  /// parent, and a query parameter from the query; a `bool` is `true` or
  /// `false` exactly. An optional value that the location does not have, or
  /// not of its type, is `null`; a route whose required value is missing or
  /// not of its type redirects through [valueChecks], which throws a
  /// `GoException`, so that the router shows its error screen instead. The
  /// redirect of a parent checks its path parameters for its children.
  factory GoRoutes.of(
    RouterFacade facade, {
    FacadeRoute? start,
    bool mainNavigation = false,
  }) {
    final screens = <String, ImportRef>{};
    String prefixOf(ImportRef import) => screens
        .putIfAbsent(
          // A screen is a file of the app, which its path identifies.
          import.uri,
          () => import.withPrefix('screen${screens.length}'),
        )
        .prefix!;
    var checksValues = false;

    String code(FacadeRoute route) {
      final screen = route.route.screen;
      final params = route.route.params;
      // The redirect of the parent checks a path parameter of its own that
      // the route passes on, since go_router runs the redirects of every
      // route that matches the location.
      final checked = [
        for (final param in params)
          if (param.isRequired &&
              _mayBeMissing(param) &&
              !route.isInherited(param))
            param,
      ];
      checksValues |= checked.isNotEmpty;
      final widget = '${prefixOf(screen.import)}.${screen.className}';
      final path = route.parent == null ? route.fullPath : route.route.path;
      return [
        'GoRoute(',
        '  path: ${SmfNames.dartString(path)},',
        '  name: ${SmfNames.dartString(route.fullName)},',
        if (checked.isNotEmpty) ...[
          '  redirect: (context, state) => _checkValues({',
          for (final param in checked)
            '    ${SmfNames.dartString(param.name)}: ${_valueOf(param)},',
          '  }),',
        ],
        if (params.isEmpty)
          '  builder: (context, state) => const $widget(),'
        else ...[
          '  builder: (context, state) => $widget(',
          for (final param in params)
            '    ${param.name}: ${_argumentOf(param)},',
          '  ),',
        ],
        if (route.children.isNotEmpty) ...[
          '  routes: [',
          for (final child in route.children)
            '${_indented(code(child), '    ')},',
          '  ],',
        ],
        ')',
      ].join('\n');
    }

    const fallback = AppEntryRole.fallbackStartScreen;
    final root = start == null
        ? '  builder: (context, state) => const ${fallback.name}(),'
        : '  redirect: (context, state) => '
            '${SmfNames.dartString(start.fullPath)},';
    final destinations =
        mainNavigation ? facade.destinations : const <FacadeRoute>[];
    final routes = [
      "GoRoute(\n  path: '/',\n$root\n)",
      if (destinations.isNotEmpty)
        [
          'StatefulShellRoute.indexedStack(',
          '  // The navigator of each branch has observers of its own, so the',
          '  // observers of the root navigator are not told about its pages.',
          '  notifyRootObserver: false,',
          '  builder: (context, state, shell) => AppShell(',
          '    destinations: const [',
          for (final route in destinations)
            '      ${_destinationOf(route.route.destination!)},',
          '    ],',
          '    currentIndex: shell.currentIndex,',
          '    onSelect: shell.goBranch,',
          '    body: shell,',
          '  ),',
          '  branches: [',
          for (final route in destinations) ...[
            '    StatefulShellBranch(',
            '      initialLocation: ${SmfNames.dartString(route.fullPath)},',
            '      observers: _observers(),',
            '      routes: [',
            '${_indented(code(route), '        ')},',
            '      ],',
            '    ),',
          ],
          '  ],',
          ')',
        ].join('\n'),
      for (final feature in facade.features)
        for (final route in feature.routes)
          if (!destinations.contains(route)) code(route),
    ];
    return GoRoutes._(
      routes: Fragment(
        [for (final route in routes) '${_indented(route, '      ')},']
            .join('\n'),
        imports: [
          if (start == null) fallback.importRef,
          ...screens.values,
          if (destinations.isNotEmpty) ...[
            ImportRef.app(
              _appPathOf(LayoutRole.appShellFile),
              show: [LayoutRole.appShell.name],
            ),
            ImportRef.app(
              _appPathOf(LayoutRole.destinationFile),
              show: const ['Destination'],
            ),
            for (final route in destinations)
              ...route.route.destination!.icon.imports,
          ],
        ],
      ),
      valueChecks: Fragment(checksValues ? _checkValues : ''),
      initialLocation: SmfNames.dartString(start?.fullPath ?? '/'),
    );
  }

  /// The items of the list of routes of `GoRouter`, with the imports of the
  /// screens.
  final Fragment routes;

  /// The function that checks the values of a location, if a route needs
  /// it, or else a fragment without code.
  final Fragment valueChecks;

  /// The location the app opens with, as a Dart string: the full path of
  /// the start route, or `/`.
  final String initialLocation;

  /// Whether the value of [param] may be missing from a location that
  /// matches the route: every value but that of a path parameter of type
  /// `String`, which the path always has.
  static bool _mayBeMissing(RouteParam param) =>
      param.source == RouteParamSource.query || param.type != String;

  /// The value of [param] in the `GoRouterState` `state`, or `null` if the
  /// location does not have it or it is not of its type.
  static String _valueOf(RouteParam param) {
    final name = SmfNames.dartString(param.name);
    final text = param.source == RouteParamSource.path
        ? 'state.pathParameters[$name]'
        : 'state.uri.queryParameters[$name]';
    return switch (param.typeName) {
      'int' || 'double' || 'bool' => "${param.typeName}.tryParse($text ?? '')",
      _ => text,
    };
  }

  /// The argument of [param] for the screen: its value, which a location
  /// that matches the route has if the screen requires it, since the path
  /// has it or the redirect of the route has checked it.
  static String _argumentOf(RouteParam param) =>
      param.isRequired ? '${_valueOf(param)}!' : _valueOf(param);

  /// The constant `Destination` of the layout for [destination].
  static String _destinationOf(Destination destination) =>
      'Destination(label: ${SmfNames.dartString(destination.label)}, '
      'icon: ${destination.icon.code})';

  /// The path below `lib/` of [path], a path from the root of the app such
  /// as `lib/core/layout/app_shell.dart`.
  static String _appPathOf(String path) => path.substring('lib/'.length);

  static String _indented(String code, String indent) =>
      code.split('\n').map((line) => '$indent$line').join('\n');

  static const _checkValues = r'''

/// Lets a route show its screen when the location has the values it
/// requires: [values] has the value of each by name, or `null` for one that
/// is missing or not of its type. Otherwise throws a [GoException], so that
/// the router shows its error screen.
String? _checkValues(Map<String, Object?> values) {
  final invalid = [
    for (final MapEntry(:key, :value) in values.entries)
      if (value == null) key,
  ];
  if (invalid.isEmpty) return null;
  throw GoException('The location has no valid ${invalid.join(', ')}.');
}''';
}
