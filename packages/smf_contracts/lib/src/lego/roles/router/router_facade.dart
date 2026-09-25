part of '../router.dart';

/// The key of a member of [RouterRole.screenAnnotations]: a screen of a
/// feature.
typedef ScreenKey = ({ModuleId feature, String screen});

/// The key of a member of [RouterRole.paramAnnotations]: a parameter of the
/// constructor of a screen of a feature.
typedef ParamKey = ({ModuleId feature, String screen, String param});

/// What the template of the router decides before rendering: the route the
/// app starts on.
///
/// It is the result of the router's `choose` hook; read it with
/// [RouterRole.startIn].
@immutable
final class RouterChoice {
  /// Creates the choice of the start route [startPath].
  const RouterChoice({this.startPath});

  /// The full path of the start route, or `null` if no route can start the
  /// app, which then starts on the fallback screen of the app entry.
  final String? startPath;
}

/// The routes of all modules of an app with their full paths, names and
/// classes, from which the router role generates the navigation facade.
///
/// The template of the router renders the facade from it and providers
/// render their routes from it, so both agree on every path and name.
/// Obtain it with [RouterRole.facadeOf].
final class RouterFacade {
  RouterFacade._(this.features);

  /// Resolves [data], the routes of the modules in the order the modules
  /// were selected; data of the same module is merged.
  ///
  /// Routes live under the namespace of their module, so data without a
  /// module as its origin is left out; the router's template reports it.
  factory RouterFacade.of(Iterable<RoleData<RoutesData>> data) {
    final routes = <ModuleId, List<Route>>{};
    for (final entry in data) {
      if (entry.origin case ModuleOrigin(:final module)) {
        routes.putIfAbsent(module, () => []).addAll(entry.value.routes);
      }
    }
    return RouterFacade._(
      List.unmodifiable([
        for (final MapEntry(key: module, value: moduleRoutes) in routes.entries)
          if (moduleRoutes.isNotEmpty) FacadeFeature._(module, moduleRoutes),
      ]),
    );
  }

  /// The modules with routes, in the order they were selected.
  final List<FacadeFeature> features;

  /// Every route of the app, parents before their children, in the order of
  /// the features and their routes.
  List<FacadeRoute> get routes =>
      [for (final feature in features) ...feature.allRoutes];

  /// The top-level routes that are destinations of the main navigation, in
  /// the order of the features and their routes.
  List<FacadeRoute> get destinations => [
        for (final feature in features)
          for (final route in feature.routes)
            if (route.route.destination != null) route,
      ];

  /// The route whose full path is [fullPath], such as `/home/details/:id`,
  /// or `null` if there is none.
  FacadeRoute? routeAt(String fullPath) {
    for (final route in routes) {
      if (route.fullPath == fullPath) return route;
    }
    return null;
  }

  /// The Dart code of the navigation facade: a location class per route,
  /// `AppNav` with a getter per feature, a navigation class per feature,
  /// and the `context.nav` extension.
  ///
  /// The code belongs in `lib/core/router/navigation.dart` of the router's
  /// template, after `AppLocation` and `NavLink`.
  String toDart() {
    final buffer = StringBuffer();
    for (final route in routes) {
      route._writeLocation(buffer);
    }
    if (routes.any((route) => route.params.any(_isQuery))) {
      buffer.write(_withQuery);
    }
    _writeNav(buffer);
    for (final feature in features) {
      feature._writeRoutes(buffer);
    }
    return buffer.toString();
  }

  void _writeNav(StringBuffer buffer) {
    buffer
      ..writeln()
      ..writeln('/// Typed navigation to the routes of the app.')
      ..writeln('extension AppNavigation on BuildContext {')
      ..writeln('  /// The routes of the app by module.');
    if (features.isEmpty) {
      buffer
        ..writeln('  AppNav get nav => const AppNav._();')
        ..writeln('}')
        ..writeln()
        ..writeln('/// The routes of the app by module; it has none.')
        ..writeln('final class AppNav {')
        ..writeln('  const AppNav._();')
        ..writeln('}');
      return;
    }
    buffer
      ..writeln('  AppNav get nav => AppNav._(this);')
      ..writeln('}')
      ..writeln()
      ..writeln('/// The routes of the app by module, as `context.nav`.')
      ..writeln('final class AppNav {')
      ..writeln('  const AppNav._(this._context);')
      ..writeln()
      ..writeln('  final BuildContext _context;');
    for (final feature in features) {
      buffer
        ..writeln()
        ..writeln('  /// The routes of the module `${feature.module}`.')
        ..writeln(
          '  ${feature.routesClass} get ${feature.accessor} => '
          '${feature.routesClass}._(_context);',
        );
    }
    buffer.writeln('}');
  }

