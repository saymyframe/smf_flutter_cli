import 'dart:async';

import 'package:flutter/material.dart';

import '../app/fallback_start_screen.dart';
import 'app_router.dart';
import 'navigation.dart';

/// Creates the router of the app: a plain navigator whose stack is a list
/// of locations (fixture).
AppRouter createAppRouter() => _FixtureRouter();

final class _FixtureRouter implements AppRouter {
  final _FixtureDelegate _delegate = _FixtureDelegate();

  @override
  late final RouterConfig<Object> config =
      RouterConfig(routerDelegate: _delegate);

  @override
  AppNavigator navigatorOf(BuildContext context) => _delegate;
}

final class _FixtureDelegate extends RouterDelegate<Object>
    with ChangeNotifier
    implements AppNavigator {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey();

  final List<NavigatorObserver> _observers = [
    for (final create in <NavigatorObserver Function()>[
{{{smf_router__observers}}}
    ])
      create(),
  ];

  final _screenListeners = <void Function(String? route, String location)>[
{{{smf_router__screen_listeners}}}
  ];

  final List<AppLocation> _stack = [{{{start}}}];

  final Map<AppLocation, Completer<Object?>> _results = {};

  /// The location on top, as the listeners of the screen last heard of it,
  /// or [_nothing] before the first screen.
  Object? _shown = _nothing;

  static const Object _nothing = Object();

  @override
  Widget build(BuildContext context) {
    _showScreen();
    return Navigator(
      key: _navigatorKey,
      observers: _observers,
      pages: [
        if (_stack.isEmpty)
          const MaterialPage<Object?>(child: FallbackStartScreen()),
        for (final location in _stack)
          MaterialPage<Object?>(
            key: ObjectKey(location),
            name: location.routeName,
            child: _screen(location),
          ),
      ],
      onDidRemovePage: (page) {
        final location = (page.key as ObjectKey?)?.value;
        if (location is AppLocation && _stack.remove(location)) {
          _results.remove(location)?.complete();
          notifyListeners();
        }
      },
    );
  }

  /// Tells the listeners of the screen about the page on top when it is
  /// another than they last heard of: the location on top of the stack, or
  /// the fallback screen at `/`.
  void _showScreen() {
    final top = _stack.lastOrNull;
    if (identical(top, _shown)) return;
    _shown = top;
    for (final listener in _screenListeners) {
      listener(top?.routeName, top?.path ?? '/');
    }
  }

  @override
  Future<bool> popRoute() async {
    if (_stack.length < 2) return false;
    final location = _stack.removeLast();
    _results.remove(location)?.complete();
    notifyListeners();
    return true;
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {}

  @override
  void go(AppLocation location) {
    _stack
      ..clear()
      ..addAll(location.chain);
    notifyListeners();
  }

  @override
  Future<T?> push<T extends Object?>(AppLocation location) {
    final result = Completer<Object?>();
    _results[location] = result;
    _stack.add(location);
    notifyListeners();
    return result.future.then((value) => value as T?);
  }

  @override
  void replace(AppLocation location) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _stack.add(location);
    notifyListeners();
  }
}

/// The screen of [location].
Widget _screen(AppLocation location) => {{{screen}}};
