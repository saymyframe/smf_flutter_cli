part of '../router.dart';

/// The library of `ValueListenable`, which the widgets library of Flutter
/// does not export.
const _foundation = ImportRef('package:flutter/foundation.dart');

/// The code of the guards of [facade] for `lib/core/router/app_router.dart`
/// of the router's template: the class `RouteGuard`,
/// [RouterRole.routeGuards], [RouterRole.redirectOf],
/// [RouterRole.flowIsOver], [RouterRole.guardChanges], the classes of the
/// answers of [RouterRole.guardedNavigation] and that class, with the
/// imports they need; or no code for an app without guards.
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
    ..writeln(
      '/// The guards of the routes of the app, in the order the app asks '
      'them:',
    )
    ..writeln(
      '/// the gates first, and then the guards with [RouteGuard.routes].',
    )
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
      ..writeln('    flow: const {${flow.join(', ')}},');
    if (!guard.guard.resumes) buffer.writeln('    resumes: false,');
    if (guard.guard.condition case final condition?) {
      final routes = [
        for (final route in facade.routesAsking(condition))
          SmfNames.dartString(route.fullName),
      ];
      buffer.writeln('    routes: const {${routes.join(', ')}},');
    }
    buffer.writeln('  ),');
  }
  buffer
    ..writeln('];')
    ..write(_redirectOf)
    ..write(_flowIsOver)
    ..write(_guardChanges)
    ..write(_answers)
    ..write(_guardedNavigation);
  return Fragment('$buffer', imports: [_foundation, ...files.values]);
}

/// The class of a guard in the app.
const _guardClass = '''

/// A guard of the routes of the app. Without [routes] it is a gate: while
/// it does not allow, the router shows its target in place of every
/// location outside its flow. With [routes] it keeps the user only from
/// those routes, and the router shows every other route as it is.
///
/// While a gate does not allow, `go()`, `push()` and `replace()` of a
/// location that it keeps the user from show its target in place of the
/// whole stack, and `push()` completes with `null`. Once it allows, the
/// router shows the location that the user last asked for, or the one that
/// the gate took the user from if it [resumes], or else the screen that
/// the app starts on.
///
/// While a guard with [routes] does not allow, a request for one of them
/// opens its target over the page that the user is on, and the request
/// waits. Back returns to that page and drops the request. Once the guard
/// allows, the router closes the pages of the flow and does what was asked:
/// `push()` shows the location over the page that the user was on, and
/// completes with the value of its page, `go()` shows it in place of the
/// stack, and `replace()` in place of that page. A further request for one
/// of the [routes] does nothing while the flow is open. A location from
/// the platform opens the target over the screen that the app starts on.
/// When the guard stops allowing, the router closes each page of its
/// [routes] and the pages over it.
///
/// The routes of its flow show only while it does not allow, or while
/// another guard with the same flow does not. At any other time the router
/// shows the screen that the app starts on in place of a location of the
/// flow (see [flowIsOver]), or the target of a gate while that one does
/// not allow. So the code of the app changes what [allows] reads. It
/// navigates into a flow only while a guard with [routes] and that flow
/// does not allow and every gate does, as to a sign-in that a guest opens.
final class RouteGuard {
  /// Creates the guard [name].
  const RouteGuard(
    this.name, {
    required this.allows,
    required this.redirectTo,
    required this.flow,
    this.resumes = true,
    this.routes,
  });

  /// The full name of the guard: its module and its name there.
  final String name;

  /// Whether the guard lets the user see the locations that it keeps them
  /// from otherwise; it notifies its listeners when that changes.
  final ValueListenable<bool> allows;

  /// The target of the guard: the location that the router shows while the
  /// guard does not allow.
  final AppLocation redirectTo;

  /// The full names of the routes that the user may see while the guard
  /// does not allow: the route of [redirectTo] and the routes below it.
  /// Once every guard with this flow allows, the router shows none of them.
  final Set<String> flow;

  /// Whether the router brings the user back to the location that the
  /// guard takes them from when it stops allowing, once it allows again.
  ///
  /// With `false`, the router forgets what it remembers when the guard
  /// stops allowing: where the user was, whichever gate took them from
  /// it, and a location that was asked for before. So once the gates
  /// allow, the user comes to the screen that the app starts on, as the
  /// next user does after a sign-out, unless a location was asked for
  /// since the guard stopped, such as a link.
  ///
  /// The router remembers a location only for a gate. A guard with
  /// [routes] closes its pages when it stops allowing, so the user is on
  /// the page below them, whatever this says. With `false`, such a guard
  /// still makes the router forget what a gate made it remember.
  final bool resumes;

  /// The full names of the routes that the guard keeps the user from while
  /// it does not allow, or `null` for a gate, which keeps the user from
  /// every route outside its [flow].
  ///
  /// A guard with routes stands for something that only those routes need,
  /// such as an account: every other route shows whatever the guard says.
  /// None of its routes is in the [flow] of a guard. To ask for it on one
  /// more route, add the full name of the route here, and that of each
  /// route below it: a route does not ask because the route above it does.
  final Set<String>? routes;
}
''';

