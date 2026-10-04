import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart' show AppNavigator, AppRouter{{#guards}}, GuardedNavigation, guardChanges{{/guards}};
import 'navigation.dart' show AppLocation;

/// Creates the router of the app: a [GoRouter] with the routes of the
/// modules of the app.
AppRouter createAppRouter() => _GoAppRouter();

/// The router of the app with go_router, which navigates between the
/// locations of the app too, and tells the listeners of the screen the user
/// sees when it changes.
final class _GoAppRouter implements AppRouter, AppNavigator {
{{#guards}}  /// Creates the router, which tells the guards of the app of its pages
  /// when one of them starts or stops allowing.
  _GoAppRouter() {
    guardChanges.addListener(_guardsChanged);
  }

{{/guards}}  /// The router, created once, on first use. Navigation goes through it
  /// rather than through the router above a context, so that any context
  /// can navigate, even one above the router.
  @override
  late final GoRouter config = GoRouter(
    initialLocation: {{{initial_location}}},
    observers: _observers(),{{#guards}}
    redirect: (context, state) =>
        _guards.asked(state.topRoute?.name, '${state.uri}')?.location,{{/guards}}
    routes: [
{{{routes}}}
    ],
  )..routerDelegate.addListener(_pagesChanged);

  /// The key of the page on top and its location, as the listeners of the
  /// screen last heard of them.
  (LocalKey?, String)? _screen;

  /// The pages that pushes showed, by their keys, as the router last saw
  /// them among the pages of go_router.
  Map<LocalKey, ImperativeRouteMatch> _pushed = {};

  /// For each completer that go_router gave a pushed page anew, the
  /// completer of the push that showed the page.
  final Expando<Completer<Object?>> _pushes = Expando();{{#guards}}

  /// The guards of the app as the router asks them, which keep the location
  /// that the user comes back to once they allow it. The router knows a
  /// location by its URI, and `/` is the screen that the app starts on.
  ///
  /// go_router asks them about every location that it parses, in its
  /// `redirect`: the one the app starts on, those of [go] and those of the
  /// platform, and goes to the location that they answer. [push] and
  /// [replace] ask them before they hand a location to go_router, which
  /// would put the target of the guard on top of the stack.
  final GuardedNavigation<String> _guards = GuardedNavigation(
    start: '/',
    locationOf: (location) => location.path,
  );{{/guards}}

  @override
  AppNavigator navigatorOf(BuildContext context) => this;

  @override
  void go(AppLocation location) => config.go(location.path);

  @override
  Future<T?> push<T extends Object?>(AppLocation location) {
    {{#guards}}final guarded = _guards.asked(location.routeName, location.path);
    if (guarded != null) {
      config.go(guarded.location);
      return Future.value();
    }
    {{/guards}}{{#main_navigation}}_checkMainNavigation(location, 'push');
    {{/main_navigation}}return config.push<T>(location.path);
  }

  @override
  void replace(AppLocation location) {
    {{#guards}}final guarded = _guards.asked(location.routeName, location.path);
    if (guarded != null) return config.go(guarded.location);
    {{/guards}}{{#main_navigation}}_checkMainNavigation(location, 'replace');
    {{/main_navigation}}config.pushReplacement<Object?>(location.path);
  }{{#guards}}

  /// Tells the guards of the pages of the router when one of them starts
  /// or stops allowing, and goes to the location that they answer: the
  /// target of the guard that keeps the user from one of the pages, or the
  /// location that the user comes back to once the guards allow it.
  ///
  /// The pages of the router are those that pushes showed, the one on top
  /// first, and, below them, the location that go_router went to last. A
  /// page that [replace] showed over other pages is one that a push showed
  /// to go_router. The router listens to the guards itself rather than
  /// through the `refreshListenable` of go_router, whose refresh asks only
  /// about the location below the pushed pages.
  void _guardsChanged() {
    final configuration = config.routerDelegate.currentConfiguration;
    // Before its first location, the router has no page to tell of. The
    // guards still take note of what they allow, so that a notification
    // without a change does not look like one later.
    if (configuration.isEmpty && !configuration.isError) {
      _guards.changed(const []);
      return;
    }
    final below = config.configuration.findMatch(configuration.uri);
    final shown = _guards.changed([
      for (final page in _pushedPages(configuration.matches).toList().reversed)
        (route: page.route.name, location: '${page.matches.uri}', pushed: true),
      (
        route: below.lastOrNull?.route.name,
        location: '${configuration.uri}',
        pushed: false,
      ),
    ]);
    if (shown != null) config.go(shown.location);
  }{{/guards}}

  /// Follows the pages of go_router, whose delegate notifies its listeners
  /// of each change of them: keeps each push completing with the value of
  /// its page, and tells the listeners of the screen about the page on top.
  void _pagesChanged() {
    _keepPushes();
    _showScreen();
  }

  /// Lets each push complete with the value that its page returns when it
  /// closes, whatever completer go_router gives the page.
  ///
  /// go_router completes a push with the completer that it gives the page
  /// it pushed, which the page completes when it closes. When go_router
  /// shows its pages anew from their encoded form, as on [GoRouter.refresh],
  /// such as when its `refreshListenable` notifies, it gives each pushed
  /// page a new completer, though the page keeps its key and its location,
  /// so the push would never complete
  /// (https://github.com/flutter/flutter/issues/128122). So when a page
  /// comes back at its location with another completer, the router passes
  /// on the value of that completer to that of the push. A branch of the
  /// main navigation that is not selected keeps its pages as they were, so
  /// a page that comes back with its branch passes on its value as before.
  /// Once go_router keeps the completers of its pages, this does nothing
  /// and can go.
  void _keepPushes() {
    final pushed = {
      for (final page in _pushedPages(
        config.routerDelegate.currentConfiguration.matches,
      ))
        page.pageKey: page,
    };
    for (final page in pushed.values) {
      final before = _pushed[page.pageKey];
      if (before == null ||
          before.completer == page.completer ||
          before.matches.uri != page.matches.uri) {
        continue;
      }
      final push = _pushes[before.completer] ?? before.completer;
      _pushes[page.completer] = push;
      unawaited(
        page.completer.future.then((value) {
          if (!push.isCompleted) push.complete(value);
        }),
      );
    }
    _pushed = pushed;
  }

  /// The pages that pushes showed among [matches], in the stacks of the
  /// main navigation too.
  static Iterable<ImperativeRouteMatch> _pushedPages(
    List<RouteMatchBase> matches,
  ) sync* {
    for (final match in matches) {
      if (match is ImperativeRouteMatch) yield match;
      if (match is ShellRouteMatch) yield* _pushedPages(match.matches);
    }
  }

  /// Tells the listeners of the screen about the page on top when another
  /// page comes on top, or the page on top shows another location.
  ///
  /// The delegate of go_router notifies its listeners once for each change
  /// of its configuration, a switch of branches included, and may do so
  /// again without a change of the page on top, which the listeners of the
  /// screen do not hear of twice. The location of a pushed page is its own,
  /// as that of the configuration leaves pushed pages out. The error screen
  /// of go_router has no route match, or, for a location pushed in error, a
  /// route without a name.
  void _showScreen() {
    final configuration = config.routerDelegate.currentConfiguration;
    final top = configuration.lastOrNull;
    final location = switch (top) {
      ImperativeRouteMatch(:final matches) => matches.uri.toString(),
      _ => configuration.uri.toString(),
    };
    final screen = (top?.pageKey, location);
    if (screen == _screen) return;
    _screen = screen;
    for (final listener in _screenListeners) {
      _callAlone(listener, top?.route.name, location);
    }
  }{{#main_navigation}}

  /// Throws a [StateError] instead of showing [location] of the main
  /// navigation on top of a page that is shown over the main navigation:
  /// go_router shows the main navigation once, so a location in it goes
  /// only on top of the main navigation itself.
  void _checkMainNavigation(AppLocation location, String method) {
    final matches = config.routerDelegate.currentConfiguration.matches;
    if (matches.isEmpty ||
        matches.last is ShellRouteMatch ||
        !matches.any((match) => match is ShellRouteMatch)) {
      return;
    }
    final target = config.configuration.findMatch(Uri.parse(location.path));
    if (target.matches.firstOrNull is! ShellRouteMatch) return;
    throw StateError(
      'Cannot $method ${location.path}: it is in the main navigation, and a '
      'page is shown over the main navigation. Use go() to show it there.',
    );
  }{{/main_navigation}}
}

/// Creates the observers of a navigator. An observer can watch only one
/// navigator, so each navigator gets instances of its own.
List<NavigatorObserver> _observers() => [
  for (final create in <NavigatorObserver Function()>[
{{{smf_router__observers}}}
  ])
    create(),
];

/// The listeners of the screen the user sees, which get the full name of
/// the route of the screen, or `null` for a screen that is not a route of a
/// module, and its location.
final List<void Function(String? route, String location)> _screenListeners = [
{{{smf_router__screen_listeners}}}
];

/// Calls [listener] of the screen with [route] and [location] on its own:
/// what it throws keeps no other listener from hearing the screen, and
/// reaches neither the router nor the handlers of the errors of the app. In
/// debug mode it is printed, so that a listener that fails shows in the
/// console.
void _callAlone(
  void Function(String? route, String location) listener,
  String? route,
  String location,
) {
  try {
    listener(route, location);
  } on Object catch (error) {
    if (kDebugMode) {
      debugPrint('A listener of the screen failed: $error');
    }
  }
}
{{{value_checks}}}
