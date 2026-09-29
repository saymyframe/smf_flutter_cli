import 'package:event_bus/event_bus.dart';

import 'communication_service.dart';

/// Creates a communication service on a new [EventBus] of the event_bus
/// package.
///
/// The app has one service, which `createCommunicationService()` returns:
/// the listeners of one service do not get the events fired into another.
CommunicationService createEventBusCommunicationService() =>
    EventBusCommunicationService(EventBus());

/// Delivers the events of the app through an [EventBus].
///
/// An event goes to everyone listening to its type, or to a type it extends
/// or implements, after the code that fires it has completed. A listener
/// gets the events fired after it starts listening.
final class EventBusCommunicationService implements CommunicationService {
  /// Creates the service on the given [EventBus].
  EventBusCommunicationService(this._eventBus);

  final EventBus _eventBus;

  @override
  void fire(AppEvent event) => _eventBus.fire(event);

  @override
  Stream<T> on<T extends AppEvent>() => _eventBus.on<T>();
}