/// The function of the app that asks its guards about a route.
const _redirectOf = '''

/// The location that the router shows when it is asked for the route
/// [routeName] and a guard keeps the user from it, or `null` if the guards
/// let the user see the route.
///
/// [routeName] is the full name of a route, or `null` for a screen that is
/// no route of a module, such as the error screen of the router. The first
/// gate that does not allow decides, and no guard after it is asked: it
/// shows its target in place of every route outside its flow. When every
/// gate allows, the first guard that has the route among its
/// [RouteGuard.routes] and does not allow shows its target: over the page
/// that the user is on, not in place of it.
///
/// A route that the guards let the user see may still be in a flow that is
/// over, in place of which the router shows the screen that the app starts
/// on; see [${RouterRole.flowIsOver}].
AppLocation? ${RouterRole.redirectOf}(String? routeName) =>
    _guardKeepingFrom(routeName)?.redirectTo;

/// The guard that keeps the user from the route [routeName], or `null` if
/// the guards let the user see it: the first gate that does not allow,
/// unless the route is in its flow, or else the first guard with
/// [RouteGuard.routes] that does not allow and has the route among them.
RouteGuard? _guardKeepingFrom(String? routeName) {
  for (final guard in ${RouterRole.routeGuards}) {
    if (guard.allows.value) continue;
    final routes = guard.routes;
    if (routes == null) return guard.flow.contains(routeName) ? null : guard;
    if (routes.contains(routeName)) return guard;
  }
  return null;
}
''';

/// The function of the app that says whether the flow of a route is over.
const _flowIsOver = '''

/// Whether the route [routeName] is in the flow of a guard and every guard
/// with that flow allows: the flow is over. The router then shows the
/// screen that the app starts on in place of the route, unless another
/// guard does not allow and shows its target instead (see
/// [${RouterRole.redirectOf}]).
///
/// [routeName] is the full name of a route, or `null` for a screen that is
/// no route of a module, which is in no flow. Two guards with one target
/// have one flow, which is over once both allow.
bool ${RouterRole.flowIsOver}(String? routeName) {
  final guards = $_list.where((guard) => guard.flow.contains(routeName));
  return guards.isNotEmpty && guards.every((guard) => guard.allows.value);
}
''';

/// The listenable of the app that tells of the changes of its guards.
const _guardChanges = '''

/// Notifies its listeners when a guard starts or stops allowing, so that
/// the router tells its [${RouterRole.guardedNavigation}] of its pages.
final Listenable ${RouterRole.guardChanges} = Listenable.merge([
  for (final guard in ${RouterRole.routeGuards}) guard.allows,
]);
''';

/// The names that the code of [_flowIsOver], of [_answers] and of
/// [_guardedNavigation] has from the role.
const String _navigation = RouterRole.guardedNavigation;
const String _ask = RouterRole.redirectOf;
const String _over = RouterRole.flowIsOver;
const String _list = RouterRole.routeGuards;
const String _changes = RouterRole.guardChanges;

