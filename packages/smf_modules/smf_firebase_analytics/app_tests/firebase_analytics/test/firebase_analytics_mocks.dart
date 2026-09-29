// The platform side of Firebase Analytics for the tests that continuous
// integration runs in the apps with Firebase Analytics: it records what
// reaches it. The matrix sets it up before the tests of every module of
// such an app (MatrixAppTest.mocks), so that any of them may run the
// start-up of the app, which logs the screens that the user sees.
// firebase_analytics_platform_interface 6 has no mocks for tests, as those
// of Firebase Core and Crashlytics, so this answers its messages to the
// platform: each method of FirebaseAnalyticsHostApi on a channel of its
// own, with the arguments as a list in the standard codec, and logEvent
// with a map of the name and the parameters of the event. A version of the
// package that changes them breaks these tests.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The prefix of the channels of the platform side of Firebase Analytics.
const _channels = 'dev.flutter.pigeon.firebase_analytics_platform_interface.'
    'FirebaseAnalyticsHostApi.';

/// What reached the platform side of Firebase Analytics: each call as its
/// method followed by its arguments.
final List<List<Object?>> analyticsCalls = [];

/// The parameters of the screen views that reached Firebase Analytics.
List<Map<Object?, Object?>> get screenViews => [
      for (final call in analyticsCalls)
        if (call case ['logEvent', {'eventName': 'screen_view'} && final event])
          (event['parameters'] ?? const {}) as Map<Object?, Object?>,
    ];

/// Answers the platform side of Firebase Analytics, recording each call in
/// [analyticsCalls].
///
/// The binding of the tests must be initialized first.
void mockFirebaseAnalytics() {
  const codec = StandardMessageCodec();
  for (final method in [
    'logEvent',
    'setUserId',
    'setUserProperty',
    'setAnalyticsCollectionEnabled',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('$_channels$method', (message) async {
      final arguments = codec.decodeMessage(message)! as List<Object?>;
      analyticsCalls.add([method, ...arguments]);
      return codec.encodeMessage(<Object?>[null]);
    });
  }
}
