// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: replace() of the
// navigation of the router role before go_router has a page, as the
// start-up of a module may make it. GoRouter.pushReplacement throws for
// want of a page to replace then, and the app would start with no page at
// all. So the router of the module gives go_router the location as go()
// does: the app starts on it, with the pages of its chain below it. A
// router that always has a page never comes here. It uses what the tests
// of router_screens share, which every app that it applies to has.
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
      'replace() before go_router has a page starts the app on its '
      'location, as go() does', (tester) async {
    // Any context navigates: the router of the app is not below it.
    await tester.pumpWidget(const SizedBox());
    appRouter
        .navigatorOf(tester.element(find.byType(SizedBox)))
        .replace(const FakeFeatureDetailsLocation(id: 7));
    await tester.pump();

    await startApp(tester);
    expect(
      tester.takeException(),
      isNull,
      reason: 'replace() before go_router has a page throws nothing.',
    );
    expect(
      heard(),
      [('fake_feature.details', '/fake_feature/details/7')],
      reason: 'The app starts on the location that replace() asked for '
          'before go_router had a page, which is heard of once.',
    );
    expect(
      [
        find.byType(FixtureDetailsScreen).evaluate().length,
        find.byType(FixtureHomeScreen, skipOffstage: false).evaluate().length,
      ],
      [1, 1],
      reason: 'The app starts on the location that replace() asked for '
          'before go_router had a page as go() to it shows it: with the '
          'page of its parent below it.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