/// The names of the classes of the answers of [RouterRole.guardedNavigation]
/// in the app.
const String _instead = 'ShowInstead';
const String _onTop = 'ShowOver';
const String _nothing = 'ShowNothing';
const String _close = 'ClosePages';

/// The classes of the app for what its guards answer its router.
const _answers = '''

/// What [$_navigation.asked] answers a router that is not to show the
/// location that it asked about: [$_instead], [$_onTop] or [$_nothing].
sealed class WhenAsked<L> {}

/// What [$_navigation.changed] answers a router that is to change its
/// pages: [$_instead] or [$_close].
sealed class WhenChanged<L> {}

/// The router shows [location] in place of its whole stack, as `go()` to
/// it does. A `push()` that it asked about completes with `null`.
final class $_instead<L> implements WhenAsked<L>, WhenChanged<L> {
  /// Creates the answer.
  const $_instead(this.location);

  /// The location to show: the target of a gate, the location that the
  /// user comes back to, or the screen that the app starts on.
  final L location;
}

/// The router shows [location] over the page on top, as `push()` of it
/// does, and keeps the request that it asked about waiting while a page of
/// a route of [flow] is among its pages.
///
/// The router makes the request again once [$_navigation.changed] closes
/// the last of those pages, and drops it when the last of them leaves in
/// another way, as when the user goes back. It keeps one request: a
/// request that waited before is dropped.
final class $_onTop<L> implements WhenAsked<L> {
  /// Creates the answer.
  const $_onTop(this.location, {required this.flow});

  /// The location to show on top: the target of a guard with
  /// [RouteGuard.routes].
  final L location;

  /// The full names of the routes of the flow of that guard.
  final Set<String> flow;
}

/// The router shows nothing and leaves its pages as they are: the flow of
/// the guard is open already. A `push()` that it asked about completes
/// with `null`.
final class $_nothing<L> implements WhenAsked<L> {
  /// Creates the answer.
  const $_nothing();
}

/// The router closes the [pages] pages on top, at once and whatever its
/// navigator shows over them, such as a dialog, and each `push()` that
/// showed one of them completes with `null`. It then makes the request
/// that waits again, if no page of the flow of that request is left.
final class $_close<L> implements WhenChanged<L> {
  /// Creates the answer.
  const $_close(this.pages);

  /// How many pages to close, from the one on top down. The router said of
  /// each that it can close it on its own, and a page stays below them.
  final int pages;
}
''';

