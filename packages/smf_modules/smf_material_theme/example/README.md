# Generate a Flutter app with a light and a dark theme

`material_theme` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that gives the app a light and a dark Material 3 theme, with a palette and a font of their own. Choose it with `-m`, here with the start screen `home`, the settings screen `settings` and the tabs of `bottom_tabs`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m material_theme,home,settings,bottom_tabs --no-input
```

The app remembers the theme mode in its preferences, and its screens need a router, so `smf create` adds the modules that provide them:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding shared_preferences: the only provider of the preferences role, which material_theme requires.
Adding go_router: the only provider of the router role, which home requires.
```

The module writes `lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// The accent of the app, and the colour that `ColorScheme.fromSeed` derives
/// the colours from that [_schemeOf] does not set itself, such as those of
/// an error. The colours of the app are in [_schemeOf]: change them there
/// to give the app another look.
const Color seedColor = Color(0xFF15803D);

/// The deep green that the themes pair with [seedColor]: the primary colour
/// of the light theme, and the colour of what stands on the primary colour
/// of the dark one.
const Color _deepGreen = Color(0xFF0F3326);

/// The cream that goes with [_deepGreen]: the primary colour of the dark
/// theme, and the colour of what stands on the primary colour of the light
/// one.
const Color _cream = Color(0xFFF1F1E8);

/// The font of the app: the family that `pubspec.yaml` declares with the
/// files in `assets/fonts/geist/`, in the weights 400, 500 and 600. A text
/// of another weight gets the nearest of them. For another font, add its
/// files, declare its family in `pubspec.yaml` and name it here.
const String _fontFamily = 'Geist';

/// The light theme of the app.
///
/// The root of the app calls it each time it builds, so a change of this
/// file shows on a hot reload. [context] is the context of the root, above
/// its `MaterialApp`: it has neither the theme nor the localizations of the
/// app.
ThemeData createLightTheme(BuildContext context) => _themeOf(Brightness.light);

/// The dark theme of the app; see [createLightTheme].
ThemeData createDarkTheme(BuildContext context) => _themeOf(Brightness.dark);

/// The colours of [brightness]: those that `ColorScheme.fromSeed` derives
/// from [seedColor], with neutral surfaces, hairlines for borders, and the
/// deep green and the cream as the primary pair.
ColorScheme _schemeOf(Brightness brightness) {
  final seeded = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return switch (brightness) {
    Brightness.light => seeded.copyWith(
      primary: _deepGreen,
      onPrimary: _cream,
      primaryContainer: const Color(0xFFDDEDE3),
      onPrimaryContainer: _deepGreen,
      secondary: seedColor,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFDCFCE7),
      onSecondaryContainer: const Color(0xFF14532D),
      tertiary: const Color(0xFFB45309),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFEF3C7),
      onTertiaryContainer: const Color(0xFF78350F),
      surface: const Color(0xFFFAFAF9),
      onSurface: const Color(0xFF0C0A09),
      onSurfaceVariant: const Color(0xFF57534E),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF5F5F4),
      surfaceContainerHigh: const Color(0xFFEEEDEB),
      surfaceContainerHighest: const Color(0xFFE7E5E4),
      outline: const Color(0xFFA8A29E),
      outlineVariant: const Color(0xFFE7E5E4),
      inverseSurface: const Color(0xFF1C1917),
      onInverseSurface: const Color(0xFFFAFAF9),
      surfaceTint: Colors.transparent,
    ),
    Brightness.dark => seeded.copyWith(
      primary: _cream,
      onPrimary: _deepGreen,
      primaryContainer: const Color(0xFF143D2F),
      onPrimaryContainer: const Color(0xFFD9EFE2),
      secondary: const Color(0xFF4ADE80),
      onSecondary: const Color(0xFF052E16),
      secondaryContainer: const Color(0xFF133422),
      onSecondaryContainer: const Color(0xFFBBF7D0),
      tertiary: const Color(0xFFFBBF24),
      onTertiary: const Color(0xFF451A03),
      tertiaryContainer: const Color(0xFF3A2A0A),
      onTertiaryContainer: const Color(0xFFFDE68A),
      surface: const Color(0xFF0A0A0A),
      onSurface: const Color(0xFFEDEDED),
      onSurfaceVariant: const Color(0xFFA3A3A3),
      surfaceContainerLowest: const Color(0xFF060606),
      surfaceContainerLow: const Color(0xFF111111),
      surfaceContainer: const Color(0xFF161616),
      surfaceContainerHigh: const Color(0xFF1C1C1C),
      surfaceContainerHighest: const Color(0xFF262626),
      outline: const Color(0xFF525252),
      outlineVariant: const Color(0xFF262626),
      inverseSurface: const Color(0xFFEDEDED),
      onInverseSurface: const Color(0xFF0A0A0A),
      surfaceTint: Colors.transparent,
    ),
  };
}

/// The text styles of the app in its font, in the colours of [scheme]:
/// tight, heavy headlines and calm body text.
TextTheme _textThemeOf(ColorScheme scheme) {
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: _fontFamily,
  ).textTheme;
  TextStyle? style(
    TextStyle? from,
    FontWeight weight, {
    double? spacing,
    double? height,
  }) => from?.copyWith(
    fontWeight: weight,
    letterSpacing: spacing,
    height: height,
  );
  return base.copyWith(
    displayLarge: style(base.displayLarge, FontWeight.w600, spacing: -2.2),
    displayMedium: style(base.displayMedium, FontWeight.w600, spacing: -1.8),
    displaySmall: style(base.displaySmall, FontWeight.w600, spacing: -1.4),
    headlineLarge: style(base.headlineLarge, FontWeight.w600, spacing: -1.1),
    headlineMedium: style(base.headlineMedium, FontWeight.w600, spacing: -0.9),
    headlineSmall: style(base.headlineSmall, FontWeight.w600, spacing: -0.6),
    titleLarge: style(base.titleLarge, FontWeight.w600, spacing: -0.5),
    titleMedium: style(base.titleMedium, FontWeight.w600, spacing: -0.2),
    titleSmall: style(base.titleSmall, FontWeight.w600, spacing: -0.1),
    bodyLarge: style(
      base.bodyLarge,
      FontWeight.w400,
      spacing: -0.1,
      height: 1.5,
    ),
    bodyMedium: style(
      base.bodyMedium,
      FontWeight.w400,
      spacing: 0,
      height: 1.45,
    ),
    bodySmall: style(base.bodySmall, FontWeight.w400, spacing: 0, height: 1.4),
    labelLarge: style(base.labelLarge, FontWeight.w600, spacing: -0.1),
    labelMedium: style(base.labelMedium, FontWeight.w500, spacing: 0),
    labelSmall: style(base.labelSmall, FontWeight.w500, spacing: 0.1),
  );
}

/// The theme of [brightness]. What both themes of the app share goes here:
/// its colours, its font and text styles, and the look of its components.
ThemeData _themeOf(Brightness brightness) {
  final scheme = _schemeOf(brightness);
  final text = _textThemeOf(scheme);
  final hairline = BorderSide(color: scheme.outlineVariant);
  // The box of a text field, with the hairline around it.
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: hairline,
  );
  // An icon in a field keeps its colour when the field has a mistake, and
  // is as dim as the text of a field that is disabled.
  final fieldIcon = WidgetStateColor.fromMap({
    WidgetState.disabled: scheme.onSurface.withValues(alpha: 0.38),
    WidgetState.any: scheme.onSurfaceVariant,
  });
  // A box of 56 leaves 16 on each side of an icon, the padding of a field.
  const fieldIconBox = BoxConstraints(minWidth: 56, minHeight: 48);
  return ThemeData(
    colorScheme: scheme,
    fontFamily: _fontFamily,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    // The accent marks the selected destination of the main navigation.
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.fromMap({
        WidgetState.selected: text.labelMedium?.copyWith(
          color: scheme.secondary,
        ),
        WidgetState.any: text.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      }),
      iconTheme: WidgetStateProperty.fromMap({
        WidgetState.selected: IconThemeData(size: 24, color: scheme.secondary),
        WidgetState.any: IconThemeData(
          size: 24,
          color: scheme.onSurfaceVariant,
        ),
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: hairline,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        selectedForegroundColor: scheme.onSecondaryContainer,
        selectedBackgroundColor: scheme.secondaryContainer,
        side: hairline,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
        minimumSize: const Size(0, 44),
      ),
    ),
    // The line around a field tells of the focus and of a mistake. The text
    // of a field, its hint and its label are `bodyLarge` in the colours that
    // Material takes from the scheme.
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: field,
      enabledBorder: field,
      disabledBorder: field,
      focusedBorder: field.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: field.copyWith(borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: field.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      errorStyle: text.bodySmall?.copyWith(color: scheme.error),
      // The text of a mistake takes the lines that it needs.
      errorMaxLines: 5,
      prefixIconColor: fieldIcon,
      suffixIconColor: fieldIcon,
      prefixIconConstraints: fieldIconBox,
      suffixIconConstraints: fieldIconBox,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      titleTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
```

Change the colours in `_schemeOf` to give the app another look, and `_themeOf` to change what both themes share. The root `MaterialApp` of the app takes its `theme` and its `darkTheme` from the two functions.

The module also writes the files of the font into `assets/fonts/geist/`, with their licence, and declares the family `Geist` in `pubspec.yaml`, so the app loads no font from the network.

The app follows the device until the user selects a mode. The second tab of this app is Settings, and its entry Theme offers System, Light and Dark. The app shows the selected mode at once and starts in it the next time. Code of the app selects a mode with `appThemeMode.choose(ThemeMode.dark)`, and a widget reads the mode with `AppThemeModeScope.of(context)`. Both are in `lib/core/theme/theme_mode.dart`, which the theme role adds.

The documentation has more on [the material_theme module](https://doc.saymyframe.com/modules/material-theme).
