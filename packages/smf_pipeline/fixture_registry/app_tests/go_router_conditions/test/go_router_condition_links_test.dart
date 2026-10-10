// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router, the fixture gates and
// the second fixture feature: two links to routes that ask for a condition
// that arrive in one turn. go_router asks the guards about each in its
// redirect, which can only send it to another location: the router sends
// it to the screen that the app starts on and opens the target of the
// guard over that screen once the parse is over. The second link arrives
// before the router opened the target for the first, so the router opens
// it once, for the second, as a router does that takes the latest of two
// locations from the platform. It uses what the tests of router_screens,
// of router_guards and of the conditions share, which every app that it
// applies to has.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'two links to routes that ask for a condition, in one turn, open the '
    'flow of the guard once, and the later link shows once the condition '
    'holds',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );
      await toDetails(tester, 1);
      await takeBadge(tester);

      // Both links reach go_router before the router opens the target for
      // the first.
      final first = tester.binding.handlePushRoute(membersScreen.$2);
      final second = tester.binding.handlePushRoute(vaultScreen.$2);
      await first;
      await second;
      await tester.pumpAndSettle();
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureGateScreen],
        reason: 'Two links in one turn to routes that ask for a condition '
            'that does not hold open the target of the guard once, over the '
            'screen that the app starts on.',
      );
      expect(
        heard(),
        [gateScreen],
        reason: 'Two links in one turn to routes that ask for a condition '
            'that does not hold open the target of the guard once, of which '
            'alone the listeners of the screen hear.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [vaultScreen],
        reason: 'Once the condition holds, the router shows the later of '
            'two links that arrived in one turn.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureOutsideScreen, FixtureVaultScreen],
        reason: 'Once the condition holds, the router shows the later of '
            'two links that arrived in one turn as go() to it does: its '
            'chain in place of the stack.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
