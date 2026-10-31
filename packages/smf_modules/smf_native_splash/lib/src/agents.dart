import 'package:smf_native_splash/src/config.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the splash role, after what the role says there: the command
/// that the role leaves to its provider, the setting that must stay out of
/// the configuration, and that no code of the app imports the package.
const agentNote = '''
With `flutter_native_splash`:

- `$configFile` has the images and the colours of the screen. After a change of that file or of an image, run `$splashCommand` and commit what it changed under `android/` and `ios/`.
- Never set `android_min_sdk` in `$configFile`. The tool then leaves `android/app/src/main/res/drawable-v21/launch_background.xml` as it is, and that file wins on Android below 12, so the screen there has no image.
- The package is a dev dependency, so no code of the app imports it.
''';
