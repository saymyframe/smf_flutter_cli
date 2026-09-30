// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it: the router creates
// its configuration, appRouter.config, once (RouterRole), so the root of the
// app and any code that reads it later share one router, whatever the user
// does. It starts the app with main() of lib/main.dart, which the app entry
// role puts into every app, and navigates only through the navigation
// facade of the router role and the navigators of Flutter. It uses what the
// tests of router_screens share. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with (brokenProviders
// of the fixture registry).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('the router creates its configuration once', (tester) async {
    await startApp(tester);
    final config = appRouter.config;
    expect(
      appRouter.config,
      same(config),
      reason: 'The router creates its config once.',
    );

    // Navigation, and the back button of the system, keep it.
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    unawaited(details(tester, 1).nav.fakeFeature.details(id: 2).push<void>());
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      appRouter.config,
      same(config),
      reason: 'The router creates its config once.',
    );

    // So does building every widget of the app again, the root of the app,
    // which takes the config, included.
    final reassembled = tester.binding.reassembleApplication();
    await tester.pumpAndSettle();
    await reassembled;
    expect(
      appRouter.config,
      same(config),
      reason: 'The router creates its config once.',
    );
    expect(
      tester.widget<WidgetsApp>(find.byType(WidgetsApp)).routerConfig,
      same(config),
      reason: 'The root of the app has the config of the router.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
