import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the layout: what its shell does with the destinations.
final String agentNote = '''
- `${LayoutRole.appShell.name}` hides its `NavigationBar` while the app has fewer than two destinations. Keep to five destinations, the most that a navigation bar should have.
''';
