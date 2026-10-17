// What the tests of the onboarding screen role share, in the apps of the
// fixture modules whose modules give the role steps: the start of the app
// with main() of lib/main.dart, which the app entry role puts into every
// app, a new onboarding screen over the app, the pages of the screen, which
// turn with a swipe, and the steps of the fixture steps, whose actions note
// their calls.
//
// They know only the roles and the fixture steps. The matrix writes
// of_app.dart next to this file from the data of the onboarding screen role
// and of the localization role: the type of the screen of the route that
// the provider of the role names, a function that creates one, and the
// texts of the steps of the app in each of its languages. So the tests find
// a step by its texts, whichever module draws it, and push a new screen
// rather than go to the route of the screen, which a guard of its provider
// may keep the user from once the onboarding is over.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/onboarding/onboarding_steps.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'of_app.dart';

/// The index of the step `ask` of the fixture steps among the steps of the
/// app, [appSteps] and `appOnboardingSteps`, which have the same order: a
/// step with the button later and a function that says whether the
/// onboarding shows it, whose action waits for what a test holds it back
/// with and fails when a test says so.
final int ask = _indexOf('fake_steps.ask');

/// The index of the step `confirm` of the fixture steps, which comes right
/// after [ask]: a step without later, which the onboarding always shows.
final int confirm = _indexOf('fake_steps.confirm');

/// The index of the step [name] among the steps of the app; fails if the
/// app does not have it.
int _indexOf(String name) {
  final index = appSteps.indexWhere((step) => step.name == name);
  if (index < 0) fail('The app has no onboarding step $name.');
  return index;
}

/// The indices of the steps of the app that an onboarding screen that opens
/// now shows, in the order of the role: those whose showIf returns `true`,
/// and those without one. The step ask of the fixture steps is among them
/// unless a test says otherwise; whether the onboarding shows a step of
/// another module, such as one that asks for a permission, is up to that
/// module.
List<int> keptSteps() => [
      for (final (index, step) in appOnboardingSteps.indexed)
        if (step.showIf?.call() ?? true) index,
    ];

/// The most pages that the provider of the role may show besides the
/// steps, such as a first page and a last page of its own.
const int _otherPages = 6;

/// The onboarding screen that the user sees.
final Finder onboarding = find.byType(onboardingScreen);

/// What the onboarding screen shows of [matching].
Finder shown(Finder matching) =>
    find.descendant(of: onboarding, matching: matching);

/// The texts of the step at [index] among the steps of the app in
/// [language], a code of [stepLanguages].
StepTexts textsOf(int index, String language) =>
    appSteps[index].texts[language]!;

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as a timer or the platform side of a module,
/// does not keep the fake time of the test waiting forever. An error of
/// [action] fails the test, which tester.runAsync would only report to the
/// handler of the errors of Flutter.
Future<void> inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, as the start-up of a module may wait for a
/// timer or for input and output. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the
/// widget of an error go back to those of the test once main() returns, so
/// that flutter_test reports the errors of the frames that follow, and an
/// expectation that fails, as in any test.
Future<void> startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await inRealTime(tester, 'main()', app.main);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  await tester.pumpAndSettle();
}

/// Puts the app into [language], a code of [stepLanguages], in real time,
/// as on a device, so that a choice that the app saves does not wait for
/// the fake time of the test, and waits for the app to build in it.
Future<void> useLanguage(WidgetTester tester, String language) async {
  await inRealTime(
    tester,
    'the choice of $language',
    () => chooseLanguage(language),
  );
  await tester.pumpAndSettle();
}

/// The navigator at the root of the app, which shows its screens.
NavigatorState _rootNavigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// A context below the root of the app, which has the texts of the app.
BuildContext contextOfApp(WidgetTester tester) =>
    tester.element(find.byType(Navigator).first);

/// Shows a new onboarding screen over the app, on top of the navigator at
/// the root of the app, so that it has the theme and the texts of the app,
/// and waits for its first page. A new screen asks the steps again whether
/// it shows them. [closeScreen] closes it.
Future<void> showNewScreen(WidgetTester tester) async {
  unawaited(
    _rootNavigator(tester).push<void>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            newOnboardingScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    onboarding,
    findsOneWidget,
    reason: 'A new onboarding screen shows over the app.',
  );
}

