import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:{{app_name.snakeCase()}}/core/services/system/i_system_service.dart';
import 'package:{{app_name.snakeCase()}}/core/typedef.dart';

part 'home_bloc.freezed.dart';
part 'home_events.dart';
part 'home_states.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this._systemService) : super(const HomeLoadingState()) {
    on<HomeFetchEvent>(_fetchEvent);
  }

  factory HomeBloc.create() {
    return HomeBloc(getIt());
  }

  final ISystemService _systemService;

  Future<void> _fetchEvent(HomeEvent event, Emitter<HomeState> emit) async {
    emit(ConnectedModulesState(_systemService.getConnectedModules()));
  }
}
