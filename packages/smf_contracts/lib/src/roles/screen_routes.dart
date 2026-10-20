import 'package:smf_contracts/smf_contracts.dart';

/// The route that the provider of [role] names as its screen, among the
/// routes of the app in [input], the input of a hook of [role] or of its
/// provider: the route named by the first data of [role] that [nameOf]
/// takes for the name of the screen, if a module gave it, or `null` if no
/// module names one or the module that does has no route of that name.
///
/// The routes of the app are data of the router role, so a hook of a role
/// reads them only if that role requires or uses the router role too;
/// otherwise this throws an [ArgumentError] once a module names the route.
FacadeRoute? screenRouteIn(
  RoleHookInput<Object> input,
  Role role,
  String? Function(Object data) nameOf,
) {
  for (final data in role.dataIn(input)) {
    if ((nameOf(data.value), data.origin)
        case (final name?, ModuleOrigin(:final module))) {
      return _routeOf(input, module, name);
    }
  }
  return null;
}

/// The problems of the routes [named] that the module of [input] names as
/// the screen of [role]: only the provider of the role names one, exactly
/// one, which is a route of its own that needs no values.
///
/// [screen] is the screen as messages name it, such as `settings screen`,
/// and [routeClass] the class of the data that names the route, such as
/// `SettingsScreenRoute`.
List<SmfIssue> screenRouteIssues(
  ModuleRuleInput<Object> input,
  Role role,
  List<String> named, {
  required String screen,
  required String routeClass,
}) {
  final module = input.module;
  final origin = ModuleOrigin(module.id);
  if (!module.provides.contains(role)) {
    return [
      if (named.isNotEmpty)
        SmfIssue(
          'The module names the route of the $screen, which only the '
          'provider of the $role does.',
          origin: origin,
        ),
    ];
  }
  if (named.length != 1) {
    return [
      SmfIssue(
        'The provider of the $role names exactly one route as the $screen, '
        'but the module names ${named.length}.',
        hint: 'Contribute one $routeClass with the name of the route of the '
            'screen.',
        origin: origin,
      ),
    ];
  }
  final name = named.single;
  final route = _routeOf(input.roleInput, module.id, name);
  if (route == null) {
    return [
      SmfIssue(
        'The module names its route "$name" as the $screen, but declares no '
        'route of that name.',
        origin: origin,
      ),
    ];
  }
  final required = route.params.where((param) => param.isRequired);
  return [
    if (required.isNotEmpty)
      SmfIssue(
        'The route "$name" (${route.fullPath}) of the $screen needs '
        '${required.join(', ')}; the $screen is reached without values.',
        origin: origin,
      ),
  ];
}

/// The problem of a route of the screen of [role] that [origin] names,
/// unless a module does: the routes of an app are those of its modules.
/// [screen] is the screen as messages name it, such as `settings screen`.
List<SmfIssue> screenRouteOriginIssues(
  ContributionOrigin? origin,
  Role role, {
  required String screen,
}) =>
    [
      if (origin is! ModuleOrigin)
        SmfIssue(
          'Only the module that provides the $role names the route of the '
          '$screen, not $origin.',
          origin: origin,
        ),
    ];

/// The route [name] of the module [module] among the routes of the app in
/// [input], or `null` if the module has no route of that name.
FacadeRoute? _routeOf(
  RoleHookInput<Object> input,
  ModuleId module,
  String name,
) {
  for (final feature in routerRole.facadeOf(input).features) {
    if (feature.module != module) continue;
    for (final route in feature.allRoutes) {
      if (route.route.name == name) return route;
    }
  }
  return null;
}
