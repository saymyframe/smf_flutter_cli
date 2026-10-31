import 'package:smf_launcher_icons/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the app icon: the command that makes the icon, which the note
/// of the role leaves to its provider, and the two ways around it that break
/// something.
const agentNote = '''
With `flutter_launcher_icons`:

- After a change of a source or of `$configFile`, run `$updateCommand` and commit what changed under `android/` and `ios/`.
- Do not run `dart run flutter_launcher_icons` itself: it writes the name of the icon into a build setting of the Xcode project that takes YES or NO, and the script repairs that setting.
- Do not add a `flutter_launcher_icons-<flavor>.yaml`. It turns `$configFile` off, and on iOS it does not switch the icon of a flavor.
''';
