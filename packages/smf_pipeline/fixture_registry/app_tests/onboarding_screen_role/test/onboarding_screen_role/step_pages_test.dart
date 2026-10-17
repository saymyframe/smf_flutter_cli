// A test that continuous integration runs in the apps of the fixture
// modules whose modules give the onboarding screen role steps, whichever
// module provides the role: each label of a step in the list that the
// template of the role generates returns the text of its contributor in the
// language of the app, and the onboarding screen shows each step on a page
// of its own, in the order of the role, with no other page between two
// steps: its icon, its title as a header for a screen reader, its text, the
// button of its action and, if it has one, that of later. The labels follow
// the language of the app while a step shows (OnboardingScreenRole).
//
// It uses what the tests of the role share (steps.dart), and the texts that
// the matrix writes for each step in each language of the app. The app
// starts once, since the start-up of an app runs once in a test file. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/onboarding/onboarding_steps.dart';

import 'of_app.dart';
import 'steps.dart';

/// Checks that the page that the user sees shows the step at [index] in
/// [language]: its icon, its title as a header for a screen reader, its
/// text and the labels of its buttons.
void _expectStep(WidgetTester tester, int index, String language) {
  final step = appOnboardingSteps[index];
  final texts = textsOf(index, language);
  final name = '${appSteps[index].name} in $language';
  expect(
    isOnScreen(tester, shown(find.byIcon(step.icon))),
    isTrue,
    reason: 'The page of a step shows the icon of the step: $name.',
  );
  expect(
    tester.getSemantics(shown(find.text(texts.title))),
    isSemantics(label: texts.title, isHeader: true),
    reason: 'A screen reader announces the title of a step as a header: '
        '$name.',
  );
  for (final (what, text) in [
    ('the text', texts.text),
    ('the label of the action', texts.action),
    if (texts.later case final later?) ('the label of later', later),
  ]) {
    expect(
      isOnScreen(tester, shown(find.text(text))),
      isTrue,
      reason: 'The page of a step shows $what of the step: $name.',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'each step shows on a page of its own, in the order of the role, with '
    'its icon, its title as a header, its text and its buttons, in each '
    'language of the app',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await startApp(tester);
        expect(
          appOnboardingSteps,
          hasLength(appSteps.length),
          reason: 'The list of the steps of the app has each step of the '
              'role.',
        );
        for (final language in stepLanguages) {
          await useLanguage(tester, language);
          final context = contextOfApp(tester);
          for (final (index, step) in appOnboardingSteps.indexed) {
            final texts = textsOf(index, language);
            expect(
              (
                title: step.title(context),
                text: step.text(context),
                action: step.action(context),
                later: step.later?.call(context),
              ),
              texts,
              reason: 'Each label of a step returns the text of its '
                  'contributor in the language of the app, or its English '
                  'text where it has no translation into it: '
                  '${appSteps[index].name} in $language.',
            );
          }

          await showNewScreen(tester);
          final pages = await swipeThrough(
            tester,
            language,
            onStep: (index) => _expectStep(tester, index, language),
          );
          final steps = pages.whereType<int>().toList();
          expect(
            steps,
            [for (var index = 0; index < appSteps.length; index++) index],
            reason: 'The onboarding shows each step whose showIf keeps it on '
                'a page of its own, in the order of the role ($language).',
          );
          expect(
            pages.sublist(
                pages.indexOf(steps.first), pages.indexOf(steps.last)),
            everyElement(isNotNull),
            reason: 'The onboarding shows no other page between two steps '
                '($language).',
          );
          await closeScreen(tester);
        }

        // The labels follow a language that the app takes while a step
        // shows.
        await useLanguage(tester, stepLanguages.first);
        await showNewScreen(tester);
        await swipeToStep(tester, ask, stepLanguages.first);
        final other = stepLanguages.last;
        await useLanguage(tester, other);
        expect(
          stepShown(tester, other),
          ask,
          reason: 'The title of the step that shows follows the language of '
              'the app.',
        );
        _expectStep(tester, ask, other);
      } finally {
        semantics.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
