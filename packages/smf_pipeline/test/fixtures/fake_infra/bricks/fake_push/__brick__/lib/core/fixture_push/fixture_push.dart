import 'dart:async';

import '../push/push_service.dart';

/// The address of this device for push messages, or `null` while the
/// device has none. It stands for the registration of the device with the
/// service of push messages, which every start of the app finds as the last
/// one left it.
String? _address;

/// How many addresses the service of push messages gave this device, so
/// that each one differs from the others.
int _given = 0;

/// The registration of the device while it is on its way.
Future<void>? _registration;

/// Tells the app of the address that the device gets: it stands for the
/// platform, so it outlives a start of the app.
final StreamController<String> _addresses =
    StreamController<String>.broadcast();

/// Waits for the answer of the system, which takes a moment, as with a
/// provider that asks it: a turn of the event loop. So a test makes the
/// calls of the push messages in real time, as it runs the start-up of the
/// app.
Future<void> _answer() => Future<void>.delayed(Duration.zero);

/// Opens the push messages of the fixture, as a start of the app does: it
/// asks the system for what it keeps, which takes a moment, and returns the
/// service. It asks the user nothing.
///
/// The first start registers the device, which gets its address a while
/// later, as an iPhone gets the token of APNs: the service answers `null`
/// until then, and tells of the address on its address changes. A later
/// start finds the address that the device kept. Nothing outlives the
/// process of the app, so each run of the tests of a file starts as on a
/// first launch.
Future<PushService> openFixturePush() async {
  await _answer();
  if (_address == null) _registration ??= _register();
  return FixturePush._();
}

/// Registers the device with the service of push messages, which takes a
/// while, and tells the app of the address that the device got.
Future<void> _register() async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  final address = _address = 'fixture-device-${++_given}';
  _registration = null;
  _addresses.add(address);
}

/// Push messages in memory, on a device that shows nothing itself, so the
/// app shows a message that arrives in the foreground. No server sends it a
/// message, and it has no user who taps one, so the service tells of
/// neither, and the app was not launched by a tap on a message.
final class FixturePush implements PushService {
  FixturePush._();

  @override
  bool get platformShowsInForeground => false;

  @override
  Future<String?> address() async {
    await _answer();
    return _address;
  }

  @override
  Stream<String> get addressChanges => _addresses.stream;

  @override
  Stream<PushMessage> get messages => const Stream.empty();

  @override
  Stream<PushMessage> get taps => const Stream.empty();

  @override
  Future<PushMessage?> launchMessage() async {
    await _answer();
    return null;
  }
}
