import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/di/service_locator.dart';

/// The analytics service for the widgets of the feature: a bridge from the
/// service locator to Riverpod.
final fixtureAnalyticsProvider =
    Provider<AnalyticsService>((_) => resolve<AnalyticsService>());

/// Counts the taps on the details screen.
final fixtureTapsProvider = NotifierProvider<FixtureTaps, int>(FixtureTaps.new);

/// Counts the taps on the details screen and logs them.
class FixtureTaps extends Notifier<int> {
  @override
  int build() => 0;

  /// Counts a tap.
  Future<void> tap() async {
    await ref.read(fixtureAnalyticsProvider).logEvent('fixture_tap');
    state++;
  }
}
