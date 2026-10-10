import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/fallback_start_screen.dart';
import 'app_router.dart';
import 'navigation.dart';

/// Creates the router of the app: plain navigators whose stacks are lists
/// of locations (fixture).
AppRouter createAppRouter() => _FixtureRouter();

final class _FixtureRouter implements AppRouter {
  final _FixtureDelegate _delegate = _FixtureDelegate();

  /// The configuration of the router, which hears of the back button of
  /// the system too.
  @override
  late final RouterConfig<Object> config = RouterConfig(
    routerDelegate: _delegate,
    backButtonDispatcher: RootBackButtonDispatcher(),
  );

  @override
  AppNavigator navigatorOf(BuildContext context) => _delegate;
}

/// The locations of the destinations of the main navigation, in order, if
/// the app has a layout: each branch of the main navigation starts on one.
const List<AppLocation> _destinations = [{{{destinations}}}];

/// The main navigation, as an entry of the stack of the root navigator.
const _mainNavigation = _MainNavigation();

final class _MainNavigation {
  const _MainNavigation();
}

final class _FixtureDelegate extends RouterDelegate<Object>
    with ChangeNotifier
    implements AppNavigator {
  /// Creates the delegate, which shows the start route of the app, if it
  /// has one, and else the fallback screen.
  _FixtureDelegate() {
    for (final location in <AppLocation>[{{{start}}}]) {
      _show(location);
    }{{#guards}}
    // The guards are asked about the screen that the app starts on before
    // the router builds it, and told of its pages when one of them changes.
    // That screen asks for no condition, so they let the user see it or
    // answer the location to show in its place.
    final start = _guards.start;
    final guarded = _guards.asked(
      start?.routeName,
      start,
      onTopOf: const [],
    );
    if (guarded case ShowInstead(:final location)) _go(location);
    guardChanges.addListener(_guardsChanged);{{/guards}}
  }

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();

  final List<NavigatorObserver> _observers = _newObservers();

  final _screenListeners = <void Function(String? route, String location)>[
{{{smf_router__screen_listeners}}}
  ];

  /// The stack of the root navigator: locations, and the main navigation.
  final List<Object> _stack = [];

  /// The stack of each branch of the main navigation.
  final List<List<AppLocation>> _branches = [
    for (final destination in _destinations) [destination],
  ];

  /// The observers of the navigator of each branch that was selected.
  final Map<int, List<NavigatorObserver>> _branchObservers = {};

  /// The key of the navigator of each branch that was selected.
  final Map<int, GlobalKey<NavigatorState>> _branchNavigators = {};

  /// The branch of the main navigation that is selected.
  int _selected = 0;

  final Map<AppLocation, Completer<Object?>> _results = {};

  /// The page on top, as the listeners of the screen last heard of it, or
  /// `null` before the first screen; see [_top].
  (int, AppLocation?)? _shown;

{{#guards}}  /// The guards of the app as the router asks them, which keep the location
  /// that the user comes back to once they allow it. The router knows a
  /// location as an [AppLocation], and the fallback screen, which has none,
  /// as `null`: the screen that the app starts on is its start route, or
  /// the fallback screen.
  final GuardedNavigation<AppLocation?> _guards = GuardedNavigation(
    start: <AppLocation>[{{{start}}}].firstOrNull,
    locationOf: (location) => location,
  );

  /// The request that waits for a flow that the guards opened over the page
  /// on top, if there is one: the routes of the flow, how to make the
  /// request again, and how to end it without showing its location.
  ({Set<String> flow, void Function() again, void Function()? drop})? _waiting;

  /// The pages that the user can get back to, the one on top first: those
  /// of the root navigator and, in place of the main navigation, those of
  /// its selected branch, and the fallback screen where it is at the bottom.
  /// A page is one that a push showed while its push waits for the value
  /// that it closes with: the router can close it on its own. A page that
  /// [replace] shows in place of such a page is one too.
  List<({String? route, AppLocation? location, bool pushed})> get _pages => [
        for (final entry in _stack.reversed)
          for (final location in entry is AppLocation
              ? [entry]
              : _branches[_selected].reversed)
            (
              route: location.routeName,
              location: location,
              pushed: _results.containsKey(location),
            ),
        if (_overFallback) (route: null, location: null, pushed: false),
      ];

  /// Shows [location] in place of the whole stack and of the stacks of
  /// every branch of the main navigation, each of which is back on its
  /// destination; `null` is the fallback screen.
  void _go(AppLocation? location) {
    _stack.clear();
    for (final (index, branch) in _branches.indexed) {
      branch
        ..clear()
        ..add(_destinations[index]);
    }
    if (location != null) _show(location);
    notifyListeners();
  }

  /// What the guards answer for [location], which [go], [push] or [replace]
  /// is asked to show on top of the pages of the router.
  WhenAsked<AppLocation?>? _asked(AppLocation location) => _guards.asked(
        location.routeName,
        location,
        onTopOf: [for (final page in _pages) page.route],
      );

  /// Does what the guards answer for [location], which [go], [push] or
  /// [replace] is asked to show; `false` if they let the user see it.
  ///
  /// [again] makes the request again, and [drop] ends it without showing
  /// its location, as a push does that completes with `null`. For the flow
  /// of a guard that the guards open over the page on top, the request
  /// waits while a page of the flow is among the pages: [_close] makes it
  /// again, and [notifyListeners] drops it. The target of such a guard is
  /// outside the main navigation, so its page goes on the root navigator,
  /// as a page that a push showed.
  bool _redirected(
    AppLocation location, {
    required void Function() again,
    void Function()? drop,
  }) {
    switch (_asked(location)) {
      case null:
        return false;
      case ShowInstead(location: final shown):
        _go(shown);
        drop?.call();
      case ShowNothing():
        drop?.call();
      case ShowOver(location: final target, :final flow):
        _drop();
        _stack.add(target!);
        _results[target] = Completer<Object?>();
        _waiting = (flow: flow, again: again, drop: drop);
        notifyListeners();
    }
    return true;
  }

  /// Drops the request that waits, if there is one.
  void _drop() {
    final waiting = _waiting;
    _waiting = null;
    waiting?.drop?.call();
  }

  /// Tells the guards of the pages of the router, as when one of them
  /// starts or stops allowing, and does what they answer: shows a location
  /// in place of the stack, or closes the pages on top.
  void _guardsChanged() {
    switch (_guards.changed(_pages)) {
      case null:
        break;
      case ShowInstead(:final location):
        _go(location);
      case ClosePages(:final pages):
        _close(pages);
    }
  }

  /// Closes the [count] pages on top, each of which a push showed, whatever
  /// the navigator shows over them, and completes their pushes with `null`.
  /// Then it makes the request that waits again, if no page of its flow is
  /// left. The listeners of the screen hear of the page that the user ends
  /// on when the router next builds its pages.
  void _close(int count) {
    final waiting = _waiting;
    _waiting = null;
    for (var closed = 0; closed < count; closed++) {
      final stack = _onMainNavigation ? _branches[_selected] : _stack;
      _results.remove(stack.removeLast())?.complete(null);
    }
    if (waiting != null) {
      if (_pages.any((page) => waiting.flow.contains(page.route))) {
        _waiting = waiting;
      } else {
        waiting.again();
      }
    }
    notifyListeners();
  }

{{/guards}}  /// The page on top: the branch it is in, or -1 for the root navigator,
  /// and its location, or `null` for the fallback screen.
  (int, AppLocation?) get _top {
    final top = _stack.lastOrNull;
    if (top == null) return (-1, null);
    if (top case final AppLocation location) return (-1, location);
    return (_selected, _branches[_selected].last);
  }

  /// Whether the main navigation is on top of the root navigator.
  bool get _onMainNavigation =>
      _stack.isNotEmpty && identical(_stack.last, _mainNavigation);

  /// Whether the fallback screen is at the bottom of the root navigator:
  /// when the stack is empty, and below the pages that pushes showed over
  /// the fallback screen.
  bool get _overFallback => _stack.every(_results.containsKey);

  /// Tells the router of a change of the stacks, as each navigation does.
  ///
  /// When the main navigation has left the stack, the branches get new
  /// navigators, with observers of their own, when they are selected next.
  /// The page of the main navigation that left stays in the tree until the
  /// transition to the page that took its place is over, with the
  /// navigators that it had: a main navigation that comes back sooner
  /// would have their keys in the tree twice.{{#guards}}
  ///
  /// Before that, the request that waits for a flow is dropped once no
  /// page of the flow is among the pages, as when the user went back from
  /// it or another location took the place of the stack.{{/guards}}
  @override
  void notifyListeners() {
{{#guards}}    if (_waiting case final waiting?
        when !_pages.any((page) => waiting.flow.contains(page.route))) {
      _drop();
    }
{{/guards}}    if (!_stack.contains(_mainNavigation)) {
      _branchNavigators.clear();
      _branchObservers.clear();
    }
    super.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    _showScreen();
    return Navigator(
      key: _navigatorKey,
      observers: _observers,
      pages: [
        if (_overFallback)
          const MaterialPage<Object?>(child: FallbackStartScreen()),
        for (final entry in _stack)
          if (entry case final AppLocation location)
            _page(location)
          else
            MaterialPage<Object?>(
              key: ObjectKey(entry),
              child: _shell(_selected, _select, _branchesWidget()),
            ),
      ],
      onDidRemovePage: (page) => _removed(_stack, page),
    );
  }

  /// The navigators of the branches of the main navigation, of which the
  /// selected one shows: a branch gets its navigator when it is first
  /// selected, and keeps it until the main navigation leaves the stack; see
  /// [notifyListeners].
  Widget _branchesWidget() => IndexedStack(
        index: _selected,
        children: [
          for (final (index, stack) in _branches.indexed)
            if (index == _selected || _branchObservers.containsKey(index))
              Navigator(
                key: _branchNavigators.putIfAbsent(index, GlobalKey.new),
                observers: _branchObservers.putIfAbsent(index, _newObservers),
                pages: [for (final location in stack) _page(location)],
                onDidRemovePage: (page) => _removed(stack, page),
              )
            else
              const SizedBox.shrink(),
        ],
      );

  /// The page of [location], which completes the push of the location with
  /// the value it pops with.
  Page<Object?> _page(AppLocation location) => _LocationPage(
        location,
        (value) => _results.remove(location)?.complete(value),
      );

  /// Takes [page], which its navigator removed, such as when it popped, out
  /// of [stack].
  void _removed(List<Object> stack, Page<Object?> page) {
    if (stack.remove((page.key as ObjectKey?)?.value)) notifyListeners();
  }

  /// Selects the branch at [index], as the layout does when the user
  /// selects its destination.
  void _select(int index) {
    _selected = index;
    notifyListeners();
  }

  /// Tells the listeners of the screen about the page on top when it is
  /// another than they last heard of: a location of the root navigator or
  /// of the selected branch, or the fallback screen at `/`.
  ///
  /// It calls each listener on its own: what one throws keeps no other
  /// from hearing the screen, and reaches neither the router nor the
  /// handlers of the errors of the app. In debug mode it is printed.
  void _showScreen() {
    final top = _top;
    if (top == _shown) return;
    _shown = top;
    final (_, location) = top;
    for (final listener in _screenListeners) {
      try {
        listener(location?.routeName, location?.path ?? '/');
      } on Object catch (error) {
        if (kDebugMode) debugPrint('A listener of the screen failed: $error');
      }
    }
  }

  /// The branch of the main navigation of [location], or `null` if it is
  /// outside the main navigation.
  int? _branchOf(AppLocation location) {
    final name = location.chain.first.routeName;
    final index = _destinations.indexWhere(
      (destination) => destination.routeName == name,
    );
    return index < 0 ? null : index;
  }

  /// Makes the chain of [location] the stack: that of its branch, which
  /// the main navigation shows, if it is in the main navigation.
  void _show(AppLocation location) {
    _stack.clear();
    final branch = _branchOf(location);
    if (branch == null) {
      _stack.addAll(location.chain);
    } else {
      _showMainNavigation(branch, location);
    }
  }

  /// Puts the main navigation on top of the stack with the branch [branch]
  /// selected, whose stack becomes the chain of [location].
  void _showMainNavigation(int branch, AppLocation location) {
    _selected = branch;
    _branches[branch]
      ..clear()
      ..addAll(location.chain);
    _stack.add(_mainNavigation);
  }

  /// Throws a [StateError] instead of showing [location] of the branch
  /// [branch] of the main navigation on top of a page shown over the main
  /// navigation, as [method] would: a location in the main navigation goes
  /// only on top of the main navigation itself.
  void _checkMainNavigation(AppLocation location, int? branch, String method) {
    if (branch == null ||
        _onMainNavigation ||
        !_stack.contains(_mainNavigation)) {
      return;
    }
    throw StateError(
      'Cannot $method ${location.path}: it is in the main navigation, and a '
      'page is shown over the main navigation. Use go() to show it there.',
    );
  }

  /// Closes the route on top when the user presses the back button of the
  /// system, with [NavigatorState.maybePop] of the navigators that the user
  /// sees, the innermost first. A navigator tells [_removed] about a page
  /// that it closes.
  @override
  Future<bool> popRoute() async {
    for (final navigator in _shownNavigators()) {
      if (await navigator.maybePop()) return true;
    }
    return false;
  }

  /// The navigators that the user sees, the innermost first: that of the
  /// selected branch of the main navigation, unless a route of the root
  /// navigator, such as a dialog, covers the main navigation, and the root
  /// navigator.
  List<NavigatorState> _shownNavigators() {
    final branch = _branchNavigators[_selected]?.currentState;
    return [
      if (branch != null && (ModalRoute.of(branch.context)?.isCurrent ?? false))
        branch,
      ?_navigatorKey.currentState,
    ];
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {}

  @override
  void go(AppLocation location) {
    {{#guards}}if (_redirected(location, again: () => go(location))) return;
    {{/guards}}_show(location);
    notifyListeners();
  }

  @override
  Future<T?> push<T extends Object?>(AppLocation location) {
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
    {{/guards}}final branch = _branchOf(location);
    _checkMainNavigation(location, branch, 'push');
    if (branch == null) {
      _stack.add(location);
    } else if (_onMainNavigation) {
      _branches[_selected].add(location);
    } else {
      _showMainNavigation(branch, location);
    }
    final result = Completer<Object?>();
    _results[location] = result;
    notifyListeners();
    return result.future.then((value) => value as T?);
  }

  @override
  void replace(AppLocation location) {
    {{#guards}}if (_redirected(location, again: () => replace(location))) return;
    {{/guards}}final branch = _branchOf(location);
    _checkMainNavigation(location, branch, 'replace');
    // A page that takes the place of one that a push showed closes without
    // the pages below it too, so it is one that a push showed.
    final (_, replaced) = _top;
    if (branch != null && _onMainNavigation) {
      _branches[_selected]
        ..removeLast()
        ..add(location);
    } else {
      if (_stack.isNotEmpty) _stack.removeLast();
      if (branch == null) {
        _stack.add(location);
      } else {
        _showMainNavigation(branch, location);
      }
    }
    if (_results.containsKey(replaced)) {
      _results[location] = Completer<Object?>();
    }
    notifyListeners();
  }
}

/// The page of a location, whose route tells [onPopped] the value it pops
/// with.
final class _LocationPage extends MaterialPage<Object?> {
  _LocationPage(AppLocation location, this.onPopped)
      : super(
          key: ObjectKey(location),
          name: location.routeName,
          child: _screen(location),
        );

  final void Function(Object? value) onPopped;

  @override
  Route<Object?> createRoute(BuildContext context) {
    final route = super.createRoute(context);
    unawaited(route.popped.then(onPopped));
    return route;
  }
}

/// Creates the observers of a navigator. An observer can watch only one
/// navigator, so each navigator gets instances of its own.
List<NavigatorObserver> _newObservers() => [
      for (final create in <NavigatorObserver Function()>[
{{{smf_router__observers}}}
      ])
        create(),
    ];

/// The layout of the main navigation around [body], the navigator of the
/// selected branch, whose index is [index]; [onSelect] selects another.
Widget _shell(int index, ValueChanged<int> onSelect, Widget body) =>
    {{{shell}}};

/// The screen of [location].
Widget _screen(AppLocation location) => {{{screen}}};
