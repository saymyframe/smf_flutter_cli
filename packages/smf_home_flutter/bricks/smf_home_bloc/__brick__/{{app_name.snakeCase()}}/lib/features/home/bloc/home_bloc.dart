import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_bloc.freezed.dart';

part 'home_events.dart';

part 'home_states.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeLoadingState()) {
    on<HomeFetchEvent>(_fetchEvent);
  }

  factory HomeBloc.create() {
    return HomeBloc();
  }

  Future<void> _fetchEvent(HomeEvent event, Emitter<HomeState> emit) async {
    emit(ConnectedModulesState({{#modules}} {{{.}}} {{/modules}}));
  }
}
