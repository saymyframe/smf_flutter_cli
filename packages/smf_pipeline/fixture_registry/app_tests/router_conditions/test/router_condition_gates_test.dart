// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates,
// the fixture late gate and the second fixture feature: a guard that
// stands for a condition next to the gates of the app, as
// RouterRole.guardedNavigation says. The third guard of the fixture gates
// stands for the condition of the fixture badge role, which three routes
// of the second fixture feature ask for, and shows the target of the first
// guard, a gate: the two have one flow. It does not bring the user back.
//
// The app starts with that gate closed and the condition not holding. The
// gate decides for every route, whether or not the route asks for the
// condition, also once the condition holds: its target takes the place of
// the stack, and the router remembers the location that was asked for.
// Once both allow, the router shows that location, and the flow is over.
// While only the condition does not hold, the flow is not over, and its
// target shows like any route. A gate of a later stage decides before the
// guard of the condition too. And when the guard of the condition stops
// allowing, the router forgets the location that a gate took the user
// from.
//
// A known limit, which the test pins: a location that asks for the
// condition and is asked for behind a gate is lost when the gate allows
// while the condition does not hold. The user comes to the screen that the
// app starts on, where the same request with no gate in its way opens the
// flow over the page. So two guards with one flow read one notifier, as
// the session of the fixture is for the first and the third guard: when
// both change in one turn, the location shows.
//
// A gate that stops allowing while the flow of the condition is open takes
// the place of the stack, the request with it, and brings the user back to
// the page that the flow was opened over, not to the location that it was
// opened for.
//
// Each expectation gives its reason, which a provider of the role with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a gate decides before a guard of a condition, the flow that the two '
    'have is over once both allow, and a guard of a condition that does not '
    'bring the user back makes the router forget where the user was',
    (tester) async {
      /// Navigates with [navigate] from the screen of the type [target],
      /// the target of a gate that does not allow, and checks that the
      /// target stays the screen the user sees: the router keeps its page,
      /// or shows it anew. A failure gives [reason].
      Future<void> staysOn(
        Type target,
        (String, String) screen,
        void Function(BuildContext context) navigate, {
        required String reason,
      }) async {
        final context = shown(tester, target);
        navigate(context);
        await tester.pumpAndSettle();
        expectHeardAtMostOnce(tester, context, screen, reason: reason);
        expect(builtScreens(tester), [target], reason: reason);
        expect(
          builtForHolders(tester),
          isEmpty,
          reason: 'The router builds no screen of a route that a gate keeps '
              'the user from.',
        );
      }

      // The gate does not allow, and the condition does not hold: the gate
      // decides, for a route that asks for the condition as for any other.
      fixtureGate.value = false;
      fixtureHolder.value = false;
      await startApp(tester);
      expect(
        heard(),
        [gateScreen],
        reason: 'The target of a gate that does not allow is heard of once, '
            'in place of the location that the app starts on.',
      );
      await staysOn(
        FixtureGateScreen,
        gateScreen,
        (gate) => gate.nav.fakeFeature.details(id: 1).go(),
        reason: 'While a gate does not allow, go() to a route that asks for '
            'no condition shows the target of the gate.',
      );
      await staysOn(
        FixtureGateScreen,
        gateScreen,
        (gate) => gate.nav.fakeSecond.members().go(),
        reason: 'While a gate does not allow, go() to a route that asks for '
            'a condition shows the target of the gate.',
      );

      // The condition holds first: the gate still keeps the user from what
      // was asked for.
      final waiting = shown(tester, FixtureGateScreen);
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'While a gate does not allow, the router stays in its flow '
            'when the condition of a guard with that flow comes to hold.',
      );
      expect(
        waiting.mounted,
        isTrue,
        reason: 'While a gate does not allow, the router stays in its flow '
            'when the condition of a guard with that flow comes to hold.',
      );

      // The gate allows too: the router shows what was asked for, and the
      // flow is over.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [membersScreen],
        reason: 'Once the gate and the condition allow, the router shows the '
            'latest location that was asked for.',
      );
      expect(
        builtForHolders(tester),
        [FixtureMembersScreen],
        reason: 'Once the gate and the condition allow, the router shows the '
            'latest location that was asked for.',
      );
      shown(tester, FixtureMembersScreen).nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once the gate and the condition with one flow both allow, '
            'the flow is over: go() to its target shows the screen that the '
            'app starts on.',
      );

      // The gate allows and the condition does not hold: the flow is not
      // over, so its target shows like any route, and the user leaves it
      // for a route that asks for no condition.
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A condition that stops holding leaves a page that does not '
            'ask for it as it is.',
      );
      shown(tester, FixtureHomeScreen).nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'While a condition does not hold, the flow of its guard is '
            'not over, though the gate with that flow allows: go() to its '
            'target shows it.',
      );
      shown(tester, FixtureGateScreen).nav.fakeFeature.home().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'While a condition does not hold, go() from the target of '
            'its guard to a route that asks for no condition shows the '
            'route.',
      );

      // The gate does not allow and the condition holds: the gate decides.
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A condition that comes to hold leaves a page that does not '
            'ask for it as it is, with nothing that was asked for.',
      );
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a gate stops allowing, the router shows its target, '
            'whatever the condition of a guard with the same flow says.',
      );
      await staysOn(
        FixtureGateScreen,
        gateScreen,
        (gate) => gate.nav.fakeSecond.memberCard().go(),
        reason: 'While a gate does not allow, go() to a route whose '
            'condition holds shows the target of the gate.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [memberCardScreen],
        reason: 'Once the gate allows, the router shows the location that '
            'was asked for, whose condition holds.',
      );
      expect(
        builtForHolders(tester),
        [FixtureMembersScreen, FixtureMemberCardScreen],
        reason: 'Once the gate allows, the router shows the location that '
            'was asked for, whose condition holds.',
      );

      // The guard of the condition does not bring the user back: when it
      // stops allowing while the flow of another gate is shown, the router
      // forgets the location that the gate took the user from.
      shown(tester, FixtureMemberCardScreen)
          .nav
          .fakeFeature
          .details(id: 5)
          .go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/5')],
        reason: 'With guards that allow, go() shows its location.',
      );
      fixtureSecondGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'When a gate stops allowing, the router shows its target.',
      );
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'While a gate does not allow, a guard of a condition that '
            'stops allowing leaves the flow of the gate as it is.',
      );
      fixtureSecondGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'When a guard of a condition that does not bring the user '
            'back stops allowing, the router forgets the location that '
            'another guard took the user from: once that guard allows, it '
            'shows the screen that the app starts on.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'When a guard of a condition that does not bring the user '
            'back stops allowing, the router forgets the location that '
            'another guard took the user from: once that guard allows, it '
            'shows the screen that the app starts on.',
      );

      // A gate of a later stage decides before the guard of the condition,
      // though that guard is of the first stage. Once the gate allows, the
      // condition still keeps the user from what was asked for: the flow of
      // the gate is over, and the user leaves it for the screen that the
      // app starts on. This is the known limit: the location is lost, and
      // the flow of the condition does not open.
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'When a gate stops allowing, the router shows its target.',
      );
      await staysOn(
        FixtureLateGateScreen,
        lateGateScreen,
        (gate) => gate.nav.fakeSecond.members().go(),
        reason: 'A gate that does not allow decides before a guard of a '
            'condition, of an earlier stage too: go() to a route whose '
            'condition does not hold shows the target of the gate.',
      );
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'KNOWN LIMIT: once a gate allows while a condition still '
            'keeps the user from the location that was asked for behind the '
            'gate, the router leaves the flow of the gate, which is over, '
            'for the screen that the app starts on.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen],
        reason: 'KNOWN LIMIT: a location that asks for a condition and was '
            'asked for behind a gate is lost once the gate allows: the flow '
            'of the condition does not open over the screen that the app '
            'starts on.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        isEmpty,
        reason: 'KNOWN LIMIT: a location that asks for a condition and was '
            'asked for behind a gate is lost once the gate allows: nothing '
            'happens when the condition comes to hold.',
      );
      await takeBadge(tester);

      // The user asks for a route whose condition does not hold, and moves
      // on from the target of its guard to another screen: the router
      // drops the request. So a gate that brings the user back takes them
      // from that screen and brings them back to it, and nothing happens
      // once the condition holds.
      shown(tester, FixtureHomeScreen).nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'go() to a route that asks for a condition that does not '
            'hold opens the target of the guard of the condition.',
      );
      shown(tester, FixtureGateScreen).nav.fakeFeature.details(id: 7).go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/7')],
        reason: 'While a condition does not hold, go() from the target of '
            'its guard to a route that asks for no condition shows the '
            'route.',
      );
      fixtureSecondGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'When a gate stops allowing, the router shows its target.',
      );
      fixtureSecondGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/7')],
        reason: 'Once a gate that brings the user back allows, the router '
            'shows the screen that the user moved on to from the target of '
            'a guard of a condition: the request that opened that flow was '
            'dropped, and does not stand in the way.',
      );
      final movedOn = details(tester, 7);
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'When a condition comes to hold after the user moved on '
            'from the target of its guard, the router leaves the user where '
            'they are.',
      );
      expect(
        movedOn.mounted,
        isTrue,
        reason: 'When a condition comes to hold after the user moved on '
            'from the target of its guard, the router leaves the user where '
            'they are.',
      );

      // Two guards with one flow over one notifier, as the gate and the
      // guard of an account of a sign-in: both stop allowing in one turn,
      // on a page that asks for the condition over a page that does not.
      // The gate decides, and brings the user back to the page below the
      // pushed one.
      var below = await toDetails(tester, 8);
      pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(heard(), [membersScreen], reason: 'push() shows its location.');
      fixtureSession.value = (app: false, holder: false);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a gate and a guard of a condition with one flow stop '
            'allowing in one turn, the gate decides: the router shows its '
            'target, once.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureGateScreen],
        reason: 'When a gate and a guard of a condition with one flow stop '
            'allowing in one turn, the target of the gate takes the place '
            'of the stack.',
      );
      fixtureSession.value = (app: true, holder: true);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [detailsScreen(8)],
        reason: 'Once a gate and a guard of a condition with one flow allow '
            'in one turn, the router shows the location below the pushed '
            'pages that the gate took the user from, once.',
      );
      expect(
        pagesBuilt(tester),
        pagesBelow,
        reason: 'Once a gate and a guard of a condition with one flow allow '
            'in one turn, the router shows the location below the pushed '
            'pages that the gate took the user from.',
      );

      // A location that asks for the condition, asked for behind the gate:
      // both allow in one turn, so the router shows it.
      fixtureSession.value = (app: false, holder: false);
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The gate shows its target.');
      await staysOn(
        FixtureGateScreen,
        gateScreen,
        (gate) => gate.nav.fakeSecond.memberCard().go(),
        reason: 'While a gate does not allow, go() to a route that asks for '
            'a condition shows the target of the gate.',
      );
      fixtureSession.value = (app: true, holder: true);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [memberCardScreen],
        reason: 'Once a gate and a guard of a condition with one flow allow '
            'in one turn, the router shows the location that was asked for '
            'behind the gate, though it asks for the condition.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureMembersScreen, FixtureMemberCardScreen],
        reason: 'Once a gate and a guard of a condition with one flow allow '
            'in one turn, the router shows the location that was asked for '
            'behind the gate, though it asks for the condition.',
      );

      // The same request when the two change apart, the gate first: the
      // known limit. The location is lost, and the user comes to the
      // screen that the app starts on.
      fixtureSession.value = (app: false, holder: false);
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The gate shows its target.');
      shown(tester, FixtureGateScreen).nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      heard();
      fixtureSession.value = (app: true, holder: false);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'KNOWN LIMIT: when the gate of a flow allows before the '
            'condition of the guard with that flow holds, a location that '
            'asks for the condition and was asked for behind the gate is '
            'lost: the user comes to the screen that the app starts on.',
      );
      fixtureSession.value = (app: true, holder: true);
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'KNOWN LIMIT: when the gate of a flow allows before the '
            'condition of the guard with that flow holds, a location that '
            'asks for the condition and was asked for behind the gate is '
            'lost: nothing happens once the condition holds.',
      );

      // The gate of the flow stops allowing while the flow of the
      // condition is open over a page: its target takes the place of the
      // stack, with nothing below it to go back to. That target is a page
      // of the flow, so the request still waits. It is dropped once the
      // gate brings the user back to the page that the flow was opened
      // over.
      below = await toDetails(tester, 9);
      await takeBadge(tester);
      var waits = pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'push() of a route that asks for a condition that does not '
            'hold opens the target of the guard of the condition.',
      );
      final open = shown(tester, FixtureGateScreen);
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        open,
        gateScreen,
        reason: 'When the gate of a flow stops allowing while the flow of a '
            'condition is open, its target is the screen that the user '
            'sees.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureGateScreen],
        reason: 'When the gate of a flow stops allowing while the flow of a '
            'condition is open, its target takes the place of the stack.',
      );
      expect(
        waits(),
        'not completed',
        reason: 'The request that opened the flow of a condition waits '
            'while a page of the flow is among the pages: the target of a '
            'gate with the same flow is one.',
      );
      final alone = shown(tester, FixtureGateScreen);
      await back(tester);
      expect(
        heard(),
        isEmpty,
        reason: 'The target of a gate that took the place of the stack has '
            'no page below it, so back leaves it where it is: a page that '
            'was open over another page before is alone now.',
      );
      expect(
        alone.mounted,
        isTrue,
        reason: 'The target of a gate that took the place of the stack has '
            'no page below it, so back leaves it where it is.',
      );
      fixtureHolder.value = true;
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [detailsScreen(9)],
        reason: 'Once the gate allows, the router shows the page that the '
            'flow of the condition was opened over, which the gate took the '
            'user from, not the location that the flow was opened for.',
      );
      expect(
        waits(),
        isNull,
        reason: 'The request that opened the flow of a condition is dropped '
            'once another location takes the place of the pages of the '
            'flow, as when a gate brings the user back.',
      );

      // A gate with another flow stops allowing while the flow of the
      // condition is open.
      await takeBadge(tester);
      waits = pushed(details(tester, 9).nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The flow opens over the page.');
      fixtureSecondGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'When a gate stops allowing while the flow of a condition '
            'is open, the router shows the target of the gate.',
      );
      expect(
        waits(),
        isNull,
        reason: 'The request that opened the flow of a condition is dropped '
            'when the target of a gate takes the place of the stack.',
      );
      fixtureSecondGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [detailsScreen(9)],
        reason: 'Once the gate allows, the router shows the page that the '
            'flow of the condition was opened over, which the gate took the '
            'user from.',
      );
      expect(
        pagesBuilt(tester),
        pagesBelow,
        reason: 'Once the gate allows, the router shows the page that the '
            'flow of the condition was opened over, without the flow.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
