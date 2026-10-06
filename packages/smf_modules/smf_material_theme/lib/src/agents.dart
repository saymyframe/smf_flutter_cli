import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the theme: where its file creates the two themes, how to
/// change their colours and what they share by hand, and what a change
/// must keep for the theme role.
final String agentNote = '''
- `_themeOf` in `${ThemeRole.appThemeFile}` creates both themes: a Material 3 `ThemeData` whose colours `ColorScheme.fromSeed` derives from `seedColor`. Change `seedColor` for other colours.
- Give that `ThemeData` what both themes share, such as the typography or the theme of a component. For what differs between the two, use the `brightness` that `_themeOf` gets.
- Keep `brightness: brightness` in the colour scheme: `${ThemeRole.createLightTheme.name}(context)` must return a light theme and `${ThemeRole.createDarkTheme.name}(context)` a dark one.
''';
