/// A push message: a message that a server sends to this device through the
/// provider of push messages.
final class PushMessage {
  /// Creates the message with its [id], [title], [body] and [data], each if
  /// it has one.
  const PushMessage({this.id, this.title, this.body, this.data = const {}});

  /// The id that the provider gives the message, or `null` if it gives none.
  final String? id;

  /// The title of the message, or `null` for a message without one.
  final String? title;

  /// The text of the message, or `null` for a message without one.
  final String? body;

  /// What the server sent for the app to read, such as the screen that a
  /// tap opens.
  final Map<String, String> data;
}

/// The push messages of the platform, which the provider of push messages
/// implements: the address of the device, the messages that arrive while
/// the app is in the foreground, and the taps of the user on the messages
/// that the platform shows.
///
/// The code of the app does not use it: it uses `appPush` of
/// `app_push.dart`, which calls this service, shows a message in the
/// foreground where the platform does not, and tells of the taps on the
/// messages that it showed.
///
/// Every implementation keeps to this:
/// - The function that creates the service asks the user nothing. It may be
///   called again, and the service that it returns then has the address
///   that the device kept.
/// - The service never asks for the permission to show notifications, which
///   the notifications of the app ask for, and never keeps the notifications
///   of the app from showing while the app is in the foreground.
/// - [address] completes with the address of the device, or with `null`
///   while the platform gives none, and does not throw. It needs no
///   permission. The address stays the same from one launch of the app to
///   the next, unless [addressChanges] tells of another.
/// - [messages] tells of each message that arrives while the app is in the
///   foreground, once.
/// - A message with a title or a body that arrives while the app is in the
///   background, or closed, is shown by the platform, on Android in the
///   channel of the notifications of the app. [taps] tells of each tap on
///   such a message while the app runs, and [launchMessage] is the message
///   whose tap launched the app.
/// - In the foreground, the platform shows such a message itself where
///   [platformShowsInForeground] is true, and [taps] then tells of a tap on
///   it too. Where it is false, the service shows nothing of the message,
///   and the app shows it as a notification of its own.
/// - [launchMessage] completes without the network, and does not throw.
abstract interface class PushService {
  /// Whether the platform shows a message with a title or a body that
  /// arrives while the app is in the foreground. The app shows it otherwise.
  bool get platformShowsInForeground;

  /// The address of the device, to which a server sends the messages for
  /// this app, or `null` while the platform gives none.
  Future<String?> address();

  /// Tells of each new address of the device: a broadcast stream.
  Stream<String> get addressChanges;

  /// Tells of each message that arrives while the app is in the foreground:
  /// a broadcast stream.
  Stream<PushMessage> get messages;

  /// Tells of each tap of the user on a message that the platform showed,
  /// while the app runs: a broadcast stream.
  Stream<PushMessage> get taps;

  /// The message whose tap launched the app, or `null` if the app was
  /// launched in another way.
  Future<PushMessage?> launchMessage();
}
