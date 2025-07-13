import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:{{app_name.snakeCase()}}/core/services/communication/events/send_analytics_event.dart';
import 'package:{{app_name.snakeCase()}}/core/services/communication/i_communication_service.dart';
import 'package:{{app_name.snakeCase()}}/core/typedef.dart';

part 'home_cubit.freezed.dart';
part 'home_states.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required this.communicationService}) : super(const HomeLoading());

  factory HomeCubit.create() {
    return HomeCubit(communicationService: getIt());
  }

  final ICommunicationService communicationService;

  void sendAnalyticsEvent() {
    communicationService.fire(SendAnalyticsEvent('test_event'));
  }
}
