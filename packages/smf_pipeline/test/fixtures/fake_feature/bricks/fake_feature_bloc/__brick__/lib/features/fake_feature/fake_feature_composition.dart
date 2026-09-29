import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/di/service_locator.dart';

/// Creates the cubit of the details screen with its services.
FixtureCubit createFixtureCubit() => FixtureCubit(resolve<AnalyticsService>());

/// Counts the taps on the details screen and logs them.
class FixtureCubit extends Cubit<int> {
  /// Creates the cubit.
  FixtureCubit(this._analytics) : super(0);

  final AnalyticsService _analytics;

  /// Counts a tap.
  Future<void> tap() async {
    await _analytics.logEvent('fixture_tap');
    emit(state + 1);
  }
}
