// Makes the launcher icons of the app from assets/branding/, as
// flutter_launcher_icons.yaml says. Run it again after you change an image:
//
//     dart tool/update_app_icon.dart
import 'dart:io';

import 'package:flutter_launcher_icons/main.dart' as flutter_launcher_icons;

const _project = '{{{xcode_project}}}';
const _setting = 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS';

Future<void> main(List<String> arguments) async {
  final line = RegExp('$_setting = ([^;]*);');
  final project = File(_project);
  final before = [
    for (final match in line.allMatches(project.readAsStringSync())) match[1],
  ];
  await flutter_launcher_icons.createIconsFromArguments(arguments);
  // flutter_launcher_icons 0.14.4 writes the name of the icon into every build
  // setting of the Xcode project whose name has ASSETCATALOG. This one takes
  // YES or NO, so each line gets its value back, or YES after an earlier run
  // of the tool.
  final text = project.readAsStringSync();
  var index = 0;
  final fixed = text.replaceAllMapped(line, (_) {
    final value = before.elementAtOrNull(index++);
    return '$_setting = ${value == 'NO' ? 'NO' : 'YES'};';
  });
  if (fixed != text) project.writeAsStringSync(fixed);
}
