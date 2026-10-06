{{#has_badge}}
import '../badge/badge_factory.dart';

{{/has_badge}}
/// The text that the clock user shows: the labels of the badge when the
/// app has one.
String clockUserText() {
{{#has_badge}}
  return createBadge().labels.join(', ');
{{/has_badge}}
{{^has_badge}}
  return 'No badge';
{{/has_badge}}
}

/// The time zones that the clock user shows: those of the clock when the
/// app has one.
List<String> clockUserZones() => {{{clock_zones}}};
