// A test of what only bottom_tabs does, which continuous integration runs
// in the apps of the fixture modules with bottom_tabs and both fixture
// features: a tap on a tab of the bar at the bottom, found by the label of
// its destination, selects the destination, whose branch the router shows.
// The main navigation under any layout is tested in layout_screens, which
// selects a destination through the AppShell of the layout role. It uses
// what the tests of router_screens share, which every app that it applies
// to has.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_second_screen.dart';

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('a tap on a tab selects its destination', (tester) async {
    await startApp(tester);
    expect(find.byType(FixtureHomeScreen), findsOneWidget);
    expect(heard(), [('fake_feature.home', '/fake_feature')]);

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(find.byType(FixtureSecondScreen), findsOneWidget);
    expect(find.byType(FixtureHomeScreen), findsNothing);
    expect(heard(), [('fake_second.second', '/fake_second')]);

    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    expect(find.byType(FixtureHomeScreen), findsOneWidget);
    expect(find.byType(FixtureSecondScreen), findsNothing);
    expect(heard(), [('fake_feature.home', '/fake_feature')]);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
