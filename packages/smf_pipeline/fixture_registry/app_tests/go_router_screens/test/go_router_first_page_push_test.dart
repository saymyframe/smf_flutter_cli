// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: push() of the navigation
// of the router role before go_router has a page, as the start-up of a
// module may make it. GoRouter.push has no page to push over then: the app
// would start on the pushed page alone, with no page below it, and the
// push would never complete. So the router of the module gives go_router
// the location as go() does: the app starts on it, with the pages of its
// chain below it, and the push completes with null at once. A router that
// always has a page never comes here. It uses what the tests of
// router_screens share, which every app that it applies to has.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
      'push() before go_router has a page starts the app on its location, '
      'as go() does, and completes with null', (tester) async {
    // Any context navigates: the router of the app is not below it.
    await tester.pumpWidget(const SizedBox());
    Object? pushed = 'not completed';
    unawaited(
      appRouter
          .navigatorOf(tester.element(find.byType(SizedBox)))
          .push<Object?>(const FakeFeatureDetailsLocation(id: 7))
          .then((value) => pushed = value),
    );
    await tester.pump();
    expect(
      pushed,
      isNull,
      reason: 'Before go_router has a page, it has none to push over: '
          'push() gives it the location as go() does, and completes with '
          'null.',
    );

    await startApp(tester);
    expect(
      heard(),
      [('fake_feature.details', '/fake_feature/details/7')],
      reason: 'The app starts on the location that push() asked for before '
          'go_router had a page, which is heard of once.',
    );
    expect(
      [
        find.byType(FixtureDetailsScreen).evaluate().length,
        find.byType(FixtureHomeScreen, skipOffstage: false).evaluate().length,
      ],
      [1, 1],
      reason: 'The app starts on the location that push() asked for before '
          'go_router had a page as go() to it shows it: with the page of '
          'its parent below it.',
    );
    expect(
      await tester.binding.handlePopRoute(),
      isTrue,
      reason: 'The back button of the system closes the page that the app '
          'started on, over the page of its parent.',
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(FixtureHomeScreen),
      findsOneWidget,
      reason: 'The back button of the system returns to the page of the '
          'parent of the location that the app started on.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
