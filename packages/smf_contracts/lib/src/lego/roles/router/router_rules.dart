part of '../router.dart';

const _segment = '(?:[a-z0-9][a-z0-9_-]*|:[a-z][a-zA-Z0-9]*)';
final RegExp _topLevelPath = RegExp('^/\$|^(?:/$_segment)+\$');
final RegExp _childPath = RegExp('^$_segment(?:/$_segment)*\$');
final RegExp _lowerCamelCase = RegExp(r'^[a-z][a-zA-Z0-9]*$');
final RegExp _upperCamelCase = RegExp(r'^[A-Z][a-zA-Z0-9]*$');

/// Names that no generated member can have: the members of `Object`, and
/// the types of `dart:core` that the facade writes in lowercase, which a
/// member of the same name would hide.
const Set<String> _reservedMemberNames = {
  'bool',
  'double',
  'dynamic',
  'hashCode',
  'int',
  'noSuchMethod',
  'num',
  'runtimeType',
  'toString',
};

/// Names a parameter cannot have: the reserved member names, the members of
/// the location classes and the `key` of a widget.
const Set<String> _reservedParamNames = {
  ..._reservedMemberNames,
  'chain',
  'key',
  'parent',
  'path',
  'routeName',
};

bool _isMemberName(String name, Set<String> reserved) =>
    _lowerCamelCase.hasMatch(name) &&
    SmfNames.isDartIdentifier(name) &&
    !reserved.contains(name);

/// The path parameters of [path], a path of a route, by name.
Set<String> _segmentsOf(String path) => {
      for (final segment in path.split('/'))
        if (segment.startsWith(':')) segment.substring(1),
    };

