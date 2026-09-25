import 'dart:async';

import '../events/communication_service.dart';

/// Opens the event channel of the fixture, which takes a moment.
Future<CommunicationService> openFixtureEvents() async => FixtureEvents();

/// Delivers events to the listeners of their type through one stream.
final class FixtureEvents implements CommunicationService {
  final _events = StreamController<AppEvent>.broadcast();

  @override
  void fire(AppEvent event) => _events.add(event);

  @override
  Stream<T> on<T extends AppEvent>() =>
      _events.stream.where((event) => event is T).cast<T>();
}
