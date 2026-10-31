// Makes the launcher icons of the app from assets/branding/, as
// flutter_launcher_icons.yaml says. Run it again after you change an image:
//
//     dart tool/update_app_icon.dart
import 'dart:io';

import 'package:flutter_launcher_icons/main.dart' as flutter_launcher_icons;

const _project = '{{{xcode_project}}}';
const _setting = 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS';

Future<void> main(List<String> arguments) async {
  await flutter_launcher_icons.createIconsFromArguments(arguments);
  // flutter_launcher_icons 0.14.4 writes the name of the icon into every build
  // setting of the Xcode project whose name has ASSETCATALOG. This one takes
  // YES or NO.
  final project = File(_project);
  final text = project.readAsStringSync();
  final fixed = text.replaceAll(
    RegExp('$_setting = (?!YES;|NO;)[^;]*;'),
    '$_setting = YES;',
  );
  if (fixed != text) project.writeAsStringSync(fixed);
}
