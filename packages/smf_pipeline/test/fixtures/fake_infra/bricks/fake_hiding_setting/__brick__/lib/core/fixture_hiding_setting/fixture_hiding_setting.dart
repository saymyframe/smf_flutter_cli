import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Whether the settings screen of the app shows [FixtureHidingSetting]: on
/// every platform but iOS, so a test that has the app run on iOS sees the
/// screen leave the entry out.
bool fixtureHidingSettingShows() =>
    defaultTargetPlatform != TargetPlatform.iOS;

/// The setting of the fixture that the settings screen shows only while
/// [fixtureHidingSettingShows] returns true.
class FixtureHidingSetting extends StatelessWidget {
  /// Creates the row.
  const FixtureHidingSetting({super.key});

  @override
  Widget build(BuildContext context) => const ListTile(
    leading: Icon(Icons.visibility_off),
    title: Text('Not on iOS'),
  );
}
