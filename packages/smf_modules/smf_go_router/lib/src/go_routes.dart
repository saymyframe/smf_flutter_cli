import 'package:smf_contracts/smf_contracts.dart';

/// The code of the routes of an app for go_router: the items of the list of
/// routes of its `GoRouter`, the location it opens with, and the check of
/// the values of a location that the routes use.
final class GoRoutes {
  GoRoutes._({
    required this.routes,
    required this.mainNavigation,
    required this.valueChecks,
    required this.initialLocation,
    required this.hasMainNavigation,
  });

  /// Renders the routes of [facade] for an app that starts on [start], or
  /// on the fallback screen of the app entry if it is `null`, with a main
  /// navigation if [mainNavigation] is set, as a layout provides.
  ///
  /// The path `/` redirects to the start route, or shows the fallback
  /// screen. Every route of the facade becomes a `GoRoute` named by its
  /// full name, such as `home.details`, which the listeners of the screen
  /// get as the name of the screen, and navigator observers as the name of
  /// its page, with its children below it; a top-level route
  /// has its full path, a child its path relative to its parent. The
  /// screens are imported with prefixes of their own: `screen0`, `screen1`,
  /// and so on.
  ///
  /// With a main navigation and destinations, the destinations go into a
  /// `StatefulShellRoute.indexedStack`, a branch for each, in their order,
  /// with the routes below them: its builder shows the `AppShell` of the
  /// layout with the list of the destinations that the layout role
  /// generates in the same order, each with its label and its icon, the
  /// index of the selected branch, and `goBranch` to select another. The
  /// function `_mainNavigation()` of [mainNavigation] creates that route,
  /// so that the router can create it anew, and the list of routes calls
  /// it right after `/`: the router matches the destinations first, and the
  /// other top-level routes follow, outside the main navigation. Each
  /// branch starts on its destination and creates observers of its own,
  /// and so does the root navigator; the branches do not notify the
  /// observers of the root navigator, which would see their pages twice
  /// otherwise.
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
    final code = _RouteCode();
    const fallback = AppEntryRole.fallbackStartScreen;
    final root = start == null
        ? '  builder: (context, state) => const ${fallback.name}(),'
        : '  redirect: (context, state) => '
            '${SmfNames.dartString(start.fullPath)},';
    final destinations =
        mainNavigation ? facade.destinations : const <FacadeRoute>[];
    // The routes of the main navigation come first, so that their screens
    // get the first prefixes.
    final shell = destinations.isEmpty ? null : code.shellOf(destinations);
    final routes = [
      "GoRoute(\n  path: '/',\n$root\n)",
      if (shell != null) '_mainNavigation()',
      for (final feature in facade.features)
        for (final route in feature.routes)
          if (!destinations.contains(route)) code.of(route),
    ];
    return GoRoutes._(
      routes: Fragment(
        [for (final route in routes) '${_indented(route, '      ')},']
            .join('\n'),
        imports: [
          if (start == null) fallback.importRef,
          ...code.screens.values,
        ],
      ),
      mainNavigation: shell == null
          ? const Fragment('')
          : Fragment(
              '$_mainNavigation$shell;\n',
              imports: _layoutImports,
            ),
      valueChecks: Fragment(code.checksValues ? _checkValues : ''),
      initialLocation: SmfNames.dartString(start?.fullPath ?? '/'),
      hasMainNavigation: destinations.isNotEmpty,
    );
  }

  /// The items of the list of routes of `GoRouter`, with the imports of the
  /// screens: with a main navigation, a call of `_mainNavigation()` is in
  /// its place among them.
  final Fragment routes;

  /// The function `_mainNavigation()`, which creates the route of the main
  /// navigation, with the imports of the layout, or a fragment without code
  /// for routes without a main navigation. The code is a blank line and
  /// the function, for a line of its own between two declarations.
  final Fragment mainNavigation;

  /// The function that checks the values of a location, if a route needs
  /// it, or else a fragment without code.
  final Fragment valueChecks;

  /// The location the app opens with, as a Dart string: the full path of
  /// the start route, or `/`.
  final String initialLocation;

  /// Whether the routes have a main navigation, which a location in it can
  /// go on top of only while no page is shown over it.
  final bool hasMainNavigation;

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

  /// The imports of the `AppShell` of the layout and of the list of the
  /// destinations of the app, which the layout role generates.
  static final List<ImportRef> _layoutImports = [
    ImportRef.app(
      LayoutRole.appShell.importRef.uri,
      show: [LayoutRole.appShell.name],
    ),
    ImportRef.app(
      LayoutRole.destination.importRef.uri,
      show: const [LayoutRole.appDestinations],
    ),
  ];

  static String _indented(String code, String indent) =>
      code.split('\n').map((line) => '$indent$line').join('\n');

  /// The start of the function that creates the route of the main
  /// navigation, up to the route.
  static const _mainNavigation = '''

/// Creates the main navigation: a branch for each destination, in the order
/// of [${LayoutRole.appDestinations}], with the routes below it.
///
/// The router calls it again each time the main navigation leaves its
/// pages, because go_router keeps the pages of the branches under keys of
/// the route: with a new route, the main navigation comes back with each
/// branch on its destination. So what a branch has of its own, such as the
/// observers of its navigator, is created here, in each call.
StatefulShellRoute _mainNavigation() => ''';

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

