// A test that continuous integration runs in the apps with the
// firebase_messaging module, on the real Firebase packages, whose platform
// side is a device in memory (firebase_messaging_mocks.dart): a service of
// the module that the app only listens to for messages hears of a message
// that arrives in the foreground. The plugin tells the app of what the
// platform sends only once something asked it for the platform side of
// Firebase Cloud Messaging, which listening to its stream of messages does
// not do, so the service does that when it is created.
//
// It has a file of its own: flutter test runs each test file in an isolate
// of its own, and a test before it in the same file would have set up the
// plugin already. It uses the service of the module and runs none of the
// start-up of the app but the start of Firebase (service.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/push/firebase_push_service.dart';

import '../firebase_messaging_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'a service that the app only listens to for messages hears of a '
      'message in the foreground', () async {
    final device = mockFirebaseMessaging();
    await initializeFirebase();
    final messages = <String>[];
    final subscription = createFirebasePushService()
        .messages
        .listen((message) => messages.add(describe(message)));
    addTearDown(subscription.cancel);

    await device.deliver(messageOfPlatform(id: 'first', title: 'First'));
    await aMoment();

    expect(
      messages,
      ['first | First | null | {}'],
      reason: 'The service sets up the plugin when it is created, so the '
          'messages of the platform reach it whatever the app asks first.',
    );
  });
}
