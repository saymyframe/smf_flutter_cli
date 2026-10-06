// What the tests that continuous integration runs in an app with the
// onboarding module need of the module, whichever module they test: the
// guard of the routes of the onboarding lets them through. Without it, an
// app that a test starts shows the onboarding, as on its first launch, in
// place of the screen that the test expects. The matrix sets it up before
// the tests of every module of such an app (MatrixAppTest.mocks).
//
// The tests of the onboarding itself start the app as its first launch
// finds it, so they tell the mocks to leave the onboarding alone
// (onboardingIsUnderTest).
import 'dart:async';

import 'package:{{app_name}}/features/onboarding/onboarding_status.dart';

/// Whether [finishOnboarding] leaves the onboarding as the app has it when
/// it starts: not finished, unless the preferences have it saved.
///
/// A test file of the onboarding sets it while its main() declares its
/// tests, which is before the matrix sets up the mocks of the app for them.
bool onboardingIsUnderTest = false;

/// Finishes the onboarding before the app starts, as the user does with
/// the button of its last page, unless the test file is one of the
/// onboarding itself.
///
/// The preferences of the app are not open yet, so this changes only
/// memory and saves nothing, whichever module provides the preferences.
/// The start-up of the app then finds nothing saved, and the restorer of
/// the module keeps what memory has: the app starts on its start screen.
void finishOnboarding() {
  if (!onboardingIsUnderTest) unawaited(onboardingStatus.complete());
}
