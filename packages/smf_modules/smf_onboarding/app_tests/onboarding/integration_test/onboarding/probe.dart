// The probe of the onboarding module, which the start check runs on a
// device once the first screen of the app settled. A device is the only
// place where the app starts with nothing saved in the preferences of a
// device, as on the first launch of a user, and where finishing the
// onboarding saves through the platform side of the preferences.
//
// It uses no test framework, and assumes nothing of the screen that the
// app shows or of the probes that ran before it: it reads what the
// preferences have saved and whether the onboarding is finished in the
// app, which must agree. If the onboarding is finished, the user has gone
// through it on this device before, or a test finished it before the app
// started, and the probe is done. If it is not, the probe goes to the route
// of the onboarding, which must show its screen, and finishes the
// onboarding as Done does: the preferences must have that saved, and the
// router must leave the screen. So it leaves the app with the onboarding
// finished, as a user does.
//
// The app may have a guard of the routes before that of the onboarding
// that does not allow on a device, such as one that asks for a signed-in
// user, which no check can open there. The router then shows the target of
// that guard in place of the route of the onboarding. So the probe asks
// redirectOf() of the router role about the route before it goes there, as
// the router does, and expects what it says: the screen of the onboarding,
// or none of it.
//
// The start check as a whole does not end that way. The walk of the
// routes, whose probe runs after this one, goes to the route of the
// onboarding last, as it does to every route in the flow of a guard. The
// screen is then shown although the onboarding is finished, so it starts
// the onboarding again, and the app has that saved when the check is over.
//
// The tests of the module run it too (onboarding/later_launch_test.dart).
import 'package:flutter/widgets.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_screen.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_status.dart';

/// The key of the preferences of the app under which the module saves that
/// the user has finished the onboarding.
const completedKey = 'onboarding.completed';

/// The probe of the start check: what is wrong with the onboarding of the
/// running app, whose screen [settle] waits for. See the top of the file.
Future<List<String>> probeOnboarding(Future<void> Function() settle) async {
  final saved = createAppPreferences().getBool(completedKey);
  final completed = onboardingStatus.completed.value;
  if (saved != null && saved != completed) {
    return [
      'The preferences have $saved saved under $completedKey, but in the app '
          'the onboarding is ${completed ? '' : 'not '}finished: the app did '
          'not restore what is saved.',
    ];
  }
  if (completed) return const [];

  final from = _innermostNavigator();
  if (from == null) {
    return const [
      'No navigator is on the screen to go to the onboarding from.',
    ];
  }
  final problems = <String>[];
  const location = OnboardingOnboardingLocation();
  // Whether a guard before that of the onboarding keeps the user from the
  // route of the onboarding, whose target the router then shows instead.
  final kept = redirectOf(location.routeName) != null;
  // From whichever screen the app shows: the route of the onboarding is the
  // one that its guard lets the user see.
  appRouter.navigatorOf(from.context).go(location);
  await settle();
  if (kept && _shows<OnboardingScreen>()) {
    problems.add(
      'A guard of the routes before that of the onboarding keeps the user '
      'from its route, but the route shows the screen of the onboarding.',
    );
  } else if (!kept && !_shows<OnboardingScreen>()) {
    problems.add(
      'While the onboarding is not finished, its route does not show its '
      'screen.',
    );
  }

  await onboardingStatus.complete();
  await settle();
  if (createAppPreferences().getBool(completedKey) != true) {
    problems.add(
      'Finishing the onboarding saved no true under $completedKey in the '
      'preferences, so the next launch of the app would show the onboarding '
      'again.',
    );
  }
  if (_shows<OnboardingScreen>()) {
    problems.add(
      'Once the onboarding is finished, the app still shows its screen: the '
      'router did not leave it.',
    );
  }
  return problems;
}

/// Whether a widget of the type [T] is on the screen.
bool _shows<T extends Widget>() {
  var shown = false;
  _visitOnScreen((element, depth) => shown = shown || element.widget is T);
  return shown;
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

/// Calls [visit] with each element on the screen, the onstage ones, and its
/// depth in the tree, parents first.
void _visitOnScreen(void Function(Element element, int depth) visit) {
  void walk(Element element, int depth) {
    visit(element, depth);
    element.debugVisitOnstageChildren((child) => walk(child, depth + 1));
  }

  if (WidgetsBinding.instance.rootElement case final root?) walk(root, 0);
}
