// A test of the analytics role that continuous integration runs in the apps
// with every module whose modules give the app the analytics role,
// whichever modules provide it there: what the code of the app chose with
// setAnalyticsCollectionEnabled() holds at the next start, whatever the app
// collects before its code chose, since every provider keeps it on the
// device. A provider that keeps it only in memory would collect a session
// at the next start, which its SDK records itself before any code of the
// app runs.
//
// The test looks at the fixture analytics, whose platform side it answers
// as a device that keeps the setting of collection as the SDK of a provider
// does (analytics_collection.dart), and starts it again as the next launch
// of the app does. What another provider, such as Firebase Analytics, keeps,
// only the test of its own module knows.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';

import 'analytics_collection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FixtureAnalyticsDevice device;

  setUpAll(() async {
    device = FixtureAnalyticsDevice();
    await startUp();
  });

  setUp(() => device.collected.clear());

  test('a collection that the code turned off stays off at the next start',
      () async {
    final analytics = createAnalyticsService();

    await analytics.setAnalyticsCollectionEnabled(false);
    await startAgain();
    await analytics.logEvent('smf_after_off');

    expect(
      device.collected,
      isEmpty,
      reason: 'A collection that the code turned off stays off at the next '
          'start, also for a session that the SDK records itself.',
    );
  });

  test('a collection that the code turned on stays on at the next start',
      () async {
    final analytics = createAnalyticsService();

    await analytics.setAnalyticsCollectionEnabled(true);
    await startAgain();
    await analytics.logEvent('smf_after_on');

    expect(
      device.collected,
      [sessionStart, 'smf_after_on'],
      reason: 'A collection that the code turned on stays on at the next '
          'start.',
    );
  });
}
