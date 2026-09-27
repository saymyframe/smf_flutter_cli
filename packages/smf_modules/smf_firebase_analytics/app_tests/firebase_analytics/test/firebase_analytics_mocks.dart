// The platform side of Firebase Analytics for the tests that continuous
// integration runs in the apps with Firebase Analytics: it records what
// reaches it.
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
