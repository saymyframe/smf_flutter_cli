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
    final start = _guards.start;
    final guarded = _guards.asked(start?.routeName, start);
    if (guarded != null) _go(guarded.location);
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

  /// The pages that the user can get back to, the one on top first: those
  /// of the root navigator and, in place of the main navigation, those of
  /// its selected branch, or the fallback screen alone. A page is one that
  /// a push showed while its push waits for the value that it closes with.
  List<({String? route, AppLocation? location, bool pushed})> get _pages => [
        if (_stack.isEmpty) (route: null, location: null, pushed: false),
        for (final entry in _stack.reversed)
          for (final location in entry is AppLocation
              ? [entry]
              : _branches[_selected].reversed)
            (
              route: location.routeName,
              location: location,
              pushed: _results.containsKey(location),
            ),
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

  /// Shows what the guards show in place of [location], as [go] to it
  /// does; `false` if the guards let the user see [location].
  bool _redirected(AppLocation location) {
    final guarded = _guards.asked(location.routeName, location);
    if (guarded == null) return false;
    _go(guarded.location);
    return true;
  }

  /// Tells the guards of the pages of the router, as when one of them
  /// starts or stops allowing, and shows the location that they answer.
  void _guardsChanged() {
    final shown = _guards.changed(_pages);
    if (shown != null) _go(shown.location);
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

  /// Tells the router of a change of the stacks, as each navigation does.
  ///
  /// When the main navigation has left the stack, the branches get new
  /// navigators, with observers of their own, when they are selected next.
  /// The page of the main navigation that left stays in the tree until the
  /// transition to the page that took its place is over, with the
  /// navigators that it had: a main navigation that comes back sooner
  /// would have their keys in the tree twice.
  @override
  void notifyListeners() {
    if (!_stack.contains(_mainNavigation)) {
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
        if (_stack.isEmpty)
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
    {{#guards}}if (_redirected(location)) return;
    {{/guards}}_show(location);
    notifyListeners();
  }

  @override
  Future<T?> push<T extends Object?>(AppLocation location) {
    {{#guards}}if (_redirected(location)) return Future.value();
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
    {{#guards}}if (_redirected(location)) return;
    {{/guards}}final branch = _branchOf(location);
    _checkMainNavigation(location, branch, 'replace');
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