List<SmfIssue> _checkRoutes(ModuleRuleInput<RoutesData> input) {
  final origin = ModuleOrigin(input.module.id);
  final routes = [for (final data in input.data) ...data.value.routes];
  final problems = <String>[
    if (input.data.isNotEmpty && routes.isEmpty)
      'The module contributes routes data without routes.',
  ];
  final warnings = <SmfIssue>[];
  final names = <String, Route>{};
  final screens = <String, Route>{};
  final patterns = <String, (Route, String)>{};
  // The routes checked so far, in the order they are declared, in which a
  // router matches them when the app has no main navigation.
  final earlier = <_PlacedRoute>[];
  // The routes that the order of the declaration leaves unreachable, or that
  // match the same locations as an earlier route.
  final reported = <_PlacedRoute>{};

  // The path of the module's root route `/` is empty, so a parent path does
  // not tell a child from a top-level route.
  void check(
    Route route, {
    required String? parentPath,
    required List<RouteParam> ancestors,
    required List<Route> chain,
  }) {
    final topLevel = parentPath == null;
    final path = topLevel
        ? (route.path == '/' ? '' : route.path)
        : '$parentPath/${route.path}';
    final label = 'The route "${route.name}" (${route.path})';
    final placed = _PlacedRoute(route, path, [...chain, route]);

    if (!(topLevel ? _topLevelPath : _childPath).hasMatch(route.path)) {
      problems.add(
        topLevel
            ? '$label has an invalid path; a top-level path starts with /, '
                'such as / or /settings/:id.'
            : '$label has an invalid path; the path of a child has no '
                'leading /, such as details/:id.',
      );
    }
    if (!_isMemberName(route.name, _reservedMemberNames)) {
      problems.add(
        '$label needs a name that is a lowerCamelCase Dart identifier, such '
        'as details, other than '
        '${(_reservedMemberNames.toList()..sort()).join(', ')}.',
      );
    }
    if (names.putIfAbsent(route.name, () => route) != route) {
      problems.add('Two routes of the module are named "${route.name}".');
    }
    if (patterns.putIfAbsent(placed.pattern, () => (route, path))
        case (
          final other,
          final otherPath,
        ) when other != route) {
      reported.add(placed);
      problems.add(
        otherPath == path
            ? 'Two routes of the module have the path "$path".'
            : 'The routes "${other.name}" and "${route.name}" have the paths '
                '"$otherPath" and "$path", which match the same locations.',
      );
    } else {
      final (:unreachable, :ambiguous) = _reachability(placed, earlier);
      if (unreachable != null) {
        reported.add(placed);
        problems.add(unreachable);
      }
      if (ambiguous != null) {
        warnings.add(SmfIssue.warning(ambiguous, origin: origin));
      }
    }
    earlier.add(placed);
    problems
      ..addAll(_screenProblems(route, label, screens))
      ..addAll(_paramProblems(route, label, ancestors));

    final ancestorPath = [
      for (final param in ancestors)
        if (param.source == RouteParamSource.path) param,
    ];
    final required = {
      for (final param in [...ancestorPath, ...route.params])
        if (param.isRequired) param.name: param,
    }.values;
    if (route.startCandidate && required.isNotEmpty) {
      problems.add(
        '$label is a start candidate but needs ${required.join(', ')}; the '
        'app can only start on a route without required parameters.',
      );
    }
    if (route.destination case final destination?) {
      if (!topLevel) {
        problems.add(
          '$label is a child, so it cannot be a destination of the main '
          'navigation.',
        );
      }
      if (required.isNotEmpty) {
        problems.add(
          '$label is a destination of the main navigation but needs '
          '${required.join(', ')}; a destination is reached without values.',
        );
      }
      if (destination.label.trim().isEmpty) {
        problems.add('$label has a destination without a label.');
      }
      final icon = destination.icon;
      if (icon.isWrapper || icon.code.trim().isEmpty) {
        problems.add(
          '$label has a destination whose icon is not an expression, such '
          'as Icons.home.',
        );
      }
      problems.addAll(icon.problems());
    }
    if (route.children.isNotEmpty &&
        route.params.any(
          (param) => param.source == RouteParamSource.query && param.isRequired,
        )) {
      problems.add(
        '$label has children, so its query parameters must be optional: '
        'navigating to a child rebuilds it without them.',
      );
    }

    final known = {for (final param in ancestors) param.name};
    for (final child in route.children) {
      check(
        child,
        parentPath: path,
        ancestors: [
          ...ancestors,
          for (final param in route.params)
            if (!known.contains(param.name)) param,
        ],
        chain: placed.chain,
      );
    }
  }

  for (final route in routes) {
    check(route, parentPath: null, ancestors: const [], chain: const []);
  }
  // In an app with a main navigation, the router matches the destinations
  // first, each with the routes below it, so a route outside the main
  // navigation comes after the routes in it that are declared later too.
  for (final (index, route) in earlier.indexed) {
    if (route.inMainNavigation || reported.contains(route)) continue;
    for (final other in earlier.skip(index + 1)) {
      if (other.inMainNavigation &&
          other.pattern != route.pattern &&
          other.covers(route)) {
        problems.add(
          'The route "${route.route.name}" (${route.shown}) cannot be '
          'reached in an app with a main navigation: its router matches the '
          'destination "${other.chain.first.name}" and the routes below it '
          'first, and the route "${other.route.name}" (${other.shown}) '
          'matches every location that "${route.route.name}" does. Change a '
          'fixed segment so that no location matches both.',
        );
        break;
      }
    }
  }
  return [
    for (final problem in problems) SmfIssue(problem, origin: origin),
    ...warnings,
  ];
}

/// A route of a module with its path from the namespace of the module, such
/// as `/items/:id`, which is empty for the route `/`, and the routes from
/// the top level down to it.
final class _PlacedRoute {
  _PlacedRoute(this.route, this.path, this.chain);

  final Route route;
  final String path;
  final List<Route> chain;

  /// The locations the route matches, as [path] with `:` for each
  /// parameter.
  late final String pattern = path.replaceAll(RegExp(':[a-zA-Z0-9]+'), ':');

  /// Whether the route is in the main navigation of an app that has one: a
  /// destination or a route below one.
  bool get inMainNavigation => chain.first.destination != null;

  /// The segments of [path].
  late final List<String> segments =
      path.isEmpty ? const [] : path.substring(1).split('/');

  /// The path as a message shows it.
  String get shown => path.isEmpty ? '/' : path;

