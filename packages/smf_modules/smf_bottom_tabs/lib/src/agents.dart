import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the layout: what its shell does with the destinations, where
/// its bar takes its look from and what a tab says to a screen reader.
final String agentNote = '''
- `${LayoutRole.appShell.name}` draws the bar itself, as `_TabBar` with a `_Tab` for each destination, and hides it while the app has fewer than two destinations. Keep to five destinations, the most that fit the bar on a phone.
- The bar is not the navigation bar of Material, so the theme of that bar does not change it. It reads its colours from the `colorScheme` of the theme: the icon and the label of the selected tab are in `secondary`, those of the others in `onSurfaceVariant`.
- A `_Tab` is one node for a screen reader, with the label of its destination. What you add to a tab, such as a badge, is not read unless the `Semantics` of the tab says it.
''';
