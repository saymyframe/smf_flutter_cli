import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart' show AppNavigator, AppRouter{{#guards}}, ClosePages, GuardedNavigation, ShowInstead, ShowNothing, ShowOver, guardChanges{{/guards}};
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
  late final GoRouter config = _GoRouter{{^main_navigation}}(
    initialLocation: {{{initial_location}}},
    observers: _observers(),{{/main_navigation}}{{#main_navigation}}.routingConfig(
    routingConfig: _routes,
    initialLocation: {{{initial_location}}},
    observers: _observers(),
  )..routerDelegate.addListener(_pagesChanged);

  /// The routes of the app, which go_router follows when they change, so
  /// that the router can give it a new main navigation; see
  /// [_renewMainNavigation].
  late final ValueNotifier<RoutingConfig> _routes = ValueNotifier(
    RoutingConfig({{/main_navigation}}{{#guards}}
    redirect: (context, state) =>
        _redirect(state.topRoute?.name, '${state.uri}'),{{/guards}}
    routes: [
{{{routes}}}
    ],
  ){{^main_navigation}}..routerDelegate.addListener(_pagesChanged);{{/main_navigation}}{{#main_navigation}},
  );

  /// The route of the main navigation that [_routes] has now.
  late StatefulShellRoute _mainNavigationRoute = _mainNavigation();

  /// Whether the main navigation of [_mainNavigationRoute] is, or was,
  /// among the pages of the router.
  bool _mainNavigationShown = false;

  /// Whether the router is giving go_router its new routes, which changes
  /// the pages of go_router for a moment that the router does not follow.
  bool _renewing = false;{{/main_navigation}}

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
  /// that the user comes back to once the gates allow it. The router knows
  /// a location by its URI, and `/` is the screen that the app starts on.
  ///
  /// The router asks them about each location before go_router shows it:
  /// [go], [push] and [replace] ask in [_redirected], with the pages that
  /// the location is asked for on top of, and the `redirect` of go_router
  /// asks in [_redirect] about the locations that go_router parses on its
  /// own, which take the place of the stack. The `redirect` runs for the
  /// calls of the router too, with a location that the guards let the user
  /// see or that they answered: they then answer nothing a second time.
  final GuardedNavigation<String> _guards = GuardedNavigation(
    start: '/',
    locationOf: (location) => location.path,
  );

  /// The request that waits for a flow that the guards opened over the page
  /// on top, if there is one: the routes of the flow, how to make the
  /// request again, and how to end it without showing its location.
  ({Set<String> flow, void Function() again, void Function()? drop})? _waiting;

  /// What opens the flow of a guard over the screen that the app starts
  /// on, once go_router shows that screen; see [_redirect].
  void Function()? _opening;

  /// Whether the listeners of the screen wait for the router to finish what
  /// the guards answered, of which they hear only the page that it ends on.
  bool _muted = false;{{/guards}}

  @override
  AppNavigator navigatorOf(BuildContext context) => this;

  @override
  void go(AppLocation location) {{^guards}}=> config.go(location.path);{{/guards}}{{#guards}}{
    if (!_withoutPage && _redirected(location, again: () => go(location))) {
      return;
    }
    config.go(location.path);
  }{{/guards}}

  @override
  Future<T?> push<T extends Object?>(AppLocation location) {
    if (_withoutPage) {
      go(location);
      return Future.value();
    }
    {{#guards}}// A push that waits for a flow completes with what the request
    // completes with when the router makes it again, or with `null`.
    final waiting = Completer<T?>();
    if (_redirected(
      location,
      again: () => waiting.complete(push<T>(location)),
      drop: waiting.complete,
    )) {
      return waiting.future;
    }
    {{/guards}}{{#main_navigation}}_checkMainNavigation(location, 'push');
    {{/main_navigation}}return config.push<T>(location.path);
  }

  @override
  void replace(AppLocation location) {
    if (_withoutPage) return go(location);
    {{#guards}}if (_redirected(location, again: () => replace(location))) return;
    {{/guards}}{{#main_navigation}}_checkMainNavigation(location, 'replace');
    {{/main_navigation}}config.pushReplacement<Object?>(location.path);
  }

  /// Whether go_router has no page of a route: before it shows its first
  /// location, and while it shows its error screen in place of the whole
  /// stack, as for a location that no route matches.
  ///
  /// It has no page to push over then, and none to replace.
  /// `GoRouter.push` would keep the error screen and never complete, or
  /// throw for a location in the main navigation, and before the first
  /// location the app would start on the pushed page alone.
  /// `GoRouter.pushReplacement` throws for want of a page. So [push] and
  /// [replace] give go_router their location as [go] does: it shows with
  /// the pages of its chain, in place of the error screen, and such a push
  /// completes with `null`.{{#guards}} The router asks the guards nothing
  /// itself then: the `redirect` of go_router asks, with no pages.{{/guards}}
  /// An error screen that a push showed over a page is a page of
  /// go_router, which pushes over it and replaces it like any other.
  bool get _withoutPage =>
      config.routerDelegate.currentConfiguration.matches.isEmpty;{{#guards}}

  /// Runs [navigate], of which the listeners of the screen hear only the
  /// page that it ends on. That page is not there yet while the `redirect`
  /// of go_router has a target to open over `/`: they then hear of the
  /// target when [_redirect] opens it, and nothing of `/`.
  void _quietly(void Function() navigate) {
    final muted = _muted;
    _muted = true;
    try {
      navigate();
    } finally {
      _muted = muted || _opening != null;
      if (!_muted) _showScreen();
    }
  }

  /// What go_router goes to in place of [location] of [route], a location
  /// that it parses on its own: the one that the app starts on, those of
  /// the platform, and that of a branch of the main navigation that the
  /// user selects. Such a location takes the place of the stack, so the
  /// guards are told of no pages.
  ///
  /// For the flow of a guard that they open, go_router goes to the screen
  /// that the app starts on, and the router shows the target over it once
  /// the parse is over: go_router tells nobody of pages that it has
  /// already, as when the user is on that screen. The listeners of the
  /// screen hear only of the target.
  String? _redirect(String? route, String location) {
    switch (_guards.asked(route, location, onTopOf: const [])) {
      case null || ShowNothing():
        return null;
      case ShowInstead(location: final shown):
        return shown;
      case ShowOver(location: final target, :final flow):
        _muted = true;
        void open() {
          if (_opening != open) return;
          _opening = null;
          _muted = false;
          _open(target, flow, again: () => config.go(location));
        }
        _opening = open;
        scheduleMicrotask(open);
        return _guards.start;
    }
  }

  /// Does what the guards answer for [location], which [go], [push] or
  /// [replace] is asked to show; `false` if they let the user see it.
  ///
  /// [again] makes the request again, and [drop] ends it without showing
  /// its location, as a push does that completes with `null`.
  ///
  /// go_router has a page of a route then; see [_withoutPage]. Without
  /// one, the `redirect` of go_router asks about the location, with no
  /// pages: the target of a guard that stands for a condition then opens
  /// over `/`, in place of the error screen too.
  bool _redirected(
    AppLocation location, {
    required void Function() again,
    void Function()? drop,
  }) {
    final answer = _guards.asked(
      location.routeName,
      location.path,
      onTopOf: [for (final page in _pages) page.route],
    );
    switch (answer) {
      case null:
        return false;
      case ShowInstead(location: final shown):
        config.go(shown);
        drop?.call();
      case ShowNothing():
        drop?.call();
      case ShowOver(location: final target, :final flow):
        _open(target, flow, again: again, drop: drop);
    }
    return true;
  }

  /// Shows [target], the target of a guard, over the page on top, and keeps
  /// the request of [again] and [drop] waiting while a page of [flow] is
  /// among the pages: [_close] makes it again, and [_pagesChanged] drops
  /// it. A request that waited before is dropped.
  void _open(
    String target,
    Set<String> flow, {
    required void Function() again,
    void Function()? drop,
  }) {
    _drop();
    unawaited(config.push<Object?>(target));
    _waiting = (flow: flow, again: again, drop: drop);
  }

  /// Drops the request that waits, if there is one.
  void _drop() {
    final waiting = _waiting;
    _waiting = null;
    waiting?.drop?.call();
  }

  /// Closes the [count] pages on top, each of which a push showed. Then it
  /// drops the request that waits, with [dropsRequest], or else makes it
  /// again, if no page of its flow is left. The listeners of the screen
  /// hear of the page that the user ends on.
  ///
  /// The pages go out of the pages of go_router at once, with one
  /// `restore()` of its pages without them. `pop()` would close what the
  /// navigator shows on top, such as a dialog over the page, and it cannot
  /// close a page that a push of the same turn showed, which the navigator
  /// has not built yet.
  ///
  /// go_router does not complete the push of a page that leaves that way,
  /// so the router does, once the frame is over. Until its next build the
  /// navigator still has the routes of those pages. When one of them is
  /// popped in that time, by the code of its screen or by the back button
  /// of the system, go_router completes its push itself, and would throw
  /// on a push that is completed already.
  void _close(int count, {required bool dropsRequest}) {
    final waiting = _waiting;
    _waiting = null;
    _quietly(() {
      final shown = config.routerDelegate.currentConfiguration;
      final closing = _pushedPages(
        shown.matches,
      ).toList().reversed.take(count).toList();
      config.restore(shown.remove(closing.last));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final page in closing) {
          if (!page.completer.isCompleted) page.completer.complete();
        }
      });
      if (waiting == null) return;
      if (dropsRequest) {
        waiting.drop?.call();
      } else if (_shows(waiting.flow)) {
        _waiting = waiting;
      } else {
        waiting.again();
      }
    });
  }

  /// Whether a page of a route of [flow] is among the pages of the router.
  bool _shows(Set<String> flow) =>
      _pages.any((page) => flow.contains(page.route));

  /// The pages that the user can get back to, as the guards are told of
  /// them: those that pushes showed, the one on top first, each of which
  /// the router can close on its own, and, below them, the location that
  /// go_router went to last; none before go_router has a page. A page that
  /// [replace] showed over other pages is one that a push showed to
  /// go_router.
  List<({String? route, String location, bool pushed})> get _pages {
    final configuration = config.routerDelegate.currentConfiguration;
    if (configuration.isEmpty && !configuration.isError) return const [];
    final below = config.configuration.findMatch(configuration.uri);
    return [
      for (final page in _pushedPages(configuration.matches).toList().reversed)
        (route: page.route.name, location: '${page.matches.uri}', pushed: true),
      (
        route: below.lastOrNull?.route.name,
        location: '${configuration.uri}',
        pushed: false,
      ),
    ];
  }

  /// Tells the guards of the pages of the router when one of them starts
  /// or stops allowing, and does what they answer: goes to a location,
  /// which is the target of the gate that keeps the user from one of the
  /// pages, the location that the user comes back to once the gates allow
  /// it, or `/`; or closes the pages on top, those of a flow that is over
  /// or of routes whose condition stopped holding.
  ///
  /// The router listens to the guards itself rather than through the
  /// `refreshListenable` of go_router, whose refresh asks only about the
  /// location below the pushed pages. Before its first location, it has no
  /// page to tell the guards of, and no stack that an answer of theirs
  /// could take the place of: go_router asks them about that location when
  /// it shows it.
  void _guardsChanged() {
    final pages = _pages;
    if (pages.isEmpty) return;
    switch (_guards.changed(pages)) {
      case null:
        break;
      case ShowInstead(:final location):
        config.go(location);
      case ClosePages(pages: final count, :final dropsRequest):
        _close(count, dropsRequest: dropsRequest);
    }
  }{{/guards}}

  /// Follows the pages of go_router, whose delegate notifies its listeners
  /// of each change of them: keeps each push completing with the value of
  /// its page, and tells the listeners of the screen about the page on top.{{#guards}}
  /// And it drops the request that waits for a flow once no page of the
  /// flow is among the pages, as when the user went back from it or another
  /// location took the place of the stack.{{/guards}}{{#main_navigation}}
  /// Before that, it gives go_router a new main navigation if the main
  /// navigation has left the pages. Nothing here needs that order today:
  /// it is for code that navigates when the pages change, which then finds
  /// the new routes.{{/main_navigation}}
  void _pagesChanged() {
    {{#main_navigation}}if (_renewing) return;
    _renewMainNavigation();
    {{/main_navigation}}_keepPushes();{{#guards}}
    if (_waiting case final waiting? when !_shows(waiting.flow)) _drop();
    if (_muted) return;{{/guards}}
    _showScreen();
  }{{#main_navigation}}

  /// Gives go_router a new route for the main navigation once the main
  /// navigation has left the pages of the router, as when the target of a
  /// guard takes the place of the whole stack.
  ///
  /// go_router keeps the pages of each branch, and the navigator that shows
  /// them, under keys of the route of the main navigation, for as long as a
  /// page of that route is in the widget tree: until the transition to the
  /// page that took its place is over. A main navigation that comes back
  /// sooner, such as in the same turn, would have the pages of its branches
  /// again, though a guard may keep the user from them since. And while
  /// the page that left is still in the tree, Flutter finds those keys
  /// there twice and throws
  /// (https://github.com/flutter/flutter/issues/148768). A new route has
  /// keys of its own, so the main navigation comes back with each branch on
  /// its destination, at any time. Once go_router gives the main navigation
  /// that comes back a state of its own, this can go.
  ///
  /// The other routes stay the same objects, and the new configuration has
  /// what the one before it had. When its routes change, go_router matches
  /// its location again, without the redirects of the routes. So a
  /// location that a redirect refused, such as one without a value that its
  /// route requires, would get the page of its route in place of the error
  /// screen: the router puts back the pages that go_router had.
  void _renewMainNavigation() {
    final shown = config.routerDelegate.currentConfiguration;
    if (shown.matches.any(
      (page) => identical(page.route, _mainNavigationRoute),
    )) {
      _mainNavigationShown = true;
      return;
    }
    if (!_mainNavigationShown) return;
    _mainNavigationShown = false;
    final left = _mainNavigationRoute;
    final routes = _routes.value;
    _mainNavigationRoute = _mainNavigation();
    _renewing = true;
    try {
      _routes.value = RoutingConfig(
        routes: [
          for (final route in routes.routes)
            identical(route, left) ? _mainNavigationRoute : route,
        ],
        onEnter: routes.onEnter,
        redirect: routes.redirect,
        redirectLimit: routes.redirectLimit,
      );
      if (config.routerDelegate.currentConfiguration != shown) {
        config.restore(shown);
      }
    } finally {
      _renewing = false;
    }
  }{{/main_navigation}}

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
{{{main_navigation_route}}}
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

/// The [GoRouter] of the app, which hears of the back button of the system
/// through [_BackButton]: go_router takes no dispatcher of the button, so
/// the router has one of its own in place of that of [GoRouter].
final class _GoRouter extends GoRouter {
{{^main_navigation}}  /// Creates the router of [routes], as [GoRouter.new] does.
  _GoRouter({
    required List<RouteBase> routes,{{#guards}}
    required GoRouterRedirect redirect,{{/guards}}
    super.initialLocation,
    super.observers,
  }) : super.routingConfig(
         routingConfig: ValueNotifier(
           RoutingConfig(routes: routes{{#guards}}, redirect: redirect{{/guards}}),
         ),
       );{{/main_navigation}}{{#main_navigation}}  /// Creates the router, as [GoRouter.routingConfig] does.
  _GoRouter.routingConfig({
    required super.routingConfig,
    super.initialLocation,
    super.observers,
  }) : super.routingConfig();{{/main_navigation}}

  @override
  BackButtonDispatcher get backButtonDispatcher => _backButton;

  late final _BackButton _backButton = _BackButton(this);
}

/// The dispatcher of the back button of the system for go_router, which
/// asks go_router to close the route on top only while go_router has a page
/// of a route.
///
/// go_router shows its error screen in place of the whole stack, for a
/// location that no route matches or that the redirect of a route refuses:
/// it then has no page of a route. Asked to close the route on top, its
/// delegate looks for the last of those pages and throws a [StateError]
/// (https://github.com/flutter/flutter/issues/187616). So on that screen
/// the dispatcher asks the root navigator, the only one there, itself: a
/// route that is shown over the error screen, such as a dialog, closes, and
/// with no route to close the button is left to the system, as on the
/// first page of the app. An error screen that a push showed over a page is
/// a page of go_router, which closes it. Once the delegate of go_router
/// answers without a page, this can go.
final class _BackButton extends RootBackButtonDispatcher {
  /// Creates the dispatcher of the back button of [_router].
  _BackButton(this._router);

  final GoRouter _router;

  /// For each callback that the dispatcher was given, the one that it
  /// calls in its place.
  final Map<ValueGetter<Future<bool>>, ValueGetter<Future<bool>>> _asked = {};

  /// Takes [callback], with which the `Router` of Flutter asks the delegate
  /// of go_router to close the route on top, and calls it only while
  /// go_router has a page. A `BackButtonListener` below the router still
  /// hears of the button first, on the error screen too.
  @override
  void addCallback(ValueGetter<Future<bool>> callback) => super.addCallback(
    _asked[callback] = () {
      final delegate = _router.routerDelegate;
      if (delegate.currentConfiguration.matches.isNotEmpty) return callback();
      return delegate.navigatorKey.currentState?.maybePop() ??
          Future.value(false);
    },
  );

  @override
  void removeCallback(ValueGetter<Future<bool>> callback) =>
      super.removeCallback(_asked.remove(callback) ?? callback);
}
{{{value_checks}}}