  /// Whether this route matches every location that [other] matches: they
  /// have as many segments, and each segment of this route is a parameter
  /// or the same fixed segment as that of [other].
  bool covers(_PlacedRoute other) {
    if (segments.length != other.segments.length) return false;
    for (var i = 0; i < segments.length; i++) {
      final mine = segments[i];
      if (!mine.startsWith(':') && mine != other.segments[i]) return false;
    }
    return true;
  }

  /// A location that both this route and [other] match, such as `/new/5`,
  /// or `null` if there is none.
  String? sharedLocation(_PlacedRoute other) {
    if (segments.length != other.segments.length) return null;
    final shared = <String>[];
    for (var i = 0; i < segments.length; i++) {
      final (mine, theirs) = (segments[i], other.segments[i]);
      if (!mine.startsWith(':') && !theirs.startsWith(':') && mine != theirs) {
        return null;
      }
      shared.add(mine.startsWith(':') ? theirs : mine);
    }
    return '/${shared.join('/')}';
  }
}

/// Whether [route] can be reached behind the routes of its module that come
/// before it, [earlier], in the order routers match a location: the
/// top-level routes in the order they are declared, each followed by its
/// children, depth first; the first route that matches the whole location
/// takes it, go_router and auto_route alike.
///
/// A route is unreachable when an earlier route matches every location it
/// does, such as `/:id` before `/new`: the route that takes the fixed
/// segment has to come first. When an earlier route matches only some of
/// its locations, as `/:section/about` and `/docs/:page` both match
/// `/docs/about`, those go to the earlier route, which is worth a warning.
/// Routes with the same pattern are reported by the caller.
///
/// In an app with a main navigation, the routes in it come first, so
/// declaring a route outside it earlier does not help against a route in
/// it, and a location of both goes to the route in it.
({String? unreachable, String? ambiguous}) _reachability(
  _PlacedRoute route,
  List<_PlacedRoute> earlier,
) {
  String? ambiguous;
  for (final other in earlier) {
    if (other.covers(route)) {
      final problem = 'The route "${route.route.name}" (${route.shown}) '
          'cannot be reached: the route "${other.route.name}" '
          '(${other.shown}) comes before it and matches every location it '
          'does.';
      if (other.inMainNavigation && !route.inMainNavigation) {
        return (
          unreachable: '$problem Declaring "${route.chain.first.name}" '
              'first does not help: in an app with a main navigation, the '
              'router matches the destination "${other.chain.first.name}" '
              'and the routes below it first. Change a fixed segment so that '
              'no location matches both.',
          ambiguous: null,
        );
      }
      // The routes that hold each of them, right below where their chains
      // part: siblings, the one of the earlier route declared first.
      var at = 0;
      while (at < route.chain.length - 1 &&
          at < other.chain.length - 1 &&
          identical(route.chain[at], other.chain[at])) {
        at++;
      }
      return (
        unreachable: '$problem Declare "${route.chain[at].name}" before '
            '"${other.chain[at].name}".',
        ambiguous: null,
      );
    }
    if (ambiguous != null || route.covers(other)) continue;
    if (other.sharedLocation(route) case final location?) {
      final shared = 'The routes "${other.route.name}" (${other.shown}) and '
          '"${route.route.name}" (${route.shown}) both match locations such '
          'as $location, which go to "${other.route.name}", declared first';
      ambiguous = [
        if (route.inMainNavigation && !other.inMainNavigation)
          '$shared, in an app without a main navigation, and to '
              '"${route.route.name}" in an app with one, whose router '
              'matches the destination "${route.chain.first.name}" and the '
              'routes below it first.'
        else
          '$shared.',
        'Change a fixed segment so that no location matches both.',
      ].join(' ');
    }
  }
  return (unreachable: null, ambiguous: ambiguous);
}