/// The class of the app through which its router asks the guards, which
/// keeps what they make the router remember.
const _guardedNavigation = '''

/// The guards of the routes as the router of the app asks them, with what
/// the gates make it remember: the location that the user comes back to
/// once the gates allow it.
///
/// [L] is how the router knows a location that it can show as `go()`
/// does, such as its URI. The router asks [asked] once for each request to
/// show a location, before it shows it, and tells [changed] of its pages
/// each time [$_changes] notifies. It does what either answers, and shows
/// the location, or leaves its pages as they are, when the answer is
/// `null`.
///
/// A gate answers with a location that takes the place of the whole stack.
/// A guard with [RouteGuard.routes] opens its target over the page that
/// the user is on and closes it again, so the user can go back from it,
/// and the request that opened it waits with the router, not here.
final class $_navigation<L> {
  /// Creates the guards for a router whose location `/`, the screen that
  /// the app starts on, is [start], and which knows a location of the
  /// navigation, such as the target of a guard, as [locationOf] says.
  $_navigation({required this.start, required this.locationOf});

  /// The location `/` of the router: the screen that the app starts on.
  final L start;

  /// The location of the router for a location of the navigation.
  final L Function(AppLocation location) locationOf;

  /// The location that the user comes back to once the gates allow it,
  /// with the full name of its route, or `null` if there is none.
  ({String? route, L location})? _remembered;

  /// The guards that do not bring the user back (see [RouteGuard.resumes])
  /// and that allowed when the class last looked at the guards, which it
  /// does each time it is asked or told. One of them that does not allow
  /// at the next look has stopped allowing. The class first looks when it
  /// is first asked or told, so a guard that does not allow then has not
  /// stopped.
  late final Set<RouteGuard> _allowed = {
    for (final guard in $_list)
      if (!guard.resumes && guard.allows.value) guard,
  };

  /// What the router does in place of showing [location], whose route has
  /// the full name [route], or `null` to show it.
  ///
  /// The router asks once for each request, before it shows the location:
  /// the one the app starts on, each one that `go()`, `push()` or
  /// `replace()` is asked to show, and each one from the platform.
  /// [onTopOf] are the full names of the routes of the pages that the user
  /// can get back to then, as the router tells [changed] of them. The
  /// router gives none when it has no page yet, and none for a location
  /// from the platform, which takes the place of the stack.
  ///
  /// The answer is the first of these:
  /// - [$_instead] of the target of the gate that keeps the user from the
  ///   location (see [$_ask]). The location is then remembered in place of
  ///   the one before it, so the user comes back to the latest one that
  ///   they or the platform asked for, whether or not that gate brings the
  ///   user back (see [RouteGuard.resumes]). A location in the flow of a
  ///   guard is never remembered: once that guard allows, its flow is over.
  /// - [$_instead] of [start] for a location in a flow that is over (see
  ///   [$_over]).
  /// - for a location that a guard with [RouteGuard.routes] keeps the user
  ///   from: [$_nothing] while a page of the flow of that guard is among
  ///   [onTopOf], on top or below another page, since the flow is open
  ///   already; and else [$_onTop] of the target of the guard, with its
  ///   flow.
  ///
  /// Nothing is remembered for a guard with routes, so the answer depends
  /// on what the router did about the request before: asked twice about
  /// one request, the class answers [$_nothing] for a flow that the first
  /// answer opened.
  ///
  /// What a gate made the class remember is forgotten when no gate keeps
  /// the user from the location and it is outside every flow, or in one
  /// that is over: the user has moved on, as when the code of the app
  /// navigates right when a gate starts allowing. Before that, it is
  /// forgotten if a guard that does not bring the user back stopped
  /// allowing, as [changed] says.
  WhenAsked<L>? asked(
    String? route,
    L location, {
    required Iterable<String?> onTopOf,
  }) {
    _forgetAfterStop();
    final guard = _guardKeepingFrom(route);
    if (guard != null && guard.routes == null) {
      if (!_inAFlow(route)) _remembered = (route: route, location: location);
      return $_instead(locationOf(guard.redirectTo));
    }
    final over = $_over(route);
    if (over || !_inAFlow(route)) _remembered = null;
    if (over) return $_instead(start);
    if (guard == null) return null;
    if (onTopOf.any(guard.flow.contains)) return const $_nothing();
    return $_onTop(locationOf(guard.redirectTo), flow: guard.flow);
  }

  /// What the router does now that a guard started or stopped allowing, or
  /// `null` to leave its pages as they are.
  ///
  /// [pages] are the pages that the user can get back to, the one on top
  /// first: those of the root navigator and of the selected branch of the
  /// main navigation, each with the full name of its route, its location,
  /// and whether the router can close it on its own and leave the pages
  /// below it as they are. That holds for a page that `push()` showed, and
  /// for one that `replace()` showed in place of such a page. There are
  /// none for a router that has no page yet.
  ///
  /// First, the remembered location is forgotten if a guard that does not
  /// bring the user back (see [RouteGuard.resumes]) stopped allowing: it
  /// allowed when the class was last asked or told, and does not now. That
  /// holds whichever guard decides and whatever the pages are, and for
  /// whichever gate the location was remembered, so that the next user
  /// does not come to a location of the last one. A guard that stops and
  /// allows again without the class being asked or told in between is not
  /// seen to stop.
  ///
  /// The answer is then the first of these:
  /// - [$_instead] of the target of the gate that keeps the user from one
  ///   of the pages. If that gate brings the user back, the location below
  ///   the pages that the router can close is then remembered, or [start]
  ///   if it can close them all, unless one is remembered already or it is
  ///   in the flow of a guard.
  /// - with a location remembered: `null` while a gate keeps the user from
  ///   it. Otherwise the location is forgotten, and the answer is
  ///   [$_instead] of it, or of [start] if a guard with
  ///   [RouteGuard.routes] keeps the user from it: the class cannot keep a
  ///   request waiting, so the user moves on to [start].
  /// - for the lowest page that has to leave, which is in a flow that is
  ///   over (see [$_over]) or which a guard with [RouteGuard.routes] keeps
  ///   the user from: [$_close] of that page and the pages over it, if the
  ///   router can close each of them and a page stays below; and else
  ///   [$_instead] of [start].
  ///
  /// So the pages of a flow close once its guards allow, also below a page
  /// that was pushed from them, and a page that asks for a condition
  /// closes when the condition stops holding. A page that took the place
  /// of the stack, as after `go()` to it, has nothing below it: the user
  /// then comes to [start].
  ///
  /// A known limit of the second answer: a location that a guard with
  /// [RouteGuard.routes] keeps the user from, and that was asked for
  /// behind a gate, is lost once the gate allows. A link to such a route
  /// that opens the app on a first launch, behind an onboarding, leaves
  /// the user on [start], though [asked] opens the flow of the guard over
  /// [start] for the same link when no gate is in its way.
  WhenChanged<L>? changed(
    Iterable<({String? route, L location, bool pushed})> pages,
  ) {
    _forgetAfterStop();
    final all = pages.toList();
    for (final page in all) {
      final gate = _guardKeepingFrom(page.route);
      if (gate == null || gate.routes != null) continue;
      final below = all.where((other) => !other.pushed).firstOrNull;
      if (gate.resumes && _remembered == null && !_inAFlow(below?.route)) {
        _remembered = (
          route: below?.route,
          location: below == null ? start : below.location,
        );
      }
      return $_instead(locationOf(gate.redirectTo));
    }
    if (_remembered case final remembered?) {
      final guard = _guardKeepingFrom(remembered.route);
      // The pages are those of the flow of the gate, which is not over.
      if (guard != null && guard.routes == null) return null;
      _remembered = null;
      return $_instead(guard == null ? remembered.location : start);
    }
    // No gate keeps the user from a page, so a guard that does is one with
    // routes.
    final lowest = all.lastIndexWhere(
      (page) => $_over(page.route) || _guardKeepingFrom(page.route) != null,
    );
    if (lowest < 0) return null;
    final leaving = all.take(lowest + 1);
    return leaving.every((page) => page.pushed) && lowest + 1 < all.length
        ? $_close(lowest + 1)
        : $_instead(start);
  }

  /// Forgets the remembered location if a guard that does not bring the
  /// user back stopped allowing since the class last looked at the guards,
  /// and notes which of those guards allow now.
  void _forgetAfterStop() {
    for (final guard in $_list) {
      if (guard.resumes) continue;
      if (guard.allows.value) {
        _allowed.add(guard);
      } else if (_allowed.remove(guard)) {
        _remembered = null;
      }
    }
  }

  /// Whether [route] is in the flow of a guard, of whichever guard.
  static bool _inAFlow(String? route) =>
      $_list.any((guard) => guard.flow.contains(route));
}''';

