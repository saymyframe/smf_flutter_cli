// A test that continuous integration runs in the apps with the
// firebase_auth module, on the real Firebase packages, whose platform side
// is a backend in memory (firebase_auth_mocks.dart): the probe of the
// module (integration_test/firebase_auth/probe.dart), which the start check
// runs on a device, finds nothing while the session of the app and
// Firebase Authentication agree on who is signed in, and tells when they
// do not.
//
// The probe reads the session of the app, so the start-up of the app runs
// first, as on a device, with the mocks of the platform side of every
// module of the app, which the matrix sets up before the tests of each
// test file (flutter_test_config.dart). The mocks of a module of the app
// may sign a user up before the app starts, and the app may be in any mode
// of the auth role, so the test expects nothing of who is signed in: only
// that the session and Firebase agree. To make them disagree, it signs a
// user up through the plugin, behind the session, of which the backend in
// memory tells nobody.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';

import '../../integration_test/firebase_auth/probe.dart';
import 'service.dart';

/// Runs [action], which [what] names, in real time, as on a device, and
/// fails the test if it throws, which tester.runAsync would only report to
/// the handler of the errors of Flutter.
Future<void> _inRealTime(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the probe finds nothing while the session of the app has the user of '
    'Firebase Authentication, and tells when it has another',
    (tester) async {
      // The handlers of errors that the start-up installs, such as those of
      // crash reporting, go back to those of the test once it returns.
      final onError = FlutterError.onError;
      final onPlatformError = PlatformDispatcher.instance.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      try {
        await _inRealTime(tester, 'bootstrap()', bootstrap);
      } finally {
        FlutterError.onError = onError;
        PlatformDispatcher.instance.onError = onPlatformError;
        ErrorWidget.builder = errorWidgetBuilder;
      }
      late List<String> afterStart;
      late List<String> afterSignOut;
      late List<String> behindTheSession;
      late String ofSession;
      late String ofFirebase;
      late List<String> afterNextSignOut;

      await _inRealTime(tester, 'signing out and up', () async {
        afterStart = await probeFirebaseAuth(() async {});
        await appSession.signOut();
        afterSignOut = await probeFirebaseAuth(() async {});
        ofSession = switch (appSession.value) {
          SignedOutSession() => 'nobody',
          AnonymousSession(:final uid) => 'the anonymous user $uid',
          AccountSession(:final uid) => 'the account $uid',
        };
        final signedUp =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: addressOf('behind-the-session'),
          password: password,
        );
        ofFirebase = 'the account ${signedUp.user?.uid}';
        behindTheSession = await probeFirebaseAuth(() async {});
        await appSession.signOut();
        afterNextSignOut = await probeFirebaseAuth(() async {});
      });

      expect(
        [afterStart, afterSignOut, afterNextSignOut],
        everyElement(isEmpty),
        reason: 'The session of the app has the user of Firebase '
            'Authentication when the app has started, and after each of '
            'its calls: the probe finds nothing.',
      );
      expect(
        behindTheSession,
        [
          'The session of the app has $ofSession, and Firebase '
              'Authentication has $ofFirebase signed in on this device.',
        ],
        reason: 'The probe tells when the session of the app has another '
            'user than Firebase Authentication, each by its kind and its '
            'id.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
