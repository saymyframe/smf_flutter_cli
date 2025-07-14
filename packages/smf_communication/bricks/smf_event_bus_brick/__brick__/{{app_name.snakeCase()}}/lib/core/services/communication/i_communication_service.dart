import 'package:{{app_name.snakeCase()}}/core/services/communication/base_event.dart';

abstract interface class ICommunicationService {
  Stream<T> on<T extends BaseEvent>();

  void fire(BaseEvent event);
}
