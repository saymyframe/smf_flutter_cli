import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/configure.dart';
import 'package:smf_firebase_core/src/readme.dart';

/// The heading of the section of the module in the guide for coding agents
/// of the app: that of its section in the README.
const String agentHeading = readmeHeading;

/// The note of the module in the guide for coding agents: the options of each
/// flavor, who writes them, and what the start-up of Firebase asks of the code
/// and of the tests of the app.
final String agentNote = '''
- `${AppEntryRole.bootstrap.name}()` initializes Firebase with `firebaseOptionsOfFlavor` of `lib/firebase_options_of_flavor.dart`, by the flavor of the build. ${_optionFiles()} are placeholders until `$configureScriptPath` writes them, and a build of such a flavor stops at start-up with an `UnsupportedError`. Do not write them by hand.
- `$configureScriptPath` needs a Firebase account and a project: run it only when asked, with the command of the section $readmeHeading of `${AppEntryRole.readmeFile}`. Do not run `flutterfire configure`, whose files no flavor reads.
- A test that runs `${AppEntryRole.main.name}()` or `${AppEntryRole.bootstrap.name}()` starts Firebase with the options of the flavor of the test, `${AppEntryRole.defaultFlavor.name}`, which needs a mock of its platform side. Prefer a test of a widget, which needs neither.
''';

/// The files of the options of the flavors in inline code, as a sentence
/// names them.
String _optionFiles() {
  final files = [
    for (final flavor in AppEntryRole.flavors)
      '`lib/firebase_options_${flavor.name}.dart`',
  ];
  return '${files.sublist(0, files.length - 1).join(', ')} and ${files.last}';
}
