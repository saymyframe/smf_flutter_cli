/// A message that one part of the app sends to the others, such as
/// `final class ItemAdded extends AppEvent`.
abstract class AppEvent {
  /// Allows the events to have constant constructors.
  const AppEvent();
}

/// Delivers [AppEvent]s between parts of the app that do not know each
/// other.
///
/// Whether a listener of a type that an event extends or implements, such
/// as a listener of `on<AppEvent>()`, gets the event is up to the provider
/// of the service.
abstract interface class CommunicationService {
  /// Sends [event] to everyone listening to its type when it is fired.
  void fire(AppEvent event);

  /// The events of type [T] fired after the stream is listened to. An event
  /// fired before, even after this call returned the stream, is not in it.
  Stream<T> on<T extends AppEvent>();
}

/// Returns the communication service of the app.
CommunicationService createCommunicationService() => _communicationService;

{{{smf_events__implementations}}}
