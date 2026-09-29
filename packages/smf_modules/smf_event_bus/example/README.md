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
abstract interface class CommunicationService {
  /// Sends [event] to everyone listening to its type.
  void fire(AppEvent event);

  /// The events of type [T] sent from now on.
  Stream<T> on<T extends AppEvent>();
}
```

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
