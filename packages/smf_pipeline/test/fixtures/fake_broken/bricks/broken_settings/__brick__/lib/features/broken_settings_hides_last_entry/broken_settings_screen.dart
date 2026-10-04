import 'package:flutter/material.dart';

/// The widgets of the entries of the settings screen, in the order of the
/// settings screen role.
const List<Widget> _entries = [
{{{entries}}}
];

/// The settings screen of the app, with a known bug (fixture): it creates
/// the widget of every entry, but its list leaves out the last one.
{{{smf_router__screen_annotations__broken_settings_hides_last_entry__broken_settings_screen}}}
class BrokenSettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const BrokenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        for (final entry in _entries)
          if (!identical(entry, _entries.last)) entry,
      ],
    ),
  );
}
