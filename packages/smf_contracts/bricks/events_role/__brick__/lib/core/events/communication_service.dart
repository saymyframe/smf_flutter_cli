/// A message that one part of the app sends to the others, such as
/// `final class ItemAdded extends AppEvent`.
abstract class AppEvent {
  /// Allows the events to have constant constructors.
  const AppEvent();
}

/// Delivers [AppEvent]s between parts of the app that do not know each
/// other.
abstract interface class CommunicationService {
  /// Sends [event] to everyone listening to its type.
  void fire(AppEvent event);

  /// The events of type [T] sent from now on.
  Stream<T> on<T extends AppEvent>();
}

/// Returns the communication service of the app.
CommunicationService createCommunicationService() => _communicationService;

{{{smf_events__implementations}}}
