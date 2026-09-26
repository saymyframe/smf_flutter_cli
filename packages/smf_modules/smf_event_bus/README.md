# smf_event_bus

The SMF module of events with [event_bus](https://pub.dev/packages/event_bus). It provides the events role of the SMF module model: parts of the app that do not know each other, such as two features, exchange events through one service.

The events role generates `lib/core/events/communication_service.dart`:

- `AppEvent`, the base class of the events, such as `final class ItemAdded extends AppEvent`;
- the `CommunicationService` interface: `fire(event)` sends an event, and `on<T>()` is the stream of the events of type `T`;
- `createCommunicationService()`, which returns the service of the app.

This module adds `event_bus` to the dependencies of the app and implements the service in `lib/core/events/event_bus_communication_service.dart`, on an `EventBus` of the package:

- an event goes to everyone listening to its type, or to a type it extends or implements, so `on<AppEvent>()` gets every event;
- listeners get an event after the code that fires it has completed, not during `fire`;
- a listener gets the events fired after it starts listening.

The service is created on first use, without waiting, so the app starts as it would without it. When the app has a module that provides dependency injection, the events role registers the service in its container as a lazy singleton. The code that creates what the screens of a feature need, such as a Cubit, then takes the service with `resolve` in the composition file of the feature, and other services get it as a parameter of their factory function.

## Use with SMF CLI

`smf create` asks which module provides the events of the app, and offers none as well. To choose this one without the question, name it with `-m`:

```bash
smf create my_app -m event_bus
```

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_event_bus) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
