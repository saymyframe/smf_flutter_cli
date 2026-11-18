// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// The widgets of the entries of the settings screen that show, in the
/// order of the settings screen role: an entry with a function only while
/// the function returns true.
List<Widget> get _entries => [
{{{entries}}}
];

/// The settings screen of the app, with a known bug (fixture): it creates
/// the widget of every entry, but its list leaves out the last one.
{{{smf_router__screen_annotations__broken_settings_hides_last_entry__broken_settings_screen}}}
class BrokenSettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const BrokenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      body: ListView(
        children: [
          for (final entry in entries)
            if (!identical(entry, entries.last)) entry,
        ],
      ),
    );
  }
}
