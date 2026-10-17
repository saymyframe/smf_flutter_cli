// A test that continuous integration runs in the apps with the
// firebase_messaging module, on the real Firebase packages, whose platform
// side is a device in memory (firebase_messaging_mocks.dart): what the push
// service of the module, which createFirebasePushService() creates, sends
// to Firebase Cloud Messaging, and what it makes of what Firebase answers
// and tells. On iOS the service sets the presentation options of a
// notification in the foreground to an alert, a badge and a sound when it
// is created, and on Android it makes no call then. It never asks for the
// permission to show notifications. The address is the registration token,
// and `null` where Firebase has none or fails, as on iOS before the token
// of the Apple Push Notification service comes. A message in the
// foreground, a tap on a message that the platform showed, a new token and
// the message whose tap launched the app reach the service with what they
// have, with a value of the data that is no text as its JSON.
//
// It uses the service of the module and runs none of the start-up of the
// app but the start of Firebase (service.dart). The matrix sets up the
// mocks of the platform side of every module of the app before the tests,
// and each test takes a device of its own, which records what reaches it.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/push/firebase_push_service.dart';
import 'package:{{app_name}}/core/push/push_service.dart';

import '../firebase_messaging_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseMessaging device;

  setUpAll(() async {
    mockFirebaseMessaging();
    await initializeFirebase();
  });

  setUp(() => device = mockFirebaseMessaging());

  tearDown(onAndroid);

  test(
      'on iOS the service sets the presentation options of a notification in '
      'the foreground to an alert, a badge and a sound when it is created, '
      'and on Android it makes no call then', () async {
    final onAndroidService = createFirebasePushService();
    await aMoment();
    final ofAndroid = device.methods;
    // The service reads the platform each time it is asked.
    final showsOnAndroid = onAndroidService.platformShowsInForeground;
    onIOS();
    final onIOSService = createFirebasePushService();
    await aMoment();

    expect(ofAndroid, isEmpty);
    expect(
      showsOnAndroid,
      isFalse,
      reason: 'Android shows no message that arrives in the foreground, so '
          'the app shows it as a notification of its own.',
    );
    expect(device.methods, ['setForegroundNotificationPresentationOptions']);
    expect(
      device.calls.single.arguments,
      {'appName': '[DEFAULT]', 'alert': true, 'badge': true, 'sound': true},
      reason: 'firebase_messaging answers iOS for every notification that '
          'arrives in the foreground, the local notifications of the app '
          'too, with these options, and with none of them by default: the '
          'service sets them, as the push role asks of a provider.',
    );
    expect(onIOSService.platformShowsInForeground, isTrue);
  });

  test(
      'the address is the registration token of the device, for which the '
      'plugin asks iOS for the token of the Apple Push Notification service '
      'first', () async {
    final service = createFirebasePushService();
    final onAndroidAddress = await service.address();
    final ofAndroid = device.methods;
    device.calls.clear();
    onIOS();
    final onIOSAddress = await service.address();

    expect(onAndroidAddress, tokenOfTests);
    expect(ofAndroid, ['getToken']);
    expect(onIOSAddress, tokenOfTests);
    expect(device.methods, ['getAPNSToken', 'getToken']);
  });

  test(
      'the address is null where Firebase has none or fails, as on iOS '
      'before the token of the Apple Push Notification service comes, and '
      'the service does not throw', () async {
    final service = createFirebasePushService();
    device.failNext(
      'getToken',
      code: 'unknown',
      message: 'java.io.IOException: SERVICE_NOT_AVAILABLE',
    );
    final withoutPlayServices = await service.address();
    device.token = null;
    final withoutToken = await service.address();
    device
      ..token = tokenOfTests
      ..apnsToken = null
      ..calls.clear();
    onIOS();
    final withoutApnsToken = await service.address();

    expect(
      (withoutPlayServices, withoutToken),
      (null, null),
      reason: 'A device without Google Play services or a network gives no '
          'token, and the address never throws, as the push role says.',
    );
    expect(
      withoutApnsToken,
      isNull,
      reason: 'The plugin fails on iOS before it asks for the registration '
          'token while the device has no token of the Apple Push '
          'Notification service, as a build that is not signed for push '
          'messages never has: the address is null then.',
    );
    expect(device.methods, ['getAPNSToken']);
  });

  test(
      'the service never asks for the permission to show notifications, on '
      'Android and on iOS, whatever the app calls', () async {
    Future<void> callEveryMember() async {
      final service = createFirebasePushService();
      await service.address();
      await service.launchMessage();
      final subscriptions = [
        service.messages.listen((_) {}),
        service.taps.listen((_) {}),
        service.addressChanges.listen((_) {}),
      ];
      await aMoment();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }

    await callEveryMember();
    onIOS();
    await callEveryMember();

    expect(
      device.methods.toSet(),
      {
        'getToken',
        'getAPNSToken',
        'getInitialMessage',
        'setForegroundNotificationPresentationOptions',
      },
      reason: 'The permission to show notifications belongs to the '
          'notifications of the app, as the push role says: the service '
          'never calls requestPermission() of the package, which shows the '
          'question of the system.',
    );
  });

  test(
      'a message in the foreground reaches the messages of the service with '
      'the title and the body of its notification, and its data as texts: a '
      'value that is no text is its JSON', () async {
    final service = createFirebasePushService();
    final messages = <String>[];
    final subscription =
        service.messages.listen((message) => messages.add(describe(message)));
    addTearDown(subscription.cancel);

    await device.deliver(
      messageOfPlatform(
        id: 'message-1',
        title: 'Title',
        body: 'Body',
        data: {
          'text': 'a text',
          'number': 1,
          'flag': true,
          'nested': {
            'list': [1, 'two'],
          },
          'none': null,
        },
      ),
    );
    await device.deliver(messageOfPlatform(data: {'only': 'data'}));
    await aMoment();

    expect(
      messages,
      [
        'message-1 | Title | Body | {text: a text, number: 1, flag: true, '
            'nested: {"list":[1,"two"]}, none: null}',
        'null | null | null | {only: data}',
      ],
      reason: 'iOS may give a value of the data of a message as something '
          'other than a text, and the push role says that such a value is '
          'its JSON. A message with data alone has no title or body.',
    );
  });

  test('a tap on a message that the platform showed reaches the taps',
      () async {
    final service = createFirebasePushService();
    final taps = <String>[];
    final subscription =
        service.taps.listen((message) => taps.add(describe(message)));
    addTearDown(subscription.cancel);

    await device.open(
      messageOfPlatform(
        id: 'message-2',
        title: 'Tapped',
        data: {'screen': 'inbox', 'count': 2},
      ),
    );
    await aMoment();

    expect(taps, ['message-2 | Tapped | null | {screen: inbox, count: 2}']);
  });

  test(
      'a new registration token reaches the address changes, and is the '
      'address from then on', () async {
    final service = createFirebasePushService();
    final changes = <String>[];
    final subscription = service.addressChanges.listen(changes.add);
    addTearDown(subscription.cancel);

    await device.refreshAddress('another token of the tests');
    await aMoment();

    expect(
      changes,
      ['another token of the tests'],
      reason: 'Firebase tells of a new token, and of the first one on iOS '
          'once the token of the Apple Push Notification service came: the '
          'push role says that the address changes tell of both.',
    );
    expect(await service.address(), 'another token of the tests');
  });

  test(
      'the message whose tap launched the app is the launch message, on '
      'Android and on iOS, and an app that no tap launched has none', () async {
    final service = createFirebasePushService();
    final none = await service.launchMessage();
    device.launchWith(
      messageOfPlatform(
        id: 'launch-1',
        title: 'Hello',
        body: 'World',
        data: {'screen': 'inbox'},
      ),
    );
    final onAndroidLaunch = await service.launchMessage();
    onIOS();
    device.launchWith(messageOfPlatform(id: 'launch-2', data: {'n': 1}));
    final onIOSLaunch = await service.launchMessage();

    expect(describe(none), 'none');
    expect(
      [describe(onAndroidLaunch), describe(onIOSLaunch)],
      [
        'launch-1 | Hello | World | {screen: inbox}',
        'launch-2 | null | null | {n: 1}',
      ],
    );
  });

  test(
      'the launch message is null where Firebase fails, and the service does '
      'not throw', () async {
    final service = createFirebasePushService();
    device.failNext(
      'getInitialMessage',
      code: 'unknown',
      message: 'The platform broke.',
    );

    PushMessage? launch;
    Object? error;
    try {
      launch = await service.launchMessage();
    } on Object catch (thrown) {
      error = thrown;
    }

    expect(
      (describe(launch), error),
      ('none', null),
      reason: 'A launch message that fails would keep the app from knowing '
          'how it was launched: the push role says that it never throws.',
    );
  });
}
