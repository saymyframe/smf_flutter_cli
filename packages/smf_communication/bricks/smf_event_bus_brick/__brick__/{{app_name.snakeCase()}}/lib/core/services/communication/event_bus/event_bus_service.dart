import 'package:event_bus/event_bus.dart';
import 'package:{{app_name.snakeCase()}}/core/services/communication/base_event.dart';
import 'package:{{app_name.snakeCase()}}/core/services/communication/i_communication_service.dart';

class EventBusService implements ICommunicationService {
  const EventBusService(this._eventBus);

  final EventBus _eventBus;

  @override
  void fire(BaseEvent event) => _eventBus.fire(event);

  @override
  Stream<T> on<T extends BaseEvent>() => _eventBus.on<T>();
}
