import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Launcher icons';

/// The file that says how the icon is made.
const configFile = 'flutter_launcher_icons.yaml';

/// The script of the app that makes the icon, as a path from the root of the
/// app.
const updateScript = 'tool/update_app_icon.dart';

/// The command that makes the icon again.
const updateCommand = 'dart $updateScript';

/// The section of the module in the README of the app, after the section of
/// the role: what the two images show, how much of the foreground launchers
/// cut, and the command to run after a change.
const readmeSection = '''
`${AppIconRole.imageFile}` shows the logo of Say My Frame in cream on green, and `${AppIconRole.foregroundFile}` shows the same logo on a transparent background. On Android, `adaptive_icon_background` of `$configFile` is the colour behind it. Replace both images before you release the app.

Launchers cut the second image to a shape of their own. They always keep a circle around its centre, as wide as 90% of the image, since `adaptive_icon_foreground_inset` of `$configFile` is 16%. Keep the whole logo inside that circle. The themed icon of Android is the alpha of the same image.

After you change an image or `$configFile`, run this command and commit what changed under `android/` and `ios/`:

```bash
$updateCommand
```

Use this script rather than `dart run flutter_launcher_icons`, which writes the name of the icon into a build setting of the Xcode project that takes YES or NO. The script repairs that setting. A file `flutter_launcher_icons-<flavor>.yaml` turns `$configFile` off, and on iOS it does not switch the icon of a flavor, so one icon for each flavor needs more than that file.
''';
