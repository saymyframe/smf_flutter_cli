// A test that continuous integration runs in the apps with the
// google_sign_in module, whatever else they have: on iOS, googleCredential()
// asks the app delegate what the Google Sign-In SDK finds of the setup of
// the app, through the method channel google_sign_in/ios_setup, before it
// asks the SDK. The SDK stops the app without an iOS client of Google, with
// an empty one, or without the URL scheme of that client, and the package
// does not catch that. So in each of those, and when the app delegate does
// not answer, the call fails with notConfigured and asks Google nothing.
//
// It runs on the real google_sign_in package and the real method channel,
// over the mocks of the module (google_sign_in_mocks.dart), whose app
// delegate answers for an app that is set up unless a test scripts another
// setup.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/google_sign_in/google_sign_in.dart';

import '../google_sign_in_mocks.dart';

/// The id of another iOS client of Google.
const _otherClient = 'another-client.apps.googleusercontent.com';

/// What a sign-in on [platform] ends with when the app delegate answers
/// [setup]: the reason and the hint of its failure, or `credential` for a
/// credential, and how many sign-ins reached Google.
Future<(String, int)> _signIn(
  Map<String, Object?>? setup, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  googleSignIn.iosSetup = setup;
  debugDefaultTargetPlatformOverride = platform;
  final signIns = googleSignIn.signIns;
  try {
    await googleCredential();
    return ('credential', googleSignIn.signIns - signIns);
  } on AuthFailure catch (failure) {
    return (
      'failed: ${failure.reason.name}: ${failure.developerHint}',
      googleSignIn.signIns - signIns,
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
    googleSignIn.iosSetup = googleTestIosSetup;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A test fails after ten minutes by default; a test that hangs fails
  // sooner.
  const timeout = Timeout(Duration(minutes: 2));

  test(
    'on iOS, a sign-in in an app with an iOS client of Google but without '
    'its URL scheme fails with notConfigured, with a hint that names the '
    'scheme, and asks Google nothing: the Google Sign-In SDK would stop the '
    'app',
    () async {
      final (outcome, signIns) = await _signIn(const {
        'serviceInfo': true,
        'serviceInfoClientId': googleTestIosClient,
        'urlSchemes': <String>[],
      });

      expect(
        outcome,
        allOf(
          startsWith('failed: notConfigured: '),
          contains('ios/Runner/Info.plist has no URL scheme '
              '$googleTestIosScheme'),
          contains('CLIENT_ID of GoogleService-Info.plist'),
          contains('See the section "Google sign-in" of the README'),
        ),
        reason: 'The Google Sign-In SDK stops an iOS app without the URL '
            'scheme of its iOS client, and google_sign_in does not catch '
            'that, so the app does not ask the SDK.',
      );
      expect(signIns, 0, reason: 'The call asks Google nothing.');
    },
    timeout: timeout,
  );

  test(
    'on iOS, a sign-in fails with notConfigured and asks Google nothing '
    'without an iOS client of Google, with an empty one, without its URL '
    'scheme, and when the app delegate does not answer; a scheme in upper '
    'case passes, and CLIENT_ID of GoogleService-Info.plist comes before '
    'GIDClientID of Info.plist',
    () async {
      final outcomes = <String, (String, int)>{};
      for (final (name, setup) in <(String, Map<String, Object?>?)>[
        ('set up', googleTestIosSetup),
        (
          'no CLIENT_ID in GoogleService-Info.plist',
          const {
            'serviceInfo': true,
            'urlSchemes': [googleTestIosScheme],
          },
        ),
        (
          'no GoogleService-Info.plist',
          const {
            'serviceInfo': false,
            'urlSchemes': <String>[],
          },
        ),
        (
          'an empty CLIENT_ID',
          const {
            'serviceInfo': true,
            'serviceInfoClientId': '',
            'urlSchemes': [googleTestIosScheme],
          },
        ),
        (
          'GIDClientID alone without its scheme',
          const {
            'serviceInfo': false,
            'infoPlistClientId': googleTestIosClient,
            'urlSchemes': <String>[],
          },
        ),
        (
          'GIDClientID alone with its scheme',
          const {
            'serviceInfo': false,
            'infoPlistClientId': googleTestIosClient,
            'urlSchemes': [googleTestIosScheme],
          },
        ),
        (
          'CLIENT_ID over a GIDClientID whose scheme is there',
          const {
            'serviceInfo': true,
            'serviceInfoClientId': _otherClient,
            'infoPlistClientId': googleTestIosClient,
            'urlSchemes': [googleTestIosScheme],
          },
        ),
        (
          'its scheme in upper case',
          {
            'serviceInfo': true,
            'serviceInfoClientId': googleTestIosClient,
            'urlSchemes': [googleTestIosScheme.toUpperCase()],
          },
        ),
        ('no answer of the app delegate', null),
      ]) {
        final (outcome, signIns) = await _signIn(setup);
        // The reason, and the problem that the hint names before its cause.
        outcomes[name] = (outcome.split(').').first, signIns);
      }

      const notConfigured = 'failed: notConfigured: Google sign-in is not '
          'set up for the app (';
      expect(
        outcomes,
        {
          'set up': ('credential', 1),
          'no CLIENT_ID in GoogleService-Info.plist': (
            '${notConfigured}the iOS app has no iOS client of Google: '
                'GoogleService-Info.plist has no CLIENT_ID, and '
                'ios/Runner/Info.plist has no GIDClientID',
            0,
          ),
          'no GoogleService-Info.plist': (
            '${notConfigured}the iOS app has no iOS client of Google: the '
                'app has no GoogleService-Info.plist, and '
                'ios/Runner/Info.plist has no GIDClientID',
            0,
          ),
          'an empty CLIENT_ID': (
            '${notConfigured}the id of the iOS client of Google in CLIENT_ID '
                'of GoogleService-Info.plist is empty',
            0,
          ),
          'GIDClientID alone without its scheme': (
            '${notConfigured}ios/Runner/Info.plist has no URL scheme '
                '$googleTestIosScheme, the reversed id of the iOS client of '
                'Google in GIDClientID of ios/Runner/Info.plist, among '
                'CFBundleURLSchemes of CFBundleURLTypes: add it there',
            0,
          ),
          'GIDClientID alone with its scheme': ('credential', 1),
          'CLIENT_ID over a GIDClientID whose scheme is there': (
            '${notConfigured}ios/Runner/Info.plist has no URL scheme '
                'com.googleusercontent.apps.another-client, the reversed id '
                'of the iOS client of Google in CLIENT_ID of '
                'GoogleService-Info.plist, among CFBundleURLSchemes of '
                'CFBundleURLTypes: add it there',
            0,
          ),
          'its scheme in upper case': ('credential', 1),
          'no answer of the app delegate': (
            '${notConfigured}ios/Runner/AppDelegate.swift does not answer the '
                'method channel google_sign_in/ios_setup, through which the '
                'app learns whether the Google Sign-In SDK finds the iOS '
                'client of Google and its URL scheme',
            0,
          ),
        },
        reason: 'The app takes the iOS client of Google where the Google '
            'Sign-In SDK does, and compares the schemes in lower case as it '
            'does. An app delegate that does not answer leaves the app '
            'unable to tell, so the call fails rather than let the SDK stop '
            'the app.',
      );
    },
    timeout: timeout,
  );

  test(
    'on Android, a sign-in asks the app delegate of iOS nothing and asks '
    'Google',
    () async {
      final reads = googleSignIn.iosSetupReads;
      final (outcome, signIns) =
          await _signIn(null, platform: TargetPlatform.android);

      expect((outcome, signIns), ('credential', 1));
      expect(googleSignIn.iosSetupReads, reads);
    },
    timeout: timeout,
  );
}
