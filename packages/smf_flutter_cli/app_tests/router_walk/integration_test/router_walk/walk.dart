// The walk of the routes of an app with the router role, whichever module
// provides it: it goes to each location of the app that needs no values,
// with go() of the navigator of the role, and returns what is wrong on the
// screen, as text.
//
// The test of the router role that the CLI keeps runs it in flutter test
// (router_walk_test.dart), and a check that runs on a device can run it
// too: it uses no test framework, and takes the function that waits until
// the screen settles. The matrix writes locations.dart next to it, with the
// locations of the app from the data of its router role.
import 'package:flutter/widgets.dart';
import 'package:{{app_name}}/core/router/app_router.dart';

import 'locations.dart';

/// What the walk of the routes found wrong, as text, each problem as
/// `<route> (<path>): <problem>`.
final class WalkProblems {
  /// The locations after which the page on top of the innermost navigator
  /// on the screen, the one that shows the page the user sees, is not named
  /// after the route of the location, as the router role names the page of
  /// each route, or no navigator is on the screen.
  final List<String> pages = [];

  /// The locations after which the screen of their route is not shown.
  final List<String> screens = [];

  /// The locations after which an `ErrorWidget` is on the screen, or while
  /// going to which Flutter reported an error, `go()` threw one, or the
  /// screen did not settle.
  final List<String> errors = [];

  /// Every problem: those of [errors], [pages] and [screens].
  List<String> get all => [...errors, ...pages, ...screens];
}

/// The probe of the start check, which it runs on a device once the first
/// screen settled: walks the routes of the app with [settle] and returns
/// every problem; see [walkRoutes].
Future<List<String>> probeRoutes(Future<void> Function() settle) async =>
    (await walkRoutes(settle)).all;

/// Goes to each of [walkedLocations] with `go()` of the navigator of the
/// router of the app, from the navigator of the page that the user sees,
/// waits with [settle] until the screen settles, and returns what is wrong
/// after each; see [WalkProblems].
///
/// The errors that Flutter reports while it walks come to it; it puts back
/// the handler of the errors of Flutter that it found when it returns.
Future<WalkProblems> walkRoutes(Future<void> Function() settle) async {
  final problems = WalkProblems();
  final reported = <String>[];
  final onError = FlutterError.onError;
  FlutterError.onError =
      (details) => reported.add(_firstLine(details.exceptionAsString()));
  try {
    for (final walked in walkedLocations) {
      final label = '${walked.route} (${walked.location.path})';
      reported.clear();
      // Without a navigator on the screen to go from, what is on the
      // screen tells why, such as an ErrorWidget in place of the router.
      if (_innermostNavigator() case final from?) {
        try {
          appRouter.navigatorOf(from.context).go(walked.location);
          await settle();
        } on Object catch (error) {
          problems.errors.add('$label: ${_firstLine(error)}');
          continue;
        }
      }
      _checkScreen(walked, label, problems);
      problems.errors.addAll([
        for (final error in reported) '$label: Flutter reported $error',
      ]);
    }
  } finally {
    FlutterError.onError = onError;
  }
  return problems;
}

/// Adds to [problems] what is wrong on the screen for [walked], the
/// location that the walk went to, named [label].
void _checkScreen(
  WalkedLocation walked,
  String label,
  WalkProblems problems,
) {
  final navigator = _innermostNavigator();
  if (navigator == null) {
    problems.pages.add('$label: no navigator is on the screen');
  } else if (_topOf(navigator)?.settings.name case final name
      when name != walked.route) {
    problems.pages.add(
      '$label: the page on top of the innermost navigator on the screen is '
      '${name == null ? 'unnamed' : 'named $name'}',
    );
  }
  final shown = <Type>{};
  _visitOnScreen((element, depth) {
    final widget = element.widget;
    shown.add(widget.runtimeType);
    if (widget is ErrorWidget) {
      problems.errors.add(
        '$label: the screen shows an ErrorWidget: '
        '${_firstLine(widget.message)}',
      );
    }
  });
  if (!shown.contains(walked.screen)) {
    problems.screens.add(
      '$label: the screen ${walked.screen} of the route is not shown',
    );
  }
}

/// The navigator on the screen that is nested deepest, which shows the page
/// the user sees, or `null` if none is on the screen.
NavigatorState? _innermostNavigator() {
  NavigatorState? innermost;
  var deepest = -1;
  _visitOnScreen((element, depth) {
    if (element is StatefulElement &&
        element.state is NavigatorState &&
        depth > deepest) {
      innermost = element.state as NavigatorState;
      deepest = depth;
    }
  });
  return innermost;
}

/// The route on top of [navigator].
Route<Object?>? _topOf(NavigatorState navigator) {
  Route<Object?>? top;
  // The first route the predicate sees is the one on top, and taking it
  // pops nothing.
  navigator.popUntil((route) {
    top = route;
    return true;
  });
  return top;
}

/// Calls [visit] with each element on the screen, the onstage ones, and its
/// depth in the tree, parents first.
void _visitOnScreen(void Function(Element element, int depth) visit) {
  void walk(Element element, int depth) {
    visit(element, depth);
    element.debugVisitOnstageChildren((child) => walk(child, depth + 1));
  }

  if (WidgetsBinding.instance.rootElement case final root?) walk(root, 0);
}

/// The first line of the text of [error].
String _firstLine(Object error) => '$error'.trim().split('\n').first;