List<SmfIssue> _checkGuards(ModuleRuleInput<RoutesData> input) {
  final origin = ModuleOrigin(input.module.id);
  final routes = [for (final data in input.data) ...data.value.routes];
  final names = <String>{};
  final conditions = <RouteCondition>{};
  final problems = <String>[];
  for (final data in input.data) {
    for (final guard in data.value.guards) {
      final label = 'The guard "${guard.name}"';
      if (!_isMemberName(guard.name, const {})) {
        problems.add(
          '$label needs a name that is a lowerCamelCase Dart identifier, '
          'such as firstRun.',
        );
      }
      if (!names.add(guard.name)) {
        problems.add('Two guards of the module are named "${guard.name}".');
      }
      problems
        ..addAll(_guardFunctionProblems(guard, label))
        ..addAll(_guardTargetProblems(guard, label, routes));
      if (guard.condition case final condition?) {
        problems.addAll(
          _guardConditionProblems(
            condition,
            label,
            input.module,
            first: conditions.add(condition),
          ),
        );
      }
    }
  }
  return [for (final problem in problems) SmfIssue(problem, origin: origin)];
}

/// The problems with [condition], which the guard of [label] of [module]
/// stands for; [first] is whether no guard of the module before it stands
/// for the same condition.
///
/// The function of the guard says whether the condition holds, which it
/// reads from what the role of the condition has. So the module has that
/// role in every app: it requires or provides it, and does not only use
/// it. And a route that asks for the condition shows the target of one
/// guard, so a module has one guard for a condition.
List<String> _guardConditionProblems(
  RouteCondition condition,
  String label,
  ModuleDescriptor module, {
  required bool first,
}) {
  final role = condition.role;
  final problems = <String>[];
  if (!module.provides.contains(role) &&
      !module.effectiveRequires.contains(role)) {
    problems.add(
      '$label stands for the condition $condition, but the module neither '
      'requires nor provides the $role, whose condition it is.',
    );
  }
  if (!first) {
    problems.add(
      'Two guards of the module stand for the condition $condition; an app '
      'has one guard for a condition.',
    );
  }
  return problems;
}