  static bool _isQuery(RouteParam param) =>
      param.source == RouteParamSource.query;

  static const _withQuery = r'''

String _withQuery(String path, Map<String, String?> query) {
  query.removeWhere((key, value) => value == null);
  return query.isEmpty ? path : '$path?${Uri(queryParameters: query).query}';
}
''';
}

/// The routes of one module in a [RouterFacade].
final class FacadeFeature {
  FacadeFeature._(this.module, List<Route> routes) {
    this.routes = List.unmodifiable([
      for (final route in routes) FacadeRoute._(this, route, null),
    ]);
  }

  /// The module that declares the routes.
  final ModuleId module;

  /// The top-level routes of the module, in order.
  late final List<FacadeRoute> routes;

  /// The name of the feature in `context.nav`, such as `home`.
  String get accessor => module.lowerCamelCase;

  /// The name of the class with the feature's routes, such as
  /// `HomeRoutes`.
  ///
  /// Its suffix differs from those of `AppNav` and the location classes, so
  /// no module id makes the names collide.
  String get routesClass => '${module.upperCamelCase}Routes';

  /// The path all routes of the module start with, such as `/home`.
  String get namespace => '/${module.value}';

  /// Every route of the module, parents before their children.
  List<FacadeRoute> get allRoutes =>
      [for (final route in routes) ...route.withDescendants];

  void _writeRoutes(StringBuffer buffer) {
    buffer
      ..writeln()
      ..writeln('/// The routes of the module `$module`.')
      ..writeln('final class $routesClass {')
      ..writeln('  const $routesClass._(this._context);')
      ..writeln()
      ..writeln('  final BuildContext _context;');
    for (final route in allRoutes) {
      final params = route.params.isEmpty
          ? ''
          : '{${route.params.map(_parameter).join(', ')}}';
      buffer
        ..writeln()
        ..writeln('  /// The route `${route.fullName}`: `${route.fullPath}`.')
        ..writeln(
          '  NavLink ${route.route.name}($params) => '
          'NavLink(_context, ${route._newLocation()});',
        );
    }
    buffer.writeln('}');
  }

  static String _parameter(RouteParam param) => param.isRequired
      ? 'required ${param.typeName} ${param.name}'
      : '${param.typeName}? ${param.name}';

  @override
  String toString() => 'routes of $module';
}

/// A route of a [RouterFacade]: its full path, full name and the classes
/// the facade generates for it.
final class FacadeRoute {
  FacadeRoute._(this.feature, this.route, this.parent) {
    fullPath = switch (parent) {
      null => route.path == '/'
          ? feature.namespace
          : '${feature.namespace}${route.path}',
      final parent => '${parent.fullPath}/${route.path}',
    };
    children = List.unmodifiable([
      for (final child in route.children) FacadeRoute._(feature, child, this),
    ]);
  }

  /// The feature that declares the route.
  final FacadeFeature feature;

  /// The route as the module declared it.
  final Route route;

  /// The route this one is shown on top of, or `null` for a top-level
  /// route.
  final FacadeRoute? parent;

  /// The routes shown on top of this one.
  late final List<FacadeRoute> children;

  /// The full path of the route, with its path parameters as `:<name>`
  /// segments, such as `/home/details/:id`.
  late final String fullPath;

  /// The full name of the route, such as `home.details`.
  String get fullName => '${feature.module}.${route.name}';

  /// The name of the location class of the route, such as
  /// `HomeDetailsLocation`.
  String get locationClass {
    final name = route.name;
    final upper = name.isEmpty ? '' : name[0].toUpperCase() + name.substring(1);
    return '${feature.module.upperCamelCase}${upper}Location';
  }

  /// The routes from the top-level route down to this one: the stack that
  /// going to this route shows.
  List<FacadeRoute> get chain => [...?parent?.chain, this];

  /// The top-level route of [chain]; its destination, if any, is the branch
  /// of the main navigation this route is in.
  FacadeRoute get topLevel => parent?.topLevel ?? this;

  /// This route followed by all routes below it, parents first.
  List<FacadeRoute> get withDescendants =>
      [this, for (final child in children) ...child.withDescendants];