/// Writes the code of the routes of [GoRoutes.of] and keeps what it needs:
/// the imports of the screens, each with a prefix of its own, and whether a
/// route checks the values of its location.
final class _RouteCode {
  /// The imports of the screens by URI, with their prefixes.
  final Map<String, ImportRef> screens = {};

  /// Whether a route checks the values of its location.
  bool checksValues = false;

  /// The prefix of the import of the screen of [import], which the first
  /// route with the screen gives it: `screen0`, `screen1`, and so on.
  String _prefixOf(ImportRef import) => screens
      .putIfAbsent(
        // A screen is a file of the app, which its path identifies.
        import.uri,
        () => import.withPrefix('screen${screens.length}'),
      )
      .prefix!;

  /// The `GoRoute` of [route], with its children.
  String of(FacadeRoute route) {
    final screen = route.route.screen;
    final params = route.route.params;
    // The redirect of the parent checks a path parameter of its own that
    // the route passes on, since go_router runs the redirects of every
    // route that matches the location.
    final checked = [
      for (final param in params)
        if (param.isRequired &&
            GoRoutes._mayBeMissing(param) &&
            !route.isInherited(param))
          param,
    ];
    checksValues |= checked.isNotEmpty;
    final widget = '${_prefixOf(screen.import)}.${screen.className}';
    final path = route.parent == null ? route.fullPath : route.route.path;
    return [
      'GoRoute(',
      '  path: ${SmfNames.dartString(path)},',
      '  name: ${SmfNames.dartString(route.fullName)},',
      if (checked.isNotEmpty) ..._redirectOf(checked),
      if (params.isEmpty)
        '  builder: (context, state) => const $widget(),'
      else ...[
        '  builder: (context, state) => $widget(',
        for (final param in params)
          '    ${param.name}: ${GoRoutes._argumentOf(param)},',
        '  ),',
      ],
      if (route.children.isNotEmpty) ...[
        '  routes: [',
        for (final child in route.children)
          '${GoRoutes._indented(of(child), '    ')},',
        '  ],',
      ],
      ')',
    ].join('\n');
  }

  /// The redirect of a route that checks the values of [checked].
  static List<String> _redirectOf(List<RouteParam> checked) {
    return [
      '  redirect: (context, state) => _checkValues({',
      for (final param in checked)
        '    ${SmfNames.dartString(param.name)}: ${GoRoutes._valueOf(param)},',
      '  }),',
    ];
  }

  /// The `StatefulShellRoute` of the main navigation with [destinations],
  /// with a branch for each.
  String shellOf(List<FacadeRoute> destinations) => [
        'StatefulShellRoute.indexedStack(',
        '  // The navigator of each branch has observers of its own, so the',
        '  // observers of the root navigator are not told about its pages.',
        '  notifyRootObserver: false,',
        '  builder: (context, state, shell) => ${LayoutRole.appShell.name}(',
        '    destinations: ${LayoutRole.appDestinations},',
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
          '${GoRoutes._indented(of(route), '        ')},',
          '      ],',
          '    ),',
        ],
        '  ],',
        ')',
      ].join('\n');
}
