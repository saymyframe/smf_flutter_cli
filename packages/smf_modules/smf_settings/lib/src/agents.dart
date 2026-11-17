/// The note of the module in the guide for coding agents of the app, in the
/// section of the settings screen: where the screen is, what it shows with
/// entries and without, also while every entry hides, and how code opens the
/// screen in an app without a main navigation, where no screen leads to it.
const String agentNote = '''
- `SettingsScreen` in `lib/features/settings/settings_screen.dart`, the route `settings.settings` at `/settings`, is the settings screen. Below its title it shows the entries in one group, and the file imports the files of the entries as `entry0`, `entry1` and so on. An entry may show only at times, such as one that hides on a platform: the screen asks it each time it builds. While no module of the app has a setting, or while none of its entries shows, the screen shows a note for the developer of the app in place of the group: the first entry that shows replaces that note.
- With a main navigation in the app, the screen is one of its destinations.
- Without a main navigation, no screen leads to the settings screen: open it with `context.nav.settings.settings().push<void>()`, which shows it on top of the current screen, so that its back button leads back. `go()` would replace the stack with the screen alone, and nothing would lead back.
''';