  /// The path parameters of [chain], the parents' first, each once: the
  /// values the location needs to build its path.
  List<RouteParam> get pathParams {
    final params = <String, RouteParam>{};
    for (final route in chain) {
      for (final param in route.route.params) {
        if (param.source == RouteParamSource.path) {
          params.putIfAbsent(param.name, () => param);
        }
      }
    }
    return List.unmodifiable(params.values);
  }

  /// Whether [param], a parameter of [route], is a path parameter of a
  /// parent that the route also passes to its screen, such as `userId` of
  /// `/users/:userId` for its child `posts/:postId`.
  ///
  /// A router that annotates parameters marks such a one as inherited, as
  /// auto_route does with `@PathParam.inherit()`.
  bool isInherited(RouteParam param) =>
      param.source == RouteParamSource.path &&
      !_segmentsOf(route.path).contains(param.name);

  /// The parameters of the location and of the facade's navigation method:
  /// [pathParams], then the query parameters of the route itself.
  List<RouteParam> get params => [
        ...pathParams,
        for (final param in route.params)
          if (param.source == RouteParamSource.query) param,
      ];

  /// Whether navigating to the route needs a value, so it cannot start the
  /// app.
  bool get hasRequiredParams => params.any((param) => param.isRequired);

  /// The key of the route's screen in [RouterRole.screenAnnotations].
  ScreenKey get screenKey =>
      (feature: feature.module, screen: route.screen.className);

  /// The key of the route's parameter [param] in
  /// [RouterRole.paramAnnotations].
  ParamKey paramKey(RouteParam param) => (
        feature: feature.module,
        screen: route.screen.className,
        param: param.name,
      );

  String _newLocation() {
    final arguments = [
      for (final param in params) '${param.name}: ${param.name}',
    ];
    return arguments.isEmpty
        ? 'const $locationClass()'
        : '$locationClass(${arguments.join(', ')})';
  }

  void _writeLocation(StringBuffer buffer) {
    final params = this.params;
    buffer
      ..writeln()
      ..writeln('/// The location of `$fullName`: `$fullPath`.')
      ..writeln('final class $locationClass extends AppLocation {');
    if (params.isEmpty) {
      buffer.writeln('  /// Creates the location.');
    } else {
      buffer
          .writeln('  /// Creates the location with the values of the route.');
    }
    final fields = [
      for (final param in params)
        '${param.isRequired ? 'required ' : ''}this.${param.name}',
    ];
    final named = fields.isEmpty ? '' : '{${fields.join(', ')}}';
    buffer.writeln('  const $locationClass($named);');
    for (final param in params) {
      final kind = param.source == RouteParamSource.path ? 'path' : 'query';
      buffer
        ..writeln()
        ..writeln('  /// The value of the $kind parameter `${param.name}`.')
        ..writeln(
          '  final ${param.typeName}${param.optional ? '?' : ''} '
          '${param.name};',
        );
    }
    buffer
      ..writeln()
      ..writeln('  @override')
      ..writeln(
        '  String get routeName => ${SmfNames.dartString(fullName)};',
      )
      ..writeln()
      ..writeln('  @override')
      ..writeln('  String get path => ${_pathExpression()};');
    if (parent case final parent?) {
      buffer
        ..writeln()
        ..writeln('  @override')
        ..writeln('  AppLocation get parent => ${parent._parentLocation()};');
    }
    buffer.writeln('}');
  }

  /// The expression that creates this route's location as the parent of a
  /// child: with the path parameters only, which the child also has.
  String _parentLocation() {
    final arguments = [
      for (final param in pathParams) '${param.name}: ${param.name}',
    ];
    return arguments.isEmpty
        ? 'const $locationClass()'
        : '$locationClass(${arguments.join(', ')})';
  }

  String _pathExpression() {
    final segments = fullPath.split('/').map((segment) {
      if (!segment.startsWith(':')) return segment;
      final name = segment.substring(1);
      // router.routes rejects a segment without a parameter; this keeps the
      // code of invalid routes printable.
      final isString = pathParams
          .where((param) => param.name == name)
          .every((param) => param.type == String);
      return isString ? '\${Uri.encodeComponent($name)}' : '\$$name';
    });
    final path = "'${segments.join('/')}'";
    final query = [
      for (final param in route.params)
        if (param.source == RouteParamSource.query)
          "'${param.name}': ${_queryValue(param)}",
    ];
    return query.isEmpty ? path : '_withQuery($path, {${query.join(', ')}})';
  }

  static String _queryValue(RouteParam param) {
    if (param.type == String) return param.name;
    return param.optional
        ? '${param.name}?.toString()'
        : '${param.name}.toString()';
  }

  @override
  String toString() => 'route $fullName';
}
