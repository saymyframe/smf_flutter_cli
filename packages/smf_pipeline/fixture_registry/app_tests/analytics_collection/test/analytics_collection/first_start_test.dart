// A test of the analytics role that continuous integration runs in the apps
// with every module whose modules give the app the analytics role,
// whichever modules provide it there: at its first start, an app collects
// analytics exactly when the role chose that it collects from its first
// start (--analytics-collection), and in a debug build, an app that collects
// nothing before its code chose says so at its start.
//
// The role has a mode option, and the matrix has each of these apps once
// more for its other value. The test looks at the fixture analytics, whose
// platform side it answers as a device on which the app never ran, which
// keeps the setting of collection as the SDK of a provider does
// (analytics_collection.dart). What another provider, such as Firebase
// Analytics, does at its start, only the test of its own module knows.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';

import 'analytics_collection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FixtureAnalyticsDevice device;
  var printed = <String>[];

  setUpAll(() async {
    device = FixtureAnalyticsDevice();
    printed = await startUp();
  });

  test(
      'at its first start, the app collects analytics exactly when it was '
      'generated to collect from its first start', () async {
    expect(
      analyticsCollectedFromFirstStart,
      collectedFromFirstStart,
      reason: 'The constant of the app is the choice of the analytics role.',
    );

    await createAnalyticsService().logEvent('smf_first_start');

    expect(
      device.collected,
      collectedFromFirstStart ? ['smf_first_start'] : isEmpty,
      reason: collectedFromFirstStart
          ? 'An app that collects from its first start collects at its '
              'first start.'
          : 'An app that collects nothing before its code chose collects '
              'nothing at its first start.',
    );
  });

  test(
      'in a debug build, the start-up says that collection waits for the code '
      'of the app exactly when the app collects nothing before its code chose',
      () {
    expect(
      printed.where(
        (line) => line.contains('setAnalyticsCollectionEnabled(true)'),
      ),
      hasLength(collectedFromFirstStart ? 0 : 1),
      reason: 'In a debug build of an app that collects nothing before its '
          'code chose, and only there, the start-up prints once that the app '
          'collects nothing until its code turns collection on.',
    );
  });
}
