// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: a refresh of its routes
// shows the page on top again, which the listener of the fixture analytics
// does not hear of again. The listeners of the screen under any router are
// tested in router_screens and layout_screens. It uses what the tests of
// router_screens share, which every app that it applies to has.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('a refresh of the routes is not heard of', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1, tab: 'b')
        .go();
    await tester.pumpAndSettle();
    expect(heard(), [
      ('fake_feature.home', '/fake_feature'),
      ('fake_feature.details', '/fake_feature/details/1?tab=b'),
    ]);

    final shown = details(tester, 1);
    (appRouter.config as GoRouter).refresh();
    await tester.pumpAndSettle();
    expect(heard(), isEmpty);
    expect(shown.mounted, isTrue, reason: 'The page on top stayed.');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
