part of '../router.dart';

/// The library of `ValueListenable`, which the widgets library of Flutter
/// does not export.
const _foundation = ImportRef('package:flutter/foundation.dart');

/// The code of the guards of [facade] for `lib/core/router/app_router.dart`
/// of the router's template: the class `RouteGuard`, and
/// [RouterRole.routeGuards], [RouterRole.redirectOf] and
/// [RouterRole.guardChanges], with the imports they need; or no code for an
/// app without guards.
///
/// The file of the function of each guard is imported with a prefix of the
/// template's own, `guard0`, `guard1` and so on, so that no function can
/// hide or be hidden by a name of the template or of another module.
Fragment _guardsCode(RouterFacade facade) {
  final guards = facade.guards;
  if (guards.isEmpty) return const Fragment('');
  // A function is in a file of the app, which its path identifies.
  final files = <String, ImportRef>{};
  String allowsOf(RouteGuard guard) => guard.allows.codeWith(
        files
            .putIfAbsent(
              guard.allows.import.uri,
              () => guard.allows.import.withPrefix('guard${files.length}'),
            )
            .prefix,
      );
  final buffer = StringBuffer(_guardClass)
    ..writeln()
    ..writeln('/// The guards of the routes of the app, in the order the app')
    ..writeln('/// asks them.')
    ..writeln('final List<RouteGuard> ${RouterRole.routeGuards} = [');
  for (final guard in guards) {
    final flow = [
      for (final route in guard.flow) SmfNames.dartString(route.fullName),
    ];
    buffer
      ..writeln('  RouteGuard(')
      ..writeln('    ${SmfNames.dartString(guard.fullName)},')
      ..writeln('    allows: ${allowsOf(guard.guard)}(),')
      ..writeln('    redirectTo: const ${guard.target.locationClass}(),')
      ..writeln('    flow: const {${flow.join(', ')}},')
      ..writeln('  ),');
  }
  buffer
    ..writeln('];')
    ..write(_redirectOf)
    ..write(_guardChanges);
  return Fragment('$buffer', imports: [_foundation, ...files.values]);
}

/// The class of a guard in the app.
const _guardClass = '''

/// A guard of the routes of the app: while it does not allow, the router
/// shows its target in place of every location outside its flow.
///
/// `go()`, `push()` and `replace()` of such a location show the target
/// too, and `push()` completes with `null`. Once the guard allows, the
/// router shows the first location that the guards kept the user from.
final class RouteGuard {
  /// Creates the guard [name].
  const RouteGuard(
    this.name, {
    required this.allows,
    required this.redirectTo,
    required this.flow,
  });

  /// The full name of the guard: its module and its name there.
  final String name;

  /// Whether the guard lets the user see the locations outside its [flow];
  /// it notifies its listeners when that changes.
  final ValueListenable<bool> allows;

  /// The target of the guard: the location that the router shows while the
  /// guard does not allow.
  final AppLocation redirectTo;

  /// The full names of the routes that the user may see while the guard
  /// does not allow: the route of [redirectTo] and the routes below it.
  final Set<String> flow;
}
''';

/// The function of the app that asks its guards about a route.
const _redirectOf = '''

/// The location that the router shows in place of the route [routeName],
/// or `null` if the guards let the user see it.
///
/// [routeName] is the full name of a route, or `null` for a screen that is
/// no route of a module, such as the error screen of the router. The first
/// guard that does not allow decides, and no guard after it is asked: it
/// shows its target in place of every route outside its flow.
AppLocation? ${RouterRole.redirectOf}(String? routeName) {
  for (final guard in ${RouterRole.routeGuards}) {
    if (guard.allows.value) continue;
    return guard.flow.contains(routeName) ? null : guard.redirectTo;
  }
  return null;
}
''';

/// The listenable of the app that tells of the changes of its guards.
const _guardChanges = '''

/// Notifies its listeners when a guard starts or stops allowing, so that
/// the router asks [${RouterRole.redirectOf}] again.
final Listenable ${RouterRole.guardChanges} = Listenable.merge([
  for (final guard in ${RouterRole.routeGuards}) guard.allows,
]);''';