List<String> _screenProblems(
  Route route,
  String label,
  Map<String, Route> screens,
) {
  final screen = route.screen;
  final import = screen.import;
  final problems = <String>[];
  final valid = _upperCamelCase.hasMatch(screen.className);
  if (!valid) {
    problems.add(
      '$label shows "${screen.className}", which is not an UpperCamelCase '
      'class name.',
    );
  }
  if (!import.isAppFile) {
    problems.add(
      '$label shows a screen of "${import.uri}"; a screen is a file of the '
      'app, imported with ImportRef.app.',
    );
  }
  if (import.prefix != null || import.show.isNotEmpty) {
    problems.add(
      '$label imports its screen with a prefix or show; routers choose their '
      'own prefix.',
    );
  }
  problems.addAll(import.problems());
  // The tags of a screen's annotations name it in snake_case, so screens
  // whose names differ only in case would share them.
  final key = valid ? SmfNames.snakeCaseOf(screen.className) : screen.className;
  if (screens.putIfAbsent(key, () => route) case final other
      when other != route) {
    problems.add(
      other.screen.className == screen.className
          ? 'The routes "${other.name}" and "${route.name}" show the same '
              'screen ${screen.className}; a screen belongs to one route.'
          : 'The screens ${other.screen.className} and ${screen.className} '
              'of the routes "${other.name}" and "${route.name}" would share '
              'the tags of their annotations; rename one of them.',
    );
  }
  return problems;
}

/// The problems with the parameters of [route], whose parents have the
/// parameters [ancestors].
///
/// A path parameter is a `:<name>` segment of the route's own path, or one
/// of a parent's path that the route also passes to its screen. No other
/// name may repeat a name of the route or of its parents, because the
/// query of a location is shared by the whole chain of pages.
List<String> _paramProblems(
  Route route,
  String label,
  List<RouteParam> ancestors,
) {
  final problems = <String>[];
  final inherited = {for (final param in ancestors) param.name: param};
  final segments = _segmentsOf(route.path);
  final seen = <String>{};
  final snakeNames = <String, String>{};
  for (final param in route.params) {
    final name = param.name;
    final valid = _isMemberName(name, _reservedParamNames);
    if (!valid) {
      problems.add(
        '$label has the parameter "$name"; a parameter name is a '
        'lowerCamelCase Dart identifier other than '
        '${(_reservedParamNames.toList()..sort()).join(', ')}.',
      );
    }
    if (!seen.add(name)) {
      problems.add('$label declares the parameter "$name" twice.');
    }
    if (param.typeName == null) {
      problems.add(
        '$label has the parameter "$name" of type ${param.type}; use String, '
        'int, double or bool.',
      );
    }
    final parents = inherited[name];
    final fromParent = param.source == RouteParamSource.path &&
        !segments.contains(name) &&
        parents?.source == RouteParamSource.path;
    if (fromParent) {
      if (parents!.type != param.type) {
        problems.add(
          '$label passes the path parameter "$name" of a parent as '
          '${param.type}, but the parent declares it as ${parents.type}.',
        );
      }
    } else if (parents != null) {
      problems.add(
        '$label has the parameter "$name", which a parent already has.',
      );
    } else if (param.source == RouteParamSource.path &&
        !segments.contains(name)) {
      problems.add(
        '$label declares the path parameter "$name", but neither its path '
        'nor the path of a parent has a :$name segment.',
      );
    }
    if (valid) {
      final snake = SmfNames.snakeCaseOf(name);
      final other = snakeNames.putIfAbsent(snake, () => name);
      if (other != name) {
        problems.add(
          '$label has the parameters "$other" and "$name", which would share '
          'the tag of their annotations; rename one of them.',
        );
      }
    }
  }
  for (final segment in segments) {
    final declared = route.params.any(
      (param) => param.source == RouteParamSource.path && param.name == segment,
    );
    if (!declared) {
      problems.add(
        '$label has the segment :$segment but no RouteParam.path for it.',
      );
    }
  }
  return problems;
}

List<SmfIssue> _checkScreenSockets(ModuleRuleInput<RoutesData> input) {
  final origin = ModuleOrigin(input.module.id);
  final templates = <String, String>{
    for (final contribution in input.contributions)
      if (contribution is BrickContribution)
        for (final file in contribution.bundle.files)
          if (file.type == 'text')
            file.path.replaceAll(r'\', '/'): utf8.decode(
              base64.decode(file.data),
              allowMalformed: true,
            ),
  };

  final issues = <SmfIssue>[];
  void check(Route route) {
    final screen = route.screen;
    final path = screen.file;
    // The rule router.routes reports invalid names, which have no tags.
    final named = _upperCamelCase.hasMatch(screen.className) &&
        route.params.every((param) => _lowerCamelCase.hasMatch(param.name));
    if (path != null && named) {
      final text = templates[path];
      if (text == null) {
        issues.add(
          SmfIssue(
            'The screen ${screen.className} of the route "${route.name}" is '
            'in $path, which the bricks of the module do not generate.',
            origin: origin,
            path: path,
          ),
        );
      } else {
        issues.addAll(
          [
            for (final problem in _annotationProblems(
              input.module.id,
              route,
              text,
            ))
              SmfIssue(problem, origin: origin, path: path),
          ],
        );
      }
    }
    route.children.forEach(check);
  }

  for (final data in input.data) {
    data.value.routes.forEach(check);
  }
  return issues;
}

