import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/readme.dart';

/// The heading of the section of the module in the guide for coding agents
/// of the app: that of its section in the README.
const String agentHeading = readmeHeading;

/// The note of the module in the guide for coding agents: the placeholder
/// of the options, who writes them, and what the start-up of Firebase asks
/// of the code and of the tests of the app.
final String agentNote = '''
- `${AppEntryRole.bootstrap.name}()` initializes Firebase with `DefaultFirebaseOptions` of `lib/firebase_options.dart`. That file is a placeholder until `flutterfire configure` writes it, and the app stops at start-up with an `UnsupportedError` until then. Do not write it by hand.
- `flutterfire configure` needs a Firebase account and someone to choose the project: run it only when asked, with the command of the section $readmeHeading of `${AppEntryRole.readmeFile}`.
- A test that runs `${AppEntryRole.main.name}()` or `${AppEntryRole.bootstrap.name}()` starts Firebase, which needs the options of `flutterfire configure` and a mock of its platform side. Prefer a test of a widget, which needs neither.
''';
