// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// The widgets of the entries of the settings screen, in the order of the
/// settings screen role: every entry, whatever its function says.
const List<Widget> _entries = [
{{{entries}}}
];

/// The settings screen of the app, with a known bug (fixture): it shows
/// every entry, also one whose function says that it does not show, which
/// it never asks.
{{{smf_router__screen_annotations__broken_settings_shows_hidden__broken_settings_screen}}}
class BrokenSettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const BrokenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: ListView(children: _entries));
}
