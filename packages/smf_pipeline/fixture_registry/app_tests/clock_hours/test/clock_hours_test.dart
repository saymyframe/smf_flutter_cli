// A test that continuous integration runs in the apps with every fixture
// module, which have the fixture clock and the module that uses it
// (fake_clock_user): the clock of the app shows the hours that the clock
// role chose when the app was generated, 24 or 12, and the clock user shows
// an hour as that clock has it.
//
// The role has a mode option, --clock-hours, and the matrix has each of
// these apps once for each of its values. The code for the value is in
// three places, which only a running app shows to agree: the constant that
// the template of the role writes, the code of the hours that the provider
// of the clock renders for the app, and the code of the clock user, the
// same in every app, which reads the constant when the app runs.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/clock/clock.dart';
import 'package:{{app_name}}/core/clock_user/clock_user.dart';

/// How many hours the clock of the app shows, as the clock role chose: the
/// matrix fills it from the choice of the role, not from the options that
/// it gave `smf create`. An app with a clock of 24 hours got none, and the
/// role chose its first value.
final int _hours = int.parse('{{clock_hours}}');

/// The hour of [hour] o'clock as the clock user shows it.
String _shown(int hour) => clockUserHour(DateTime(2026, 1, 1, hour));

void main() {
  test('the clock of the app has the hours that the clock role chose', () {
    expect(const [24, 12], contains(_hours));
    expect(
      clockHours,
      _hours,
      reason: 'The constant of the role is not the choice of the role.',
    );
  });

  test('the clock user shows an hour on the clock of the app', () {
    const hours = [0, 1, 9, 12, 13, 23];

    expect(
      [for (final hour in hours) _shown(hour)],
      switch (_hours) {
        12 => ['12 AM', '1 AM', '9 AM', '12 PM', '1 PM', '11 PM'],
        _ => ['0:00', '1:00', '9:00', '12:00', '13:00', '23:00'],
      },
      reason: 'The clock user does not show the hours of a clock of $_hours '
          'hours.',
    );
  });
}
