// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: push() of the navigation
// facade completes with the value that its page returns when it closes, even
// after a refresh of the routes, such as when the refreshListenable of
// go_router notifies. A refresh decodes the stacks of go_router anew and
// gives each pushed page a new completer
// (https://github.com/flutter/flutter/issues/128122), whose value the router
// of the module passes on to the push. The pages go on top of the stack of
// the start screen, in its branch of the main navigation when the app has
// one. It uses what the tests of router_screens share, which every app that
// it applies to has.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'screens.dart';

/// The router of the app.
GoRouter get _router => appRouter.config as GoRouter;

/// Pushes [link] and returns what the push has completed with so far:
/// `'not completed'` until it completes. The test does not wait for push(),
/// which could keep it waiting forever.
Object? Function() _push(NavLink link) {
  Object? result = 'not completed';
  unawaited(link.push<Object?>().then((value) => result = value));
  return () => result;
}

/// Refreshes the routes, as go_router does when its refreshListenable
/// notifies.
Future<void> _refresh(WidgetTester tester) async {
  _router.refresh();
  await tester.pumpAndSettle();
}

/// Closes the details of the item [id], which are on top, with [value].
Future<void> _close(WidgetTester tester, int id, Object? value) async {
  Navigator.of(details(tester, id)).pop(value);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('push() completes with the value of its page after a refresh',
      (tester) async {
    // The app starts as on a device, with what its main() puts around it.
    // runAsync reports an error of main() to Flutter rather than throwing
    // it, so the test fails on it here.
    await tester.runAsync(app.main);
    final error = tester.takeException();
    if (error != null) fail('main() of the app failed: $error');
    await tester.pumpAndSettle();
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();

    // A page that a refresh shows anew.
    final pushed = _push(details(tester, 1).nav.fakeFeature.details(id: 2));
    await tester.pumpAndSettle();
    await _refresh(tester);
    await _close(tester, 2, 'closed');
    expect(pushed(), 'closed');

    // A page pushed after a refresh, on top of a page that the refresh
    // showed anew, and a second refresh of both. Each push completes when
    // its own page closes, the one on top without a value, as the back
    // button of the system closes it.
    final below = _push(details(tester, 1).nav.fakeFeature.details(id: 3));
    await tester.pumpAndSettle();
    await _refresh(tester);
    final above = _push(details(tester, 3).nav.fakeFeature.details(id: 4));
    await tester.pumpAndSettle();
    await _refresh(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(above(), isNull);
    expect(below(), 'not completed', reason: 'Its page is still shown.');
    await _close(tester, 3, 'below');
    expect(below(), 'below');

    // The main navigation, when the app has one: a page on top of the stack
    // of a branch, which a refresh shows anew, and again once another
    // branch was selected, refreshed and left, as the branch keeps its
    // stack.
    final shells = _router.configuration.routes.whereType<StatefulShellRoute>();
    if (shells.isNotEmpty) {
      StatefulNavigationShell shell() =>
          tester.widget(find.byType(StatefulNavigationShell));
      final branch = shell().currentIndex;
      final other = (branch + 1) % shell().route.branches.length;
      expect(other, isNot(branch), reason: 'Another branch to select.');
      final inBranch = _push(details(tester, 1).nav.fakeFeature.details(id: 5));
      await tester.pumpAndSettle();
      await _refresh(tester);
      shell().goBranch(other);
      await tester.pumpAndSettle();
      await _refresh(tester);
      shell().goBranch(branch);
      await tester.pumpAndSettle();
      await _refresh(tester);
      await _close(tester, 5, 'in branch');
      expect(inBranch(), 'in branch');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
