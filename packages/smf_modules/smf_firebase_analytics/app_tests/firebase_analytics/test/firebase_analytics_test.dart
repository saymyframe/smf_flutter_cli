// A test that continuous integration runs in the apps with Firebase
// Analytics, on the real Firebase packages, whose platform side answers
// without a Firebase project: what the analytics service of the module,
// which createFirebaseAnalyticsService() creates, records reaches Firebase
// Analytics, and creating it sends nothing, so the setting of collection
// that Firebase Analytics keeps on the device holds. It also reads the
// native projects of the app as smf create left them: an app that collects
// nothing before its code chose turns the collection of Firebase Analytics
// off by default there, since Firebase Analytics starts before any Dart
// code runs.
//
// The app may have other analytics services, which only the tests of their
// own modules know, so the test uses the service of the module rather than
// createAnalyticsService(), which forwards to all of them. It initializes
// Firebase as the start-up of the app does, and runs none of the rest of
// the start-up. The options of Firebase come with the tests of
// firebase_core, which every app with Firebase Analytics has, and the
// matrix sets up the mocks of the platform side of every module of the app
// before the tests, those of Firebase Analytics among them, which record
// what reaches it (firebase_analytics_mocks.dart).
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:{{app_name}}/core/analytics/firebase_analytics_service.dart';
import 'package:{{app_name}}/firebase_options_of_flavor.dart';

import 'firebase_analytics_mocks.dart';

/// Whether the app collects analytics from its first start, as the
/// analytics role chose: `--analytics-collection` of `smf create`.
final bool _collectedFromFirstStart =
    bool.parse('{{collected_from_first_start}}');

const _manifest = '{{android_manifest}}';
const _infoPlist = '{{info_plist}}';

/// The values of the meta-data [name] of the application in the manifest of
/// Android.
List<String?> _metaData(String name) => [
      for (final element
          in XmlDocument.parse(File(_manifest).readAsStringSync())
              .rootElement
              .findElements('application')
              .single
              .findElements('meta-data'))
        if (element.getAttribute('android:name') == name)
          element.getAttribute('android:value'),
    ];

/// The elements of the values of the key [name] of Info.plist.
List<String> _plistValues(String name) {
  final entries = XmlDocument.parse(File(_infoPlist).readAsStringSync())
      .rootElement
      .findElements('dict')
      .single
      .childElements
      .toList();
  return [
    for (var index = 0; index + 1 < entries.length; index++)
      if (entries[index].name.local == 'key' &&
          entries[index].innerText == name)
        entries[index + 1].name.local,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: firebaseOptionsOfFlavor);
  });

  setUp(analyticsCalls.clear);

  test('the analytics service of the module reaches Firebase Analytics',
      () async {
    final analytics = createFirebaseAnalyticsService();

    await analytics.logEvent('smf_test', parameters: {'count': 1});
    await analytics.logSignIn(method: 'email');
    await analytics.logSignUp(method: 'email');
    await analytics.setUserId('user-1');
    await analytics.setUserProperty(name: 'plan', value: 'free');
    await analytics.setAnalyticsCollectionEnabled(false);

    expect(analyticsCalls, [
      [
        'logEvent',
        {
          'eventName': 'smf_test',
          'parameters': {'count': 1},
        },
      ],
      [
        'logEvent',
        {
          'eventName': 'login',
          'parameters': {'method': 'email'},
        },
      ],
      [
        'logEvent',
        {
          'eventName': 'sign_up',
          'parameters': {'method': 'email'},
        },
      ],
      ['setUserId', 'user-1'],
      ['setUserProperty', 'plan', 'free'],
      ['setAnalyticsCollectionEnabled', false],
    ]);
  });

  test(
      'creating the analytics service of the module sends nothing to Firebase '
      'Analytics, so the setting of collection that it keeps holds', () async {
    createFirebaseAnalyticsService();
    // A turn of the event loop, so that what the service would send once it
    // is created, without waiting, reaches the mocks too.
    await Future<void>.delayed(Duration.zero);

    expect(
      analyticsCalls,
      isEmpty,
      reason: 'Creating the service calls nothing of Firebase Analytics, so '
          'it changes no setting that Firebase Analytics keeps on the device, '
          'such as that of collection.',
    );
  });

  test(
      'the native projects turn the collection of Firebase Analytics off by '
      'default exactly when the app collects nothing before its code chose',
      () {
    expect(
      _metaData('firebase_analytics_collection_enabled'),
      _collectedFromFirstStart ? isEmpty : ['false'],
      reason: _collectedFromFirstStart
          ? 'An app that collects from its first start leaves the default '
              'of Firebase Analytics on Android.'
          : 'An app that collects nothing before its code chose turns the '
              'collection of Firebase Analytics off by default on Android.',
    );
    expect(
      _plistValues('FIREBASE_ANALYTICS_COLLECTION_ENABLED'),
      _collectedFromFirstStart ? isEmpty : ['false'],
      reason: _collectedFromFirstStart
          ? 'An app that collects from its first start leaves the default '
              'of Firebase Analytics on iOS.'
          : 'An app that collects nothing before its code chose turns the '
              'collection of Firebase Analytics off by default on iOS.',
    );
  });
}