/// Closes the screen that [showNewScreen] showed.
Future<void> closeScreen(WidgetTester tester) async {
  _rootNavigator(tester).pop();
  await tester.pumpAndSettle();
}

/// Whether [finder] finds a widget whose centre is on the onboarding
/// screen: on the page that the user sees, rather than on a page that is
/// built beside it.
bool isOnScreen(WidgetTester tester, Finder finder) {
  final screen = tester.getRect(onboarding);
  return finder.evaluate().any((element) => _isWithin(screen, element));
}

/// Whether the centre of [element] is within [screen].
bool _isWithin(Rect screen, Element element) => switch (element.renderObject) {
      final RenderBox box when box.hasSize => screen.contains(
          box.localToGlobal(box.size.center(Offset.zero)),
        ),
      _ => false,
    };

/// The elements of the texts that the onboarding screen shows on the page
/// that the user sees, and around it, such as a button below the pages.
/// A swipe that turns the page shows the texts of another page, which are
/// other elements, also when they say the same; a swipe that does not turn
/// it, as on the last page, leaves the same elements.
Set<Element> _textsOnScreen(WidgetTester tester) {
  final screen = tester.getRect(onboarding);
  return {
    for (final element in shown(find.byType(Text)).evaluate())
      if (_isWithin(screen, element)) element,
  };
}

/// The index of the step of the app whose title the page that the user
/// sees shows in [language], or `null` for a page that is no step.
int? stepShown(WidgetTester tester, String language) {
  for (final (index, step) in appSteps.indexed) {
    final title = shown(find.text(step.texts[language]!.title));
    if (isOnScreen(tester, title)) return index;
  }
  return null;
}

/// Shows the frames of [duration], one every 50 milliseconds, as a device
/// does: an animation that the screen starts, such as one that turns its
/// page, runs to its end if it is shorter, and one that does not end, such
/// as a spinner, does not keep the test waiting as pumpAndSettle would.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 50);
  for (var shown = Duration.zero; shown < duration; shown += frame) {
    await tester.pump(frame);
  }
}

/// Turns the page of the onboarding screen to the next one with a swipe,
/// as the user does, and waits for the page to settle.
Future<void> swipe(WidgetTester tester) async {
  final width = tester.getSize(onboarding).width;
  await tester.drag(onboarding, Offset(-width * 0.7, 0));
  await tester.pumpAndSettle();
}

/// Swipes from the page that the user sees until the step at [index] shows
/// in [language]; fails if no swipe gets there.
Future<void> swipeToStep(
  WidgetTester tester,
  int index,
  String language,
) async {
  for (var swipes = 0; swipes <= appSteps.length + _otherPages; swipes++) {
    if (stepShown(tester, language) == index) return;
    await swipe(tester);
  }
  fail(
    'No swipe shows the onboarding step ${appSteps[index].name}: the '
    'screen does not show its title in $language.',
  );
}

/// Swipes through every page of the onboarding screen from the page that
/// the user sees to the last one, and returns the index of the step that
/// each page shows, in the order of the pages, with `null` for a page that
/// is no step. The last page is the one that a swipe does not turn, which
/// shows the same texts before and after it. [onStep] runs on each page of
/// a step, while it shows. Fails if the screen has more pages than the
/// steps of the app and the pages that a provider may show besides them.
Future<List<int?>> swipeThrough(
  WidgetTester tester,
  String language, {
  void Function(int index)? onStep,
}) async {
  final pages = <int?>[];
  for (var swipes = 0; swipes <= appSteps.length + _otherPages; swipes++) {
    final step = stepShown(tester, language);
    pages.add(step);
    if (step != null) onStep?.call(step);
    final before = _textsOnScreen(tester);
    await swipe(tester);
    if (setEquals(before, _textsOnScreen(tester))) return pages;
  }
  fail(
    'The onboarding screen has more than $_otherPages pages besides its '
    'steps: a swipe still turns the page after ${pages.length} pages.',
  );
}
