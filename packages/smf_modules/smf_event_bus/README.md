# smf_event_bus

The SMF module of events with [event_bus](https://pub.dev/packages/event_bus). It provides the events role of SMF: parts of the app that do not know each other, such as two features, exchange events through one service.

The events role generates the `CommunicationService` interface, whose `fire(event)` sends an event and `on<T>()` is the stream of the events of type `T`, and `AppEvent`, the base class of the events. This module adds `event_bus` to the app and implements the service on an `EventBus`. With a module that provides dependency injection, the service is registered in its container.

## Use with the SMF CLI

`smf create` asks which module provides the events of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m event_bus
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS and Linux; Windows is not tested yet.

## Documentation

- [The event_bus module](https://doc.saymyframe.com/modules/event-bus)
- [Services and state](https://doc.saymyframe.com/guides/services)
