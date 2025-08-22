import 'package:{{app_name.snakeCase()}}/core/services/communication/base_event.dart';

class SendAnalyticsEvent extends BaseEvent {
  const SendAnalyticsEvent(this.event, {this.params});

  final String event;
  final Map<String, Object>? params;

  @override
  List<Object?> get props => [event, params];
}