/// The problems with the function of [guard], the guard of [label]: it is
/// a public function of a file of the app, which the role imports itself.
List<String> _guardFunctionProblems(RouteGuard guard, String label) {
  final allows = guard.allows;
  final import = allows.import;
  final problems = [
    for (final problem in allows.problems()) '$label: $problem',
  ];
  if (!import.isAppFile) {
    problems.add(
      '$label asks a function of "${import.uri}"; its function is in a file '
      'of the app, imported with ImportRef.app.',
    );
  }
  if (import.prefix != null || import.show.isNotEmpty) {
    problems.add(
      '$label imports its function with a prefix or show; the router role '
      'imports the file with a prefix of its own.',
    );
  }
  return problems;
}

/// The problems with the target of [guard], the guard of [label], among
/// [routes], the top-level routes of its module.
///
/// The target is a top-level route, as the router shows it without the
/// pages of other routes below it. It needs no values, as the router has
/// none to give it. It is outside the main navigation, which the guard
/// keeps the user out of. And no route of its flow can start the app: the
/// routes of a flow show only while its guard does not allow, and the
/// router shows the screen that the app starts on in their place once the
/// flow is over.
List<String> _guardTargetProblems(
  RouteGuard guard,
  String label,
  List<Route> routes,
) {
  String shows(Route route) =>
      '$label shows the route "${route.name}" (${route.path})';
  bool isTarget(Route route) => route.name == guard.redirectTo;
  final target = routes.where(isTarget).firstOrNull;
  if (target == null) {
    final child = _flowOf(routes).where(isTarget).firstOrNull;
    final problem = child == null
        ? '$label shows the route "${guard.redirectTo}", but the module has '
            'no route of that name.'
        : '${shows(child)}, which is a child; the target of a guard is a '
            'top-level route, since a child shows on top of its parents.';
    return [problem];
  }
  final problems = <String>[];
  final required = target.params.where((param) => param.isRequired);
  if (required.isNotEmpty) {
    problems.add(
      '${shows(target)}, which needs ${required.join(', ')}; the router shows '
      'the target of a guard without values.',
    );
  }
  if (target.destination != null) {
    problems.add(
      '${shows(target)}, which is a destination of the main navigation; a '
      'guard keeps the user out of the main navigation, so its target is '
      'outside it.',
    );
  }
  for (final route in _flowOf([target])) {
    if (!route.startCandidate) continue;
    problems.add(
      '${shows(target)}, but the route "${route.name}" (${route.path}) of its '
      'flow is a start candidate; the app shows the flow of a guard until the '
      'guard allows, and then the screen that it starts on.',
    );
  }
  return problems;
}

/// [routes] and the routes below them, parents first.
Iterable<Route> _flowOf(List<Route> routes) sync* {
  for (final route in routes) {
    yield route;
    yield* _flowOf(route.children);
  }
}