/// What may stand between the tag of a class's annotations and the class:
/// white space, comments and other annotations.
final RegExp _onlyAnnotations = RegExp(
  r'^(?:\s+|//[^\n]*|@[A-Za-z_$][\w$.]*(?:\([^()]*\))?)*$',
);

/// The problems with the annotation tags of the screen of [route] in [text],
/// the template of the screen's file.
///
/// The tag of the class must come right before its declaration, with only
/// white space, comments and other annotations between them. The tag of a
/// parameter must be in the parameters of the class's unnamed constructor,
/// before the parameter and after the previous one. No tag may follow a
/// `{`: mustache would read the brace as part of the tag's name.
List<String> _annotationProblems(ModuleId feature, Route route, String text) {
  final screen = route.screen.className;
  final screenSocket =
      RouterRole.screenAnnotations((feature: feature, screen: screen));
  final screenTag = '{{{${screenSocket.tag}}}}';
  final declaration = RegExp(
    r'^[ \t]*(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
    'class\\s+$screen\\b',
    multiLine: true,
  ).firstMatch(text);
  final problems = <String>[];
  if (declaration == null) {
    problems.add(
      'The template does not declare the class $screen of the route '
      '"${route.name}".',
    );
  }

  final screenAt = text.indexOf(screenTag);
  if (screenAt == -1) {
    problems.add(
      'The template of $screen lacks the tag $screenTag for the annotations '
      'of the class, which routers such as auto_route fill.',
    );
  } else {
    problems.addAll(_braceProblems(text, screenAt, screenTag));
    if (declaration != null) {
      final placed = screenAt < declaration.start &&
          _onlyAnnotations.hasMatch(
            text.substring(screenAt + screenTag.length, declaration.start),
          );
      if (!placed) {
        problems.add(
          'The tag $screenTag must come right before the declaration of the '
          'class $screen, with only other annotations and comments between '
          'them.',
        );
      }
    }
  }

  final constructor = declaration == null
      ? null
      : _constructorParameters(text, screen, declaration.end);
  for (final param in route.params) {
    final paramSocket = RouterRole.paramAnnotations(
      (feature: feature, screen: screen, param: param.name),
    );
    final paramTag = '{{{${paramSocket.tag}}}}';
    final at = text.indexOf(paramTag);
    if (at == -1) {
      problems.add(
        'The template of $screen lacks the tag $paramTag before the '
        'constructor parameter ${param.name}.',
      );
      continue;
    }
    problems.addAll(_braceProblems(text, at, paramTag));
    final end = at + paramTag.length;
    final placed = constructor != null &&
        at > constructor.start &&
        end <= constructor.end &&
        RegExp('^[^,]*?\\b${param.name}\\b')
            .hasMatch(text.substring(end, constructor.end));
    if (!placed) {
      problems.add(
        'The tag $paramTag must be in the parameters of the unnamed '
        'constructor of $screen, right before the parameter ${param.name}.',
      );
    }
  }
  return problems;
}

List<String> _braceProblems(String text, int at, String tag) {
  if (at == 0 || text[at - 1] != '{') return const [];
  final problem = 'The tag $tag follows a "{", which mustache reads as part '
      "of the tag's name; put a space or a line break before it.";
  return [problem];
}

