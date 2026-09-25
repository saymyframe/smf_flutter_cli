part of '../router.dart';

const _segment = '(?:[a-z0-9][a-z0-9_-]*|:[a-z][a-zA-Z0-9]*)';
final RegExp _topLevelPath = RegExp('^/\$|^(?:/$_segment)+\$');
final RegExp _childPath = RegExp('^$_segment(?:/$_segment)*\$');
final RegExp _lowerCamelCase = RegExp(r'^[a-z][a-zA-Z0-9]*$');
final RegExp _upperCamelCase = RegExp(r'^[A-Z][a-zA-Z0-9]*$');

/// Members of `Object`, which no generated class can declare again.
const _objectMembers = {'hashCode', 'noSuchMethod', 'runtimeType', 'toString'};

/// Names a parameter cannot have: the members of the location classes and
/// the `key` of a widget.
const Set<String> _reservedParamNames = {
  ..._objectMembers,
  'chain',
  'key',
  'parent',
  'path',
  'routeName',
};

List<SmfIssue> _checkRoutes(ModuleRuleInput<RoutesData> input) {
  final origin = ModuleOrigin(input.module.id);
  final routes = [for (final data in input.data) ...data.value.routes];
  final problems = <String>[
    if (input.data.isNotEmpty && routes.isEmpty)
      'The module contributes routes data without routes.',
  ];
  final names = <String, Route>{};
  final screens = <String, Route>{};
  final paths = <String, Route>{};

  // The path of the module's root route `/` is empty, so a parent path does
  // not tell a child from a top-level route.
  void check(
    Route route, {
    required String? parentPath,
    required List<RouteParam> inherited,
  }) {
    final topLevel = parentPath == null;
    final path = topLevel
        ? (route.path == '/' ? '' : route.path)
        : '$parentPath/${route.path}';
    final label = 'The route "${route.name}" (${route.path})';

    if (!(topLevel ? _topLevelPath : _childPath).hasMatch(route.path)) {
      problems.add(
        topLevel
            ? '$label has an invalid path; a top-level path starts with /, '
                'such as / or /settings/:id.'
            : '$label has an invalid path; the path of a child has no '
                'leading /, such as details/:id.',
      );
    }
    if (!_lowerCamelCase.hasMatch(route.name) ||
        !SmfNames.isDartIdentifier(route.name) ||
        _objectMembers.contains(route.name)) {
      problems.add(
        '$label needs a name that is a lowerCamelCase Dart identifier, such '
        'as details.',
      );
    }
    if (names.putIfAbsent(route.name, () => route) != route) {
      problems.add('Two routes of the module are named "${route.name}".');
    }
    if (paths.putIfAbsent(path, () => route) != route) {
      problems.add('Two routes of the module have the path "$path".');
    }
    problems
      ..addAll(_screenProblems(route, label, screens))
      ..addAll(_paramProblems(route, label, inherited));

    final required = [
      ...inherited,
      ...route.params.where((param) => param.isRequired),
    ];
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

    final pathParams = [
      ...inherited,
      ...route.params.where((param) => param.source == RouteParamSource.path),
    ];
    for (final child in route.children) {
      check(child, parentPath: path, inherited: pathParams);
    }
  }

  for (final route in routes) {
    check(route, parentPath: null, inherited: const []);
  }
  return [for (final problem in problems) SmfIssue(problem, origin: origin)];
}

List<String> _screenProblems(
  Route route,
  String label,
  Map<String, Route> screens,
) {
  final screen = route.screen;
  final import = screen.import;
  final problems = <String>[];
  if (!_upperCamelCase.hasMatch(screen.className)) {
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
  if (screens.putIfAbsent(screen.className, () => route) case final other
      when other != route) {
    problems.add(
      'The routes "${other.name}" and "${route.name}" show the same screen '
      '${screen.className}; a screen belongs to one route.',
    );
  }
  return problems;
}

List<String> _paramProblems(
  Route route,
  String label,
  List<RouteParam> inherited,
) {
  final problems = <String>[];
  final seen = {for (final param in inherited) param.name};
  final segments = {
    for (final segment in route.path.split('/'))
      if (segment.startsWith(':')) segment.substring(1),
  };
  for (final param in route.params) {
    if (!_lowerCamelCase.hasMatch(param.name) ||
        !SmfNames.isDartIdentifier(param.name) ||
        _reservedParamNames.contains(param.name)) {
      problems.add(
        '$label has the parameter "${param.name}"; a parameter name is a '
        'lowerCamelCase Dart identifier other than '
        '${(_reservedParamNames.toList()..sort()).join(', ')}.',
      );
    }
    if (!seen.add(param.name)) {
      problems.add(
        '$label declares the parameter "${param.name}" twice, or a parent '
        'already has it.',
      );
    }
    if (param.typeName == null) {
      problems.add(
        '$label has the parameter "${param.name}" of type ${param.type}; '
        'use String, int, double or bool.',
      );
    }
    if (param.source == RouteParamSource.path &&
        !segments.contains(param.name)) {
      problems.add(
        '$label declares the path parameter "${param.name}", but its path '
        'has no :${param.name} segment.',
      );
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

/// The problems with the annotation tags of the screen of [route] in [text],
/// the template of the screen's file.
List<String> _annotationProblems(ModuleId feature, Route route, String text) {
  final screen = route.screen.className;
  final screenTag =
      RouterRole.screenAnnotations((feature: feature, screen: screen)).tag;
  final declaration = RegExp('\\bclass\\s+$screen\\b').firstMatch(text);
  final screenAt = text.indexOf('{{{$screenTag}}}');
  final problems = <String>[];
  if (declaration == null) {
    problems.add(
      'The template does not declare the class $screen of the route '
      '"${route.name}".',
    );
  }
  if (screenAt == -1) {
    problems.add(
      'The template of $screen lacks the tag {{{$screenTag}}} for the '
      'annotations of the class, which routers such as auto_route fill.',
    );
  } else if (declaration != null && screenAt > declaration.start) {
    problems.add(
      'The tag {{{$screenTag}}} must come before the declaration of the '
      'class $screen.',
    );
  }
  for (final param in route.params) {
    final paramTag = RouterRole.paramAnnotations(
      (feature: feature, screen: screen, param: param.name),
    ).tag;
    final paramAt = text.indexOf('{{{$paramTag}}}');
    if (paramAt == -1) {
      problems.add(
        'The template of $screen lacks the tag {{{$paramTag}}} before the '
        'constructor parameter ${param.name}.',
      );
    } else if (declaration != null && paramAt < declaration.start) {
      problems.add(
        'The tag {{{$paramTag}}} must be in the constructor of $screen, '
        'before the parameter ${param.name}.',
      );
    }
  }
  return problems;
}

List<SmfIssue> _checkNavAccess(StructuralRuleInput<RoutesData> input) {
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: file) in input.files.entries) {
    final owner = input.owners[path];
    if (owner is! ModuleOrigin) continue;
    final module = input.module(owner.module);
    final allowed = {
      owner.module.lowerCamelCase,
      for (final dependency in module?.dependsOn ?? const <ModuleId>{})
        dependency.lowerCamelCase,
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
                'navigate.',
            origin: owner,
            path: path,
          ),
        );
      }
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
