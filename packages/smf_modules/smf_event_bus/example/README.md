# Generate a Flutter app with an event bus

`event_bus` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) through which parts of the app that do not know each other exchange events. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m event_bus --no-input
```

The module adds event_bus to the `pubspec.yaml` of the app, and `lib/core/events/event_bus_communication_service.dart` with the service on an `EventBus`. The rest of the app uses the interface in `lib/core/events/communication_service.dart`, which the events role adds:

```dart
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
```

With `event_bus`, a listener of a type gets the events of the types that extend or implement it too, so `on<AppEvent>()` gets every event.

An event is a subclass of `AppEvent`. One part of the app listens, another fires:

```dart
final class ItemAdded extends AppEvent {
  const ItemAdded();
}

final events = createCommunicationService();
events.on<ItemAdded>().listen((event) => debugPrint('An item was added'));
events.fire(const ItemAdded());
```

With a module of dependency injection, such as `get_it`, the service is registered in the container, and a feature takes it with `resolve` in its composition file.

Without `-m`, `smf create` asks which module provides the events of the app.

The documentation has more on [the event_bus module](https://doc.saymyframe.com/modules/event-bus) and on [events in the generated app](https://doc.saymyframe.com/guides/services#events).
