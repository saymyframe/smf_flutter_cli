// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: its delegate notifies its
// listeners when the routes are refreshed, and when the location on top
// comes again with another extra, while the page on top stays as it is,
// which the listener of the fixture analytics does not hear of. The
// listeners of the screen under any router are tested in router_screens and
// layout_screens. It uses what the tests of router_screens share, which
// every app that it applies to has.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('a notification that leaves the page on top is not heard of',
      (tester) async {
    await startApp(tester);
    expect(heard(), [('fake_feature.home', '/fake_feature')]);
    final router = appRouter.config as GoRouter;
    // The notifications of the delegate, without which the steps below
    // would test nothing.
    var notified = 0;
    router.routerDelegate.addListener(() => notified++);

    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);
    // The test does not wait for push(), which a refresh can keep waiting
    // forever.
    unawaited(details(tester, 1).nav.fakeFeature.details(id: 2).push<void>());
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/2')]);

    // A refresh of the routes, with a pushed page on top, which stays.
    final pushed = details(tester, 2);
    notified = 0;
    router.refresh();
    await tester.pumpAndSettle();
    expect(notified, isPositive, reason: 'go_router notified.');
    expect(heard(), isEmpty);
    expect(pushed.mounted, isTrue, reason: 'The pushed page stayed.');

    // The location on top again with another extra, which leaves the page
    // on top as it is.
    Navigator.of(pushed).pop();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);
    final shown = details(tester, 1);
    notified = 0;
    router.go('/fake_feature/details/1', extra: 'other');
    await tester.pumpAndSettle();
    expect(notified, isPositive, reason: 'go_router notified.');
    expect(heard(), isEmpty);
    expect(shown.mounted, isTrue, reason: 'The page on top stayed.');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
