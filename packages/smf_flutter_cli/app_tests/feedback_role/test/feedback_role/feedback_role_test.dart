// A test that continuous integration runs in the apps with the feedback
// role, whichever module provides it: the service of the provider, on the
// device of the mocks of the provider, which has what the provider opens and
// says no when it is asked whether it has it, as the role asks of the mocks
// of every provider. The provider has what it needs, and its open completes
// with true within two seconds of frames, without waiting for the user, with
// nothing for the handlers of the errors.
//
// It knows only the role, and starts the app once, since the start-up of an
// app may not run twice. Each expectation gives its reason, which a provider
// of the role with a known bug fails the test with (brokenProviders of the
// fixture registry). What reaches the developer goes through the tool of the
// provider, which this test does not see: the test of the module of the
// provider checks it.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/feedback/app_feedback.dart';

import 'feedback_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'open() of the provider opens its way on a device that has one, and '
    'completes with true',
    (tester) async {
      await startApp(tester);
      final service = createFeedbackService();
      expect(
        service.available,
        isTrue,
        reason: 'The test of the module of the provider gives it what it '
            'needs in the tests of every app, as the feedback role asks of '
            'the mocks of every provider.',
      );

      final context = await contextBelowRoot(tester);
      ({bool? answer, Object? error})? result;
      final errors = await errorsWhile(() async {
        result = await answerWithin(tester, service.open(context));
      });
      final (:answer, :error) = result!;
      expect(error, isNull, reason: 'open() of the provider never throws.');
      expect(
        answer,
        isNotNull,
        reason: 'open() of the provider completes within two seconds of '
            'frames, once its way opened, without waiting for the user.',
      );
      expect(
        answer,
        isTrue,
        reason: 'the provider did not open its way to write, though the '
            'device of the tests has one, as the mocks of every provider have '
            'it. A provider asks the platform nothing before it opens: asked '
            'whether it has that way, the device of the tests says no, as '
            'Android 11 and later say to an app whose manifest names no '
            'other app.',
      );
      expect(
        errors.flutter,
        isEmpty,
        reason: 'An open of the provider that succeeds reports no error.',
      );
      expect(
        errors.platform,
        isEmpty,
        reason: 'An open of the provider that succeeds leaves no error '
            'uncaught.',
      );
      await closeTestPage(tester);
    },
    timeout: timeout,
  );
}