/// The problems with the functions that the guards of the app in [input]
/// name: a function missing from its file of the app, one that needs
/// arguments, since the role's template calls it without any, and one that
/// does not say that it returns a `ValueListenable<bool>`.
///
/// The module rule `router.guards` reports a function outside the app.
List<SmfIssue> _checkGuardFunctions(StructuralRuleInput<RoutesData> input) {
  final issues = <SmfIssue>[];
  for (final guard in routerRole.facadeOf(input.roleInput).guards) {
    final allows = guard.guard.allows;
    if (!allows.import.isAppFile) continue;
    final function = RequiredFunction(
      allows.name,
      path: 'lib/${allows.import.uri}',
      returnType: 'ValueListenable<bool>',
    );
    for (final issue in function.checkIn(input.files)) {
      issues.add(
        SmfIssue(
          'The function of the $guard: ${issue.message}',
          hint: 'The router role calls it without arguments, and listens to '
              'the ValueListenable<bool> that it returns.',
          origin: ModuleOrigin(guard.feature.module),
          path: issue.path,
        ),
      );
    }
  }
  return issues;
}

/// The problems of the provider of the role in an app with guards, in
/// [input]: none of its files creates a [RouterRole.guardedNavigation], or
/// none reads [RouterRole.guardChanges], through an import of the file of
/// the role; and none of them names the answer of that class that opens
/// the target of a guard over the page on top, or the one that closes
/// pages, as code that tells an answer by its type does.
///
/// So a router that knows nothing of the guards cannot be in an app with a
/// module that needs them, and neither can one that shows every answer in
/// place of its stack, as a router did before the class had those answers.
/// The rule asks for both answers in every app with guards, also in one
/// whose guards are all gates, which get neither: the provider is the same
/// router there, and a guard with routes that a developer adds to the app
/// by hand needs no other. The rule does not tell whether the provider
/// asks what it created, and does what it answers: only a running app
/// shows that. Without the descriptor of a provider in [input], no file
/// asks the guards and there is nothing to check.
List<SmfIssue> _checkGuardsAsked(StructuralRuleInput<RoutesData> input) {
  if (routerRole.facadeOf(input.roleInput).guards.isEmpty) return const [];
  final providers = [
    for (final module in input.modules)
      if (module.provides.contains(routerRole)) module.id,
  ];
  if (providers.isEmpty) return const [];
  final files = [
    for (final MapEntry(key: path, value: file) in input.files.entries)
      if (input.owners[path] case ModuleOrigin(:final module)
          when providers.contains(module))
        file,
  ];
  bool uses(String name) => files.any(
        (file) => usesSymbols(file, {name}, RouterRole.appRouterFile),
      );
  bool names(String type) => files.any(
        (file) => namesTypes(file, {type}, RouterRole.appRouterFile),
      );
  SmfIssue issue(String message, String hint) => SmfIssue(
        message,
        hint: '$hint; see RouterRole.guardedNavigation.',
        origin: ModuleOrigin(providers.first),
        path: RouterRole.appRouterFactoryFile,
      );
  return [
    for (final (name, use) in const [
      (
        RouterRole.guardedNavigation,
        'creates a ${RouterRole.guardedNavigation}',
      ),
      (RouterRole.guardChanges, 'reads ${RouterRole.guardChanges}'),
    ])
      if (!uses(name))
        issue(
          'The provider of the $routerRole does not ask the guards of the '
              'app: none of its files $use of ${RouterRole.appRouterFile}.',
          'A router asks its ${RouterRole.guardedNavigation} about every '
              'location before it shows it, and tells it of its pages when '
              '${RouterRole.guardChanges} notifies',
        ),
    for (final answer in const [_onTop, _close])
      if (!names(answer))
        issue(
          'The provider of the $routerRole does not do what the guards of '
              'the app answer: none of its files names the answer $answer '
              'of ${RouterRole.appRouterFile}.',
          'A router opens the target of a guard with routes over the page '
              'on top for the answer $_onTop, and closes the pages on top '
              'for the answer $_close',
        ),
  ];
}
