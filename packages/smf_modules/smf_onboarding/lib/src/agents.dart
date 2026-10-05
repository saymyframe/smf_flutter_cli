import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the guide for coding agents
/// of the app.
const agentHeading = 'Onboarding';

/// The note of the module in the guide for coding agents: what shows the
/// onboarding, where its pages and its status are, how code finishes it
/// and starts it again, and what a test of another screen does about it.
///
/// What a router does with a guard of the routes is for the router role to
/// tell, in its own section of the guide, which every app with the module
/// has.
const agentNote = '''
- On the first launch, the guard `onboarding.firstRun` of `${RouterRole.routeGuards}` shows `OnboardingScreen` of `lib/features/onboarding/onboarding_screen.dart`, the route `onboarding.onboarding` at `/onboarding`, in place of every other screen. So no code navigates to the onboarding or away from it.
- The pages of the onboarding are the list that `onboardingPages()` returns in `lib/features/onboarding/onboarding_pages.dart`, in the order the user goes through them. To add or reorder a page, change that list. A page is any widget, and the screen keeps Skip, Next and Done below the pages.
- `onboardingStatus` in `lib/features/onboarding/onboarding_status.dart` has what the guard reads, and saves it in the preferences under `onboarding.completed`. Its `complete()`, which Skip and Done call, finishes the onboarding, and its `restart()` starts it again. Call `restart()` where the user asks to see the onboarding again, and do not navigate: the router shows the onboarding, and brings the user back to where they were once it is finished.
- In a test that starts the app to check another screen, call `onboardingStatus.complete()` before the app starts. It saves nothing then, and the app does not show the onboarding.
''';
