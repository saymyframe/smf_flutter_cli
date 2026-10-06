/// The note of the module in the guide for coding agents of the app, in the
/// section of the settings screen: where the screen is, what its list has
/// besides the entries, and how code opens the screen in an app without a
/// main navigation, where no screen leads to it.
const String agentNote = '''
- `SettingsScreen` in `lib/features/settings/settings_screen.dart`, the route `settings.settings` at `/settings`, is the settings screen. Its list has the entries and then About, the last row, which is the screen's own. The file imports the files of the entries as `entry0`, `entry1` and so on.
- With a main navigation in the app, the screen is one of its destinations.
- Without a main navigation, no screen leads to the settings screen: open it with `context.nav.settings.settings().push<void>()`, which shows it on top of the current screen, so that its back button leads back. `go()` would replace the stack with the screen alone, and nothing would lead back.
''';
