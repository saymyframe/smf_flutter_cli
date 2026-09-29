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
  final check = _RoutesCheck(origin);
  if (input.data.isNotEmpty && routes.isEmpty) {
    check.problems.add('The module contributes routes data without routes.');
  }
  for (final route in routes) {
    check.visit(route, parentPath: null, ancestors: const [], chain: const []);
  }
  check.mainNavigationOrder();
  return [
    for (final problem in check.problems) SmfIssue(problem, origin: origin),
    ...check.warnings,
  ];
}

/// The checks of [_checkRoutes], which visits the routes of a module in the
/// order they are declared, each followed by its children, depth first.
final class _RoutesCheck {
  _RoutesCheck(this.origin);

  final ModuleOrigin origin;
  final List<String> problems = [];
  final List<SmfIssue> warnings = [];
  final Map<String, Route> _names = {};
  final Map<String, Route> _screens = {};
  final Map<String, (Route, String)> _patterns = {};

  /// The routes checked so far, in the order they are declared, in which a
  /// router matches them when the app has no main navigation.
  final List<_PlacedRoute> _earlier = [];

  /// The routes that the order of the declaration leaves unreachable, or
  /// that match the same locations as an earlier route.
  final Set<_PlacedRoute> _reported = {};

  /// Checks [route] and its children. The path of the module's root route
  /// `/` is empty, so a parent path does not tell a child from a top-level
  /// route: [parentPath] is `null` for a top-level route.
  void visit(
    Route route, {
    required String? parentPath,
    required List<RouteParam> ancestors,
    required List<Route> chain,
  }) {
    final topLevel = parentPath == null;
    final path = _placedPath(route, parentPath);
    final label = 'The route "${route.name}" (${route.path})';
    final placed = _PlacedRoute(route, path, [...chain, route]);

    _checkPathAndName(route, label, topLevel: topLevel);
    _checkPlace(placed);
    _earlier.add(placed);
    problems
      ..addAll(_screenProblems(route, label, _screens))
      ..addAll(_paramProblems(route, label, ancestors));

    final required = _requiredParams(route, ancestors);
    if (route.startCandidate && required.isNotEmpty) {
      problems.add(
        '$label is a start candidate but needs ${required.join(', ')}; the '
        'app can only start on a route without required parameters.',
      );
    }
    if (route.destination case final destination?) {
      problems.addAll(
        _destinationProblems(destination, label, required, topLevel: topLevel),
      );
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
      visit(
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

  /// Checks the path of [route], and its name, which no other route of the
  /// module has.
  void _checkPathAndName(Route route, String label, {required bool topLevel}) {
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
    if (_names.putIfAbsent(route.name, () => route) != route) {
      problems.add('Two routes of the module are named "${route.name}".');
    }
  }

  /// Checks whether an earlier route matches the same locations as
  /// [placed], or leaves it unreachable.
  void _checkPlace(_PlacedRoute placed) {
    final _PlacedRoute(:route, :path) = placed;
    if (_patterns.putIfAbsent(placed.pattern, () => (route, path))
        case (
          final other,
          final otherPath,
        ) when other != route) {
      _reported.add(placed);
      problems.add(
        otherPath == path
            ? 'Two routes of the module have the path "$path".'
            : 'The routes "${other.name}" and "${route.name}" have the paths '
                '"$otherPath" and "$path", which match the same locations.',
      );
      return;
    }
    final (:unreachable, :ambiguous) = _reachability(placed, _earlier);
    if (unreachable != null) {
      _reported.add(placed);
      problems.add(unreachable);
    }
    if (ambiguous != null) {
      warnings.add(SmfIssue.warning(ambiguous, origin: origin));
    }
  }

  /// Checks the routes outside the main navigation of an app that has one.
  ///
  /// In such an app, the router matches the destinations first, each with
  /// the routes below it, so a route outside the main navigation comes
  /// after the routes in it that are declared later too.
  void mainNavigationOrder() {
    for (final (index, route) in _earlier.indexed) {
      if (route.inMainNavigation || _reported.contains(route)) continue;
      for (final other in _earlier.skip(index + 1)) {
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
  }
}

/// The path of [route] from the namespace of its module: empty for the
/// route `/`, and below [parentPath] for a child.
String _placedPath(Route route, String? parentPath) {
  if (parentPath != null) return '$parentPath/${route.path}';
  return route.path == '/' ? '' : route.path;
}

/// The parameters that [route] requires, with the path parameters of its
/// parents, [ancestors], which a location of the route has too.
Iterable<RouteParam> _requiredParams(
  Route route,
  List<RouteParam> ancestors,
) {
  final ancestorPath = [
    for (final param in ancestors)
      if (param.source == RouteParamSource.path) param,
  ];
  return {
    for (final param in [...ancestorPath, ...route.params])
      if (param.isRequired) param.name: param,
  }.values;
}

/// The problems with [destination], the destination of the main navigation
/// of the route of [label] that requires the parameters [required].
List<String> _destinationProblems(
  Destination destination,
  String label,
  Iterable<RouteParam> required, {
  required bool topLevel,
}) {
  final problems = <String>[];
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
  return problems..addAll(icon.problems());
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
      return (unreachable: _unreachable(route, other), ambiguous: null);
    }
    if (ambiguous != null || route.covers(other)) continue;
    if (other.sharedLocation(route) case final location?) {
      ambiguous = _ambiguity(route, other, location);
    }
  }
  return (unreachable: null, ambiguous: ambiguous);
}

/// Why [route] cannot be reached behind [other], an earlier route that
/// matches every location it does, and what to change.
String _unreachable(_PlacedRoute route, _PlacedRoute other) {
  final problem = 'The route "${route.route.name}" (${route.shown}) '
      'cannot be reached: the route "${other.route.name}" '
      '(${other.shown}) comes before it and matches every location it '
      'does.';
  if (other.inMainNavigation && !route.inMainNavigation) {
    return '$problem Declaring "${route.chain.first.name}" '
        'first does not help: in an app with a main navigation, the '
        'router matches the destination "${other.chain.first.name}" '
        'and the routes below it first. Change a fixed segment so that '
        'no location matches both.';
  }
  // The routes that hold each of them, right below where their chains
  // part: siblings, the one of the earlier route declared first.
  var at = 0;
  while (at < route.chain.length - 1 &&
      at < other.chain.length - 1 &&
      identical(route.chain[at], other.chain[at])) {
    at++;
  }
  return '$problem Declare "${route.chain[at].name}" before '
      '"${other.chain[at].name}".';
}

/// The warning that [route] and [other], an earlier route, both match
/// locations such as [location], which go to [other].
String _ambiguity(_PlacedRoute route, _PlacedRoute other, String location) {
  final shared = 'The routes "${other.route.name}" (${other.shown}) and '
      '"${route.route.name}" (${route.shown}) both match locations such '
      'as $location, which go to "${other.route.name}", declared first';
  return [
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
    final problem = _sourceProblem(param, label, inherited[name], segments);
    if (problem != null) problems.add(problem);
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
  return problems..addAll(_segmentProblems(route, label, segments));
}

/// The problem with where [param] of the route of [label] comes from, if
/// any: a parameter of a parent, [parents], or a segment of the route's
/// path, one of [segments].
String? _sourceProblem(
  RouteParam param,
  String label,
  RouteParam? parents,
  Set<String> segments,
) {
  final name = param.name;
  final fromParent = param.source == RouteParamSource.path &&
      !segments.contains(name) &&
      parents?.source == RouteParamSource.path;
  if (fromParent) {
    if (parents!.type == param.type) return null;
    return '$label passes the path parameter "$name" of a parent as '
        '${param.type}, but the parent declares it as ${parents.type}.';
  }
  if (parents != null) {
    return '$label has the parameter "$name", which a parent already has.';
  }
  if (param.source == RouteParamSource.path && !segments.contains(name)) {
    return '$label declares the path parameter "$name", but neither its path '
        'nor the path of a parent has a :$name segment.';
  }
  return null;
}

/// The problems with the path parameters [segments] of [route]: each needs
/// a [RouteParam.path].
List<String> _segmentProblems(
  Route route,
  String label,
  Set<String> segments,
) {
  final problems = <String>[];
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
  final templates = _textTemplates(input.contributions);

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

/// The text files of the bricks among [contributions], by path.
Map<String, String> _textTemplates(List<Contribution> contributions) => {
      for (final contribution in contributions)
        if (contribution is BrickContribution)
          for (final file in contribution.bundle.files)
            if (file.type == 'text')
              file.path.replaceAll(r'\', '/'): utf8.decode(
                base64.decode(file.data),
                allowMalformed: true,
              ),
    };

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

  problems.addAll(_screenTagProblems(text, screen, screenTag, declaration));

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

/// The problems with [screenTag], the tag of the annotations of the class
/// [screen], in [text], whose [declaration] of the class may be missing.
List<String> _screenTagProblems(
  String text,
  String screen,
  String screenTag,
  RegExpMatch? declaration,
) {
  final screenAt = text.indexOf(screenTag);
  if (screenAt == -1) {
    final missing = 'The template of $screen lacks the tag $screenTag for '
        'the annotations of the class, which routers such as auto_route fill.';
    return [missing];
  }
  final problems = [..._braceProblems(text, screenAt, screenTag)];
  final placed = declaration == null ||
      screenAt < declaration.start &&
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
    issues
      ..addAll(_facadeAccessIssues(path, file, owner, dependsOn))
      ..addAll(
        _locationUseIssues(path, file, owner, dependsOn, locations),
      );
  }
  return issues;
}

/// The issues of the file at [path] of the module [owner], which depends on
/// [dependsOn], for navigating through the facade to the routes of another
/// module.
List<SmfIssue> _facadeAccessIssues(
  String path,
  DartFileIndex file,
  ModuleOrigin owner,
  Set<ModuleId> dependsOn,
) {
  final allowed = {
    owner.module.lowerCamelCase,
    for (final dependency in dependsOn) dependency.lowerCamelCase,
  };
  final issues = <SmfIssue>[];
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
  return issues;
}

/// The issues of the file at [path] of the module [owner], which depends on
/// [dependsOn], for using a location class of another module, among the
/// [locations] of the facade with the module of each.
List<SmfIssue> _locationUseIssues(
  String path,
  DartFileIndex file,
  ModuleOrigin owner,
  Set<ModuleId> dependsOn,
  Map<String, ModuleId> locations,
) {
  final used = {
    for (final call in file.invocations) call.name,
    for (final reference in file.references) reference.name,
    for (final access in file.memberAccesses) access.name,
  };
  return [
    for (final MapEntry(key: location, value: feature) in locations.entries)
      if (feature != owner.module &&
          !dependsOn.contains(feature) &&
          used.contains(location))
        SmfIssue(
          '$path uses $location, a location of $feature, but the module '
          '$owner may only use its own routes and those of the modules it '
          'depends on.',
          hint: 'Declare $feature in dependsOn, or let it navigate.',
          origin: owner,
          path: path,
        ),
  ];
}

List<SmfIssue> _checkScreenConstructors(StructuralRuleInput<RoutesData> input) {
  final issues = <SmfIssue>[];
  for (final route in routerRole.facadeOf(input.roleInput).routes) {
    final screen = route.route.screen;
    final path = screen.file;
    // The rule router.routes reports a screen outside the app.
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
