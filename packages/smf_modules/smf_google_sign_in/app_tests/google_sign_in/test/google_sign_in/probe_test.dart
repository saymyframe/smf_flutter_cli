// A test that continuous integration runs in the apps with the
// google_sign_in module, whatever else they have: the probe of the module
// (integration_test/google_sign_in/probe.dart), which the start check runs
// on a device, finds nothing on Android, in an iOS app that is set up for
// Google sign-in and in one without an iOS client of Google, and tells of
// an app delegate that does not answer and of an app whose iOS client has
// no URL scheme or an empty id: the setups in which the Google Sign-In SDK
// would stop the app.
//
// It runs over the mocks of the module (google_sign_in_mocks.dart), whose
// app delegate answers for an app that is set up unless a test scripts
// another setup.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/google_sign_in/probe.dart';
import '../google_sign_in_mocks.dart';

/// What the probe finds on [platform] when the app delegate answers
/// [setup].
Future<List<String>> _probe(
  Map<String, Object?>? setup, {
  TargetPlatform platform = TargetPlatform.iOS,
}) async {
  googleSignIn.iosSetup = setup;
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await probeGoogleSignIn(() async {});
  } finally {
    debugDefaultTargetPlatformOverride = null;
    googleSignIn.iosSetup = googleTestIosSetup;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'the probe finds nothing on Android, in an iOS app that is set up for '
      'Google sign-in, and in one without an iOS client of Google', () async {
    final reads = googleSignIn.iosSetupReads;
    final onAndroid = await _probe(null, platform: TargetPlatform.android);
    final readsOnAndroid = googleSignIn.iosSetupReads - reads;

    expect(onAndroid, isEmpty);
    expect(readsOnAndroid, 0, reason: 'On Android it asks nothing.');
    expect(await _probe(googleTestIosSetup), isEmpty);
    expect(
      await _probe(const {
        'serviceInfo': true,
        'urlSchemes': <String>[],
      }),
      isEmpty,
      reason: 'An app whose Firebase project has no Google sign-in yet has '
          'no iOS client, and a sign-in there fails with notConfigured.',
    );
  });

  test(
      'the probe tells of an app delegate that does not answer, and of an '
      'iOS client of Google without its URL scheme or with an empty id',
      () async {
    expect(await _probe(null), [
      'Google sign-in fails on iOS whatever the setup: '
          'ios/Runner/AppDelegate.swift does not answer, or fails, on the method '
          'channel google_sign_in/ios_setup, through which the app learns whether the '
          'Google Sign-In SDK finds the iOS client of Google and its URL '
          'scheme.',
    ]);
    expect(
      await _probe(const {
        'serviceInfo': true,
        'serviceInfoClientId': googleTestIosClient,
        'urlSchemes': ['com.example.other'],
      }),
      [
        'The iOS app has an iOS client of Google, but Google sign-in fails '
            'with notConfigured: ios/Runner/Info.plist has no URL scheme '
            '$googleTestIosScheme, the reversed id of the iOS client of '
            'Google in CLIENT_ID of GoogleService-Info.plist, among '
            'CFBundleURLSchemes of CFBundleURLTypes: add it there.',
      ],
    );
    expect(
      await _probe(const {
        'serviceInfo': true,
        'serviceInfoClientId': '',
        'urlSchemes': <String>[],
      }),
      [
        'The iOS app has an iOS client of Google, but Google sign-in fails '
            'with notConfigured: the id of the iOS client of Google in '
            'CLIENT_ID of GoogleService-Info.plist is empty.',
      ],
    );
  });
}
