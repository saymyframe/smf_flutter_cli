part of 'home_bloc.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState.loading() = HomeLoadingState;

  const factory HomeState.modules(List<String> modules) = ConnectedModulesState;
}
