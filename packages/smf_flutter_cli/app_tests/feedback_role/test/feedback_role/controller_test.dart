// A test that continuous integration runs in the apps with the feedback
// role, whichever module provides it: appFeedback, over a service of the
// test that scripts what a provider answers. It asks the service only while
// the service has what it needs and the context is mounted, gives it the
// context below the root of the app that it got, which reaches the theme,
// the language and the navigator at the root of the app, completes with its
// answer, runs one call at a time, and reports an error of the service once,
// which counts as false. A service whose available throws counts as one
// without what it needs.
//
// It knows only the role, and starts the app once, since the start-up of an
// app may not run twice. Each expectation gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/feedback/app_feedback.dart';

import 'feedback_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'appFeedback asks the service only while it has what it needs and the '
    'context is mounted, gives it the context below the root of the app, '
    'completes with its answer, runs one call at a time, and reports an error '
    'of the service once',
    (tester) async {
      await startApp(tester);
      final provider = createFeedbackService();
      final scripted = ScriptedFeedback()..canWrite = false;
      appFeedback.use(scripted);
      addTearDown(() => appFeedback.use(provider));
      final context = await contextBelowRoot(tester);

      expect(
        appFeedback.available,
        isFalse,
        reason: 'appFeedback.available is what the service says.',
      );
      expect(
        await appFeedback.open(context),
        isFalse,
        reason: 'While the service has not what it needs, appFeedback.open '
            'completes with false.',
      );
      expect(
        scripted.contexts,
        isEmpty,
        reason: 'While the service has not what it needs, appFeedback asks '
            'it nothing.',
      );

      scripted.canWrite = true;
      expect(
        appFeedback.available,
        isTrue,
        reason: 'appFeedback.available is what the service says.',
      );
      expect(
        await appFeedback.open(context),
        isTrue,
        reason: 'appFeedback.open completes with the answer of the service.',
      );
      scripted.answer = false;
      expect(
        await appFeedback.open(context),
        isFalse,
        reason: 'appFeedback.open completes with the answer of the service.',
      );
      expect(
        scripted.contexts,
        [same(context), same(context)],
        reason: 'appFeedback gives the service the context that it got.',
      );
      final root = tester.element(find.byType(Navigator).first);
      for (final reached in scripted.reached) {
        expect(
          reached.theme,
          Theme.of(root),
          reason: 'The context below the root of the app has the theme of '
              'the app.',
        );
        expect(
          reached.locale,
          Localizations.localeOf(root),
          reason: 'The context below the root of the app has the language '
              'of the app.',
        );
        expect(
          reached.navigator,
          same(rootNavigatorOf(tester)),
          reason: 'The context below the root of the app reaches the '
              'navigator at the root of the app, over which a provider shows '
              'its way.',
        );
      }

      scripted
        ..answer = true
        ..hold();
      final first = appFeedback.open(context);
      // Within a bound, so that a second call that reaches the service fails
      // the expectations below rather than wait.
      final second = await answerWithin(tester, appFeedback.open(context));
      expect(
        second.answer,
        isFalse,
        reason: 'A call while another is on its way completes with false at '
            'once.',
      );
      expect(
        scripted.contexts,
        hasLength(3),
        reason: 'A call while another is on its way asks the service '
            'nothing.',
      );
      scripted.release(true);
      expect(
        await first,
        isTrue,
        reason: 'The call on its way completes with the answer of the '
            'service.',
      );
      expect(
        await appFeedback.open(context),
        isTrue,
        reason: 'Once the call on its way completed, the next call asks the '
            'service again.',
      );
      expect(scripted.contexts, hasLength(4));

      scripted.error = StateError('The service of the test broke.');
      bool? afterError;
      final errors = await errorsWhile(() async {
        afterError = await appFeedback.open(context);
      });
      expect(
        afterError,
        isFalse,
        reason: 'appFeedback.open never throws: an error of the service '
            'counts as false.',
      );
      expect(
        errors.flutter,
        ['Bad state: The service of the test broke.'],
        reason: 'appFeedback reports an error of the service once, to the '
            'handler of the errors of Flutter.',
      );
      expect(
        errors.platform,
        isEmpty,
        reason: 'appFeedback reports an error of the service to the handler '
            'of the errors of Flutter alone.',
      );
      scripted.error = null;
      expect(
        await appFeedback.open(context),
        isTrue,
        reason: 'A call that failed is over, so the next call asks the '
            'service again.',
      );

      scripted.availableError = StateError('The service cannot tell.');
      final asked = scripted.contexts.length;
      expect(
        appFeedback.available,
        isFalse,
        reason: 'A service whose available throws counts as one without what '
            'it needs.',
      );
      expect(
        await appFeedback.open(context),
        isFalse,
        reason: 'A service whose available throws counts as one without what '
            'it needs.',
      );
      expect(scripted.contexts, hasLength(asked));
      scripted.availableError = null;

      final gone = await contextBelowRoot(tester, name: 'gone');
      await closeTestPage(tester);
      expect(gone.mounted, isFalse, reason: 'The page of the test is closed.');
      expect(
        await appFeedback.open(gone),
        isFalse,
        reason: 'appFeedback.open completes with false for a context that is '
            'no longer mounted.',
      );
      expect(
        scripted.contexts,
        hasLength(asked),
        reason: 'appFeedback asks the service nothing for a context that is '
            'no longer mounted.',
      );
      await closeTestPage(tester);
    },
    timeout: timeout,
  );
}
