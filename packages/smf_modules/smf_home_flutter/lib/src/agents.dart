/// The heading of the section of the module in the guide for coding agents
/// of the app.
const agentHeading = 'Home';

/// The note of the module in the guide for coding agents: what its screen
/// is for, and where the image that it shows is declared.
const agentNote = '''
- `HomeScreen` in `lib/features/home/home_screen.dart`, the route `home.home` at `/home`, is a welcome to the developer of the app: it names the app and lists what to do next. Replace its content with the first screen of the app, and keep the route while the app starts there.
- The screen shows the image `lib/features/home/assets/smf_mark.png`, which `pubspec.yaml` declares among the assets of the app. Flutter takes the files of the same name in `2.0x/` and `3.0x/` next to it for a screen with more pixels. Once no screen shows the image, remove the files and their line in `pubspec.yaml`.
''';
