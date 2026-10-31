// Points the build phase for Crashlytics that flutterfire adds to the Xcode
// project at the upload script of Crashlytics where Flutter puts it, so that
// flutter build ipa finds it. See the section Crashlytics of README.md.
//
// flutterfire writes the phase again in each of its runs, so
// tool/configure_firebase.dart runs this script after it. After
// flutterfire configure by hand, run it yourself:
//
//     dart {{{script_path}}}
//
// flutterfire changes the Xcode project only on macOS, so elsewhere this script
// does nothing.

import 'dart:convert';
import 'dart:io';

/// The Xcode project, from the directory of the app.
const _project = '{{{xcode_project}}}';

/// Where the phase of flutterfire looks for the upload script: the build
/// directory of Xcode, which is another one for the archive of
/// flutter build ipa.
const _inBuildDirectory = r'{{{script_in_build_directory}}}';

/// Where the upload script is, in build/ios/SourcePackages of the app.
const _inApp = r'{{{script_in_app}}}';

void main() {
  if (!Platform.isMacOS) return;
  final script = File.fromUri(Platform.script).resolveSymbolicLinksSync();
  final app = File(script).parent.parent.parent;
  final file = File('${app.path}/$_project');
  // Byte for byte, whatever the encoding of the file and the locale.
  final text = file.existsSync() ? latin1.decode(file.readAsBytesSync()) : '';
  final fixed = text.replaceAll(_inBuildDirectory, _inApp);
  if (fixed == text) {
    stdout.writeln('Nothing to fix in $_project');
  } else {
    file.writeAsBytesSync(latin1.encode(fixed));
    stdout.writeln('Fixed the Crashlytics phase in $_project');
  }
}
