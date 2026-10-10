import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the theme: where its file creates the two themes, how to
/// change their colours, their font and what they share by hand, where a
/// text field takes its look from, and what a change must keep for the
/// theme role.
final String agentNote = '''
- `_themeOf` in `${ThemeRole.appThemeFile}` creates both themes: a Material 3 `ThemeData` with the colours of `_schemeOf`, the text styles of `_textThemeOf` and the themes of the components, such as `cardTheme` and `inputDecorationTheme`. Give that `ThemeData` what both themes share. For what differs between the two, use the `brightness` that `_themeOf` gets.
- A text field takes its border, its fill and its padding from `inputDecorationTheme`, in both themes. Give a field of a screen a decoration only for what that field alone has, such as its hint or an icon.
- `_schemeOf` has the colours of each theme. It sets most of them itself, and `ColorScheme.fromSeed` derives the others from `seedColor`. For another look, change the colours there. Keep the colour of what stands on a colour readable on it, such as `onPrimary` on `primary`.
- The font of the themes is the family `_fontFamily`, which `pubspec.yaml` declares with the files in `assets/fonts/geist/`, in the weights 400, 500 and 600. For another font, add its files, declare its family in `pubspec.yaml` and name it in `_fontFamily`. `assets/fonts/geist/OFL.txt` is the licence of the font, which the app bundles as an asset: keep it while the app has the font.
- Keep `brightness: brightness` in the colour scheme: `${ThemeRole.createLightTheme.name}(context)` must return a light theme and `${ThemeRole.createDarkTheme.name}(context)` a dark one.
''';