/// The range of the parameter list of the unnamed constructor of [screen]
/// in [text], after the class declaration that ends at [from], or `null` if
/// there is none.
({int start, int end})? _constructorParameters(
  String text,
  String screen,
  int from,
) {
  final opening = RegExp('(?<![\\w\$.])$screen\\s*\\(').firstMatch(
    text.substring(from),
  );
  if (opening == null) return null;
  final start = from + opening.end;
  var depth = 1;
  for (var i = start; i < text.length; i++) {
    if (text[i] == '(') depth++;
    if (text[i] == ')' && --depth == 0) return (start: start, end: i);
  }
  return null;
}

List<SmfIssue> _checkNavAccess(StructuralRuleInput<RoutesData> input) {
  final issues = <SmfIssue>[];
  final locations = {
    for (final route in routerRole.facadeOf(input.roleInput).routes)
      route.locationClass: route.feature.module,
  };
  for (final MapEntry(key: path, value: file) in input.files.entries) {
    final owner = input.owners[path];
    if (owner is! ModuleOrigin) continue;
    final module = input.module(owner.module);
    // The router builds the screens of every location.
    if (module?.provides.contains(routerRole) ?? false) continue;
    final dependsOn = module?.dependsOn ?? const <ModuleId>{};
    final allowed = {
      owner.module.lowerCamelCase,
      for (final dependency in dependsOn) dependency.lowerCamelCase,
    };
    for (final access in file.memberAccesses) {
      final target = access.target;
      final viaNav = target == 'nav' || target.endsWith('.nav');
      if (viaNav && !allowed.contains(access.name)) {
        issues.add(
          SmfIssue(
            '$path navigates to the routes of "${access.name}" through '
            '$target.${access.name}, but the module $owner may only use its '
            'own routes and those of the modules it depends on.',
            hint: 'Declare the module in dependsOn, or let the other module '
                'navigate. The rule matches by name, so rename a variable '
                'called nav that is not the navigation facade.',
            origin: owner,
            path: path,
          ),
        );
      }
    }
    final used = {
      for (final call in file.invocations) call.name,
      for (final reference in file.references) reference.name,
      for (final access in file.memberAccesses) access.name,
    };
    for (final MapEntry(key: location, value: feature) in locations.entries) {
      if (feature == owner.module ||
          dependsOn.contains(feature) ||
          !used.contains(location)) {
        continue;
      }
      issues.add(
        SmfIssue(
          '$path uses $location, a location of $feature, but the module '
          '$owner may only use its own routes and those of the modules it '
          'depends on.',
          hint: 'Declare $feature in dependsOn, or let it navigate.',
          origin: owner,
          path: path,
        ),
      );
    }
  }
  return issues;
}

List<SmfIssue> _checkScreenConstructors(StructuralRuleInput<RoutesData> input) {
  final issues = <SmfIssue>[];
  for (final route in routerRole.facadeOf(input.roleInput).routes) {
    final screen = route.route.screen;
    final path = screen.file;
    if (path == null) continue;
    final origin = ModuleOrigin(route.feature.module);
    final required = RequiredClass(
      screen.className,
      path: path,
      namedParameters: [for (final param in route.route.params) param.name],
      // Routers create a screen without parameters as a constant.
      constConstructor: true,
    );
    final problems = [
      ...required.checkIn(input.files),
      ..._nullabilityProblems(route, input.files[path]),
    ];
    for (final problem in problems) {
      issues.add(
        SmfIssue(
          'The screen of the $route: ${problem.message}',
          origin: origin,
          path: path,
        ),
      );
    }
  }
  return issues;
}

/// The problems with optional parameters of [route] that the constructor of
/// its screen, in [file], declares with a non-nullable type.
///
/// The index gives an initializing formal such as `this.tab` the type of
/// its field; a parameter without any type, such as `super.key`, is not
/// checked.
List<SmfIssue> _nullabilityProblems(FacadeRoute route, DartFileIndex? file) {
  final screen = route.route.screen.className;
  final constructor = file?.declaration(screen)?.unnamedConstructor;
  if (constructor == null) return const [];
  return [
    for (final param in route.route.params)
      if (param.optional)
        for (final parameter in constructor.parameters)
          if (parameter.name == param.name &&
              parameter.type != null &&
              !parameter.type!.endsWith('?'))
            SmfIssue(
              'the parameter ${param.name} of $screen must be nullable, '
              'because the location may leave it out.',
            ),
  ];
}
