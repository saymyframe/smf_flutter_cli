import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:{{app_name.snakeCase()}}/core/services/analytics/i_analytics_service.dart';
import 'package:{{app_name.snakeCase()}}/core/typedef.dart';

class FirebaseAnalyticsCubit extends Cubit<void> {
  FirebaseAnalyticsCubit(this._analyticsService) : super(null);

  factory FirebaseAnalyticsCubit.create() {
    return FirebaseAnalyticsCubit(getIt());
  }

  final IAnalyticsService _analyticsService;

  void logAnalyticsEvent(String event, {Map<String, Object>? params}) {
    _analyticsService.logEvent(event, parameters: params);
  }
}
