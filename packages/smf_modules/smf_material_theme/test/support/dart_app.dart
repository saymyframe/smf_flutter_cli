import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// The colours of a colour scheme of Flutter 3.44 that the file of the
/// themes sets or reads, but for the colour of an error, which it reads and
/// leaves to `ColorScheme.fromSeed`.
const schemeColors = [
  'primary',
  'onPrimary',
  'primaryContainer',
  'onPrimaryContainer',
  'secondary',
  'onSecondary',
  'secondaryContainer',
  'onSecondaryContainer',
  'tertiary',
  'onTertiary',
  'tertiaryContainer',
  'onTertiaryContainer',
  'surface',
  'onSurface',
  'onSurfaceVariant',
  'surfaceContainerLowest',
  'surfaceContainerLow',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'outline',
  'outlineVariant',
  'inverseSurface',
  'onInverseSurface',
  'surfaceTint',
];

/// The text styles of a text theme of Flutter, from the largest.
const textStyles = [
  'displayLarge',
  'displayMedium',
  'displaySmall',
  'headlineLarge',
  'headlineMedium',
  'headlineSmall',
  'titleLarge',
  'titleMedium',
  'titleSmall',
  'bodyLarge',
  'bodyMedium',
  'bodySmall',
  'labelLarge',
  'labelMedium',
  'labelSmall',
];

/// [each] for every item of [names], one below the other.
String _forEach(Iterable<String> names, String Function(String name) each) =>
    names.map(each).join('\n');

/// A stand-in for what the file of the themes uses of Flutter's painting
/// and widgets libraries, which its material and its cupertino library
/// both export, with the signatures of Flutter 3.44: colours, sizes,
/// shapes, a text style, and a property or a colour that has a value for
/// each state of a widget.
const _widgets = r'''
enum Brightness { dark, light }

enum Clip { none, hardEdge, antiAlias, antiAliasWithSaveLayer }

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

mixin WidgetStatesConstraint {
  bool isSatisfiedBy(Set<WidgetState> states);
}

enum WidgetState with WidgetStatesConstraint {
  hovered,
  focused,
  pressed,
  dragged,
  selected,
  scrolledUnder,
  disabled,
  error;

  static const WidgetStatesConstraint any = _AnyWidgetStates();

  @override
  bool isSatisfiedBy(Set<WidgetState> states) => states.contains(this);
}

class _AnyWidgetStates with WidgetStatesConstraint {
  const _AnyWidgetStates();

  @override
  bool isSatisfiedBy(Set<WidgetState> states) => true;
}

class Color {
  const Color(this.value);

  final int value;

  /// This colour with the opacity [alpha], from 0 to 1.
  Color withValues({double? alpha}) => alpha == null
      ? this
      : Color((value & 0x00FFFFFF) | ((alpha * 255).round() << 24));
}

class FontWeight {
  const FontWeight._(this.value);

  final int value;

  static const FontWeight w400 = FontWeight._(400);
  static const FontWeight w500 = FontWeight._(500);
  static const FontWeight w600 = FontWeight._(600);
}

class Size {
  const Size(this.width, this.height);

  final double width;
  final double height;
}

class BoxConstraints {
  const BoxConstraints({
    this.minWidth = 0.0,
    this.maxWidth = double.infinity,
    this.minHeight = 0.0,
    this.maxHeight = double.infinity,
  });

  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;
}

class Radius {
  const Radius.circular(this.x);

  final double x;

  static const Radius zero = Radius.circular(0);
}

abstract class BorderRadiusGeometry {
  const BorderRadiusGeometry();
}

class BorderRadius extends BorderRadiusGeometry {
  const BorderRadius.all(Radius radius) : top = radius, bottom = radius;

  BorderRadius.circular(double radius) : this.all(Radius.circular(radius));

  const BorderRadius.vertical({
    this.top = Radius.zero,
    this.bottom = Radius.zero,
  });

  final Radius top;
  final Radius bottom;

  static const BorderRadius zero = BorderRadius.all(Radius.zero);
}

abstract class EdgeInsetsGeometry {
  const EdgeInsetsGeometry();
}

class EdgeInsets extends EdgeInsetsGeometry {
  const EdgeInsets.only({this.left = 0.0, this.top = 0.0});

  const EdgeInsets.symmetric({double vertical = 0.0, double horizontal = 0.0})
    : left = horizontal,
      top = vertical;

  final double left;
  final double top;

  static const EdgeInsets zero = EdgeInsets.only();
}

class BorderSide {
  const BorderSide({this.color = const Color(0xFF000000), this.width = 1.0});

  final Color color;
  final double width;

  static const BorderSide none = BorderSide(width: 0.0);
}

abstract class ShapeBorder {
  const ShapeBorder();
}

abstract class OutlinedBorder extends ShapeBorder {
  const OutlinedBorder({this.side = BorderSide.none});

  final BorderSide side;
}

class RoundedRectangleBorder extends OutlinedBorder {
  const RoundedRectangleBorder({
    super.side,
    this.borderRadius = BorderRadius.zero,
  });

  final BorderRadiusGeometry borderRadius;
}

class TextStyle {
  const TextStyle({
    this.inherit = true,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    this.height,
    this.fontFamily,
  });

  final bool inherit;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? letterSpacing;
  final double? height;
  final String? fontFamily;

  TextStyle copyWith({
    bool? inherit,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    String? fontFamily,
  }) => TextStyle(
    inherit: inherit ?? this.inherit,
    color: color ?? this.color,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    height: height ?? this.height,
    fontFamily: fontFamily ?? this.fontFamily,
  );

  /// This style with what [other] sets.
  TextStyle merge(TextStyle? other) => other == null
      ? this
      : copyWith(
          color: other.color,
          fontSize: other.fontSize,
          fontWeight: other.fontWeight,
          letterSpacing: other.letterSpacing,
          height: other.height,
          fontFamily: other.fontFamily,
        );
}

class IconThemeData {
  const IconThemeData({this.size, this.color});

  final double? size;
  final Color? color;
}

typedef WidgetStateMap<T> = Map<WidgetStatesConstraint, T>;

abstract class WidgetStateProperty<T> {
  const factory WidgetStateProperty.fromMap(WidgetStateMap<T> map) =
      WidgetStateMapper<T>;

  T resolve(Set<WidgetState> states);

  /// What [value] is for [states]: itself, unless it has a value for each
  /// state of a widget.
  static T resolveAs<T>(T value, Set<WidgetState> states) =>
      value is WidgetStateProperty<T> ? value.resolve(states) : value;
}

class WidgetStateMapper<T> implements WidgetStateProperty<T> {
  const WidgetStateMapper(this._map);

  final WidgetStateMap<T> _map;

  @override
  T resolve(Set<WidgetState> states) {
    for (final entry in _map.entries) {
      if (entry.key.isSatisfiedBy(states)) return entry.value;
    }
    throw ArgumentError('No entry of the map is for $states.');
  }
}

abstract class WidgetStateColor extends Color
    implements WidgetStateProperty<Color> {
  const WidgetStateColor(super.value);

  const factory WidgetStateColor.fromMap(WidgetStateMap<Color> map) =
      _WidgetStateColorMapper;
}

/// As a colour, it is the colour of a widget in no state.
class _WidgetStateColorMapper extends WidgetStateMapper<Color>
    implements WidgetStateColor {
  const _WidgetStateColorMapper(super.map);

  @override
  int get value => resolve(const {}).value;

  @override
  Color withValues({double? alpha}) =>
      resolve(const {}).withValues(alpha: alpha);
}

abstract class PageTransitionsBuilder {
  const PageTransitionsBuilder();
}

abstract class BuildContext {}
''';

/// A stand-in for what the file of the themes uses of Flutter's cupertino
/// library: the page transition of iOS.
const _cupertino = '''
import 'widgets.dart';

export 'widgets.dart';

class CupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  const CupertinoPageTransitionsBuilder();
}
''';

/// A stand-in for the part of Flutter's material library that the file of
/// the themes uses, with the signatures of Flutter 3.44: a colour scheme
/// from a seed, a text theme, the themes of the components, and a theme,
/// which is of Material 3 and of the brightness of its colour scheme unless
/// it is told otherwise.
///
/// A colour scheme of Flutter derives each colour from its seed and does
/// not keep the seed. The one here keeps it, in `seed`, so that a test can
/// tell which colour a theme was derived from, and has the seed for every
/// colour that nothing set; `set` has the colours that a copy set, by name.
/// The colour of an error is the one that Flutter gives a scheme of each
/// brightness, whatever its seed.
/// As in Flutter, a theme applies its font to its text styles, and what
/// its text theme sets goes over them. What the themes look like is for
/// the tests of a running app.
final _material = '''
import 'widgets.dart';

export 'widgets.dart';

enum DynamicSchemeVariant {
  tonalSpot,
  fidelity,
  monochrome,
  neutral,
  vibrant,
  expressive,
  content,
  rainbow,
  fruitSalad,
}

enum SnackBarBehavior { fixed, floating }

abstract final class Colors {
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
}

class ColorScheme {
  const ColorScheme._(this.seed, this.brightness, this.set);

  factory ColorScheme.fromSeed({
    required Color seedColor,
    Brightness brightness = Brightness.light,
    DynamicSchemeVariant dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot,
  }) => ColorScheme._(seedColor, brightness, const {});

  /// The colour that the scheme was derived from.
  final Color seed;

  final Brightness brightness;

  /// The colours that a copy of the scheme set, by name.
  final Map<String, Color> set;

${_forEach(schemeColors, (name) => "  Color get $name => set['$name'] ?? seed;")}

  /// The colour of an error, which the file of the themes reads and does
  /// not set.
  Color get error => switch (brightness) {
    Brightness.light => const Color(0xFFBA1A1A),
    Brightness.dark => const Color(0xFFFFB4AB),
  };

  ColorScheme copyWith({
    Brightness? brightness,
${_forEach(schemeColors, (name) => '    Color? $name,')}
  }) => ColorScheme._(seed, brightness ?? this.brightness, {
    ...set,
${_forEach(schemeColors, (name) => "    if ($name != null) '$name': $name,")}
  });
}

class TextTheme {
  const TextTheme({
${_forEach(textStyles, (name) => '    this.$name,')}
  });

${_forEach(textStyles, (name) => '  final TextStyle? $name;')}

  TextTheme copyWith({
${_forEach(textStyles, (name) => '    TextStyle? $name,')}
  }) => TextTheme(
${_forEach(textStyles, (name) => '    $name: $name ?? this.$name,')}
  );

  TextTheme apply({String? fontFamily}) => TextTheme(
${_forEach(textStyles, (name) => '    $name: $name?.copyWith(fontFamily: fontFamily),')}
  );

  /// This text theme with what the styles of [other] set.
  TextTheme merge(TextTheme? other) => other == null
      ? this
      : TextTheme(
${_forEach(textStyles, (name) => '          $name: $name?.merge(other.$name) ?? other.$name,')}
        );
}

class PageTransitionsTheme {
  const PageTransitionsTheme({this.builders = const {}});

  final Map<TargetPlatform, PageTransitionsBuilder> builders;
}

class FadeForwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeForwardsPageTransitionsBuilder({this.backgroundColor});

  final Color? backgroundColor;
}

class AppBarThemeData {
  const AppBarThemeData({
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.scrolledUnderElevation,
    this.centerTitle,
    this.titleTextStyle,
  });

  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final double? scrolledUnderElevation;
  final bool? centerTitle;
  final TextStyle? titleTextStyle;
}

class NavigationBarThemeData {
  const NavigationBarThemeData({
    this.height,
    this.backgroundColor,
    this.elevation,
    this.indicatorColor,
    this.labelTextStyle,
    this.iconTheme,
  });

  final double? height;
  final Color? backgroundColor;
  final double? elevation;
  final Color? indicatorColor;
  final WidgetStateProperty<TextStyle?>? labelTextStyle;
  final WidgetStateProperty<IconThemeData?>? iconTheme;
}

class CardThemeData {
  const CardThemeData({
    this.clipBehavior,
    this.color,
    this.elevation,
    this.margin,
    this.shape,
  });

  final Clip? clipBehavior;
  final Color? color;
  final double? elevation;
  final EdgeInsetsGeometry? margin;
  final ShapeBorder? shape;
}

class ButtonStyle {
  const ButtonStyle({this.textStyle});

  final TextStyle? textStyle;
}

abstract final class FilledButton {
  static ButtonStyle styleFrom({
    TextStyle? textStyle,
    Size? minimumSize,
    OutlinedBorder? shape,
  }) => ButtonStyle(textStyle: textStyle);
}

abstract final class TextButton {
  static ButtonStyle styleFrom({Color? foregroundColor, TextStyle? textStyle}) =>
      ButtonStyle(textStyle: textStyle);
}

abstract final class SegmentedButton<T> {
  static ButtonStyle styleFrom({
    Color? foregroundColor,
    Color? selectedForegroundColor,
    Color? selectedBackgroundColor,
    TextStyle? textStyle,
    Size? minimumSize,
    BorderSide? side,
    OutlinedBorder? shape,
  }) => ButtonStyle(textStyle: textStyle);
}

class FilledButtonThemeData {
  const FilledButtonThemeData({this.style});

  final ButtonStyle? style;
}

class TextButtonThemeData {
  const TextButtonThemeData({this.style});

  final ButtonStyle? style;
}

class SegmentedButtonThemeData {
  const SegmentedButtonThemeData({this.style});

  final ButtonStyle? style;
}

abstract class InputBorder extends ShapeBorder {
  const InputBorder({this.borderSide = BorderSide.none});

  final BorderSide borderSide;

  bool get isOutline;
}

class OutlineInputBorder extends InputBorder {
  const OutlineInputBorder({
    super.borderSide = const BorderSide(),
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    this.gapPadding = 4.0,
  });

  final BorderRadius borderRadius;
  final double gapPadding;

  @override
  bool get isOutline => true;

  OutlineInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => OutlineInputBorder(
    borderSide: borderSide ?? this.borderSide,
    borderRadius: borderRadius ?? this.borderRadius,
    gapPadding: gapPadding ?? this.gapPadding,
  );
}

class InputDecorationThemeData {
  const InputDecorationThemeData({
    this.errorStyle,
    this.errorMaxLines,
    this.contentPadding,
    this.prefixIconColor,
    this.prefixIconConstraints,
    this.suffixIconColor,
    this.suffixIconConstraints,
    this.filled = false,
    this.fillColor,
    this.errorBorder,
    this.focusedBorder,
    this.focusedErrorBorder,
    this.disabledBorder,
    this.enabledBorder,
    this.border,
  });

  final TextStyle? errorStyle;
  final int? errorMaxLines;
  final EdgeInsetsGeometry? contentPadding;
  final Color? prefixIconColor;
  final BoxConstraints? prefixIconConstraints;
  final Color? suffixIconColor;
  final BoxConstraints? suffixIconConstraints;
  final bool filled;
  final Color? fillColor;
  final InputBorder? errorBorder;
  final InputBorder? focusedBorder;
  final InputBorder? focusedErrorBorder;
  final InputBorder? disabledBorder;
  final InputBorder? enabledBorder;
  final InputBorder? border;
}

class ListTileThemeData {
  const ListTileThemeData({
    this.iconColor,
    this.titleTextStyle,
    this.contentPadding,
  });

  final Color? iconColor;
  final TextStyle? titleTextStyle;
  final EdgeInsetsGeometry? contentPadding;
}

class DividerThemeData {
  const DividerThemeData({this.color, this.space, this.thickness});

  final Color? color;
  final double? space;
  final double? thickness;
}

class BottomSheetThemeData {
  const BottomSheetThemeData({
    this.backgroundColor,
    this.shape,
    this.showDragHandle,
  });

  final Color? backgroundColor;
  final ShapeBorder? shape;
  final bool? showDragHandle;
}

class DialogThemeData {
  const DialogThemeData({this.backgroundColor, this.shape});

  final Color? backgroundColor;
  final ShapeBorder? shape;
}

class SnackBarThemeData {
  const SnackBarThemeData({
    this.backgroundColor,
    this.contentTextStyle,
    this.shape,
    this.behavior,
  });

  final Color? backgroundColor;
  final TextStyle? contentTextStyle;
  final ShapeBorder? shape;
  final SnackBarBehavior? behavior;
}

class ThemeData {
  factory ThemeData({
    PageTransitionsTheme? pageTransitionsTheme,
    bool? useMaterial3,
    ColorScheme? colorScheme,
    Brightness? brightness,
    Color? scaffoldBackgroundColor,
    String? fontFamily,
    TextTheme? textTheme,
    // An `AppBarThemeData`, or the widget `AppBarTheme` of older code.
    Object? appBarTheme,
    BottomSheetThemeData? bottomSheetTheme,
    CardThemeData? cardTheme,
    DialogThemeData? dialogTheme,
    DividerThemeData? dividerTheme,
    FilledButtonThemeData? filledButtonTheme,
    // An `InputDecorationThemeData`, or the widget `InputDecorationTheme`
    // of older code.
    Object? inputDecorationTheme,
    ListTileThemeData? listTileTheme,
    NavigationBarThemeData? navigationBarTheme,
    SegmentedButtonThemeData? segmentedButtonTheme,
    SnackBarThemeData? snackBarTheme,
    TextButtonThemeData? textButtonTheme,
  }) => ThemeData._(
    colorScheme:
        colorScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: brightness ?? Brightness.light,
        ),
    useMaterial3: useMaterial3 ?? true,
    textTheme: const TextTheme(
${_forEach(textStyles, (name) => '      $name: TextStyle(),')}
    ).apply(fontFamily: fontFamily).merge(textTheme),
    filledButtonTheme: filledButtonTheme ?? const FilledButtonThemeData(),
    inputDecorationTheme:
        inputDecorationTheme as InputDecorationThemeData? ??
        const InputDecorationThemeData(),
    textButtonTheme: textButtonTheme ?? const TextButtonThemeData(),
    segmentedButtonTheme:
        segmentedButtonTheme ?? const SegmentedButtonThemeData(),
  );

  const ThemeData._({
    required this.colorScheme,
    required this.useMaterial3,
    required this.textTheme,
    required this.filledButtonTheme,
    required this.inputDecorationTheme,
    required this.textButtonTheme,
    required this.segmentedButtonTheme,
  });

  final ColorScheme colorScheme;

  final bool useMaterial3;

  final TextTheme textTheme;

  final FilledButtonThemeData filledButtonTheme;

  final InputDecorationThemeData inputDecorationTheme;

  final TextButtonThemeData textButtonTheme;

  final SegmentedButtonThemeData segmentedButtonTheme;

  Brightness get brightness => colorScheme.brightness;
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with a stand-in for the material library of Flutter, and for
/// what the file of the themes takes from its cupertino library, so that
/// the file of the themes can be analyzed and run with the Dart SDK alone:
/// the tests of the package run without the Flutter SDK.
///
/// The other files of the app need more of Flutter, so the analyzer checks
/// the files of the owners it is given, and a script that runs the app
/// imports none of the others. The real library runs in the tests of the
/// generated apps. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync('smf_material_theme_');
    final files = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final file in files) {
      write('app/${file.path}', file.text);
    }
    write('flutter/lib/widgets.dart', _widgets);
    write('flutter/lib/cupertino.dart', _cupertino);
    write('flutter/lib/material.dart', _material);
    write('app/pubspec.yaml', 'name: contract_app\n');
    // The stand-in is in the language of the app too.
    final languageVersion = _languageVersionOf(app);
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': languageVersion,
            },
        ],
      }),
    );
    return DartApp._(root, files);
  }

  final Directory _root;
  final List<RenderedFile> _files;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The errors and warnings that the analyzer finds in the files of
  /// [owners], each with the path of its file.
  Future<List<String>> analysisProblems(Set<ContributionOrigin> owners) async {
    final appPath = _appPath;
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in _files) {
        if (!owners.contains(file.owner)) continue;
        // The analyzer takes only the paths of the system, such as
        // C:\app\lib\main.dart on Windows.
        final path = Uri.directory(appPath).resolve(file.path).toFilePath();
        final result = await collection
            .contextFor(path)
            .currentSession
            .getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          problems.add('${file.path}: cannot be resolved: $result');
          continue;
        }
        for (final diagnostic in result.diagnostics) {
          if (diagnostic.severity == Severity.info) continue;
          problems.add(
            '${file.path}:${result.lineInfo.getLocation(diagnostic.offset)}: '
            '${diagnostic.message}',
          );
        }
      }
      return problems;
    } finally {
      await collection.dispose();
    }
  }

  /// Runs [script], a Dart library whose `main(List<String>, SendPort)`
  /// imports the app by its package, `contract_app`, in an isolate of its
  /// own, and returns the first message it sends.
  ///
  /// Throws a [StateError] with the error if the isolate fails, or if it
  /// sends nothing in time.
  Future<Object?> run(String script) async {
    final file = File('${_root.path}/check.dart')..writeAsStringSync(script);
    final result = Completer<Object?>();
    void fail(String message) {
      if (!result.isCompleted) result.completeError(StateError(message));
    }

    final messages = ReceivePort()
      ..listen((message) {
        if (!result.isCompleted) result.complete(message);
      });
    final errors = ReceivePort()
      ..listen((error) => fail('The script failed: $error'));
    // The isolate sends its message before it ends, so an end that comes
    // first means that it sent none.
    final exits = ReceivePort()
      ..listen((_) => fail('The script ended without a message.'));
    Isolate? isolate;
    try {
      isolate = await Isolate.spawnUri(
        file.uri,
        const [],
        messages.sendPort,
        onError: errors.sendPort,
        onExit: exits.sendPort,
        packageConfig: Uri.file('$_appPath/.dart_tool/package_config.json'),
      );
      return await result.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError('The script sent nothing in time.'),
      );
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
      exits.close();
    }
  }

  /// Deletes the directory of the app.
  void delete() => _root.deleteSync(recursive: true);
}

/// The language version of [app]: that of the lower bound of the SDK
/// constraint of its pubspec, such as 3.12 for `^3.12.0`.
String _languageVersionOf(RenderedApp app) {
  final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
  final sdk = (pubspec['environment'] as YamlMap)['sdk'] as String;
  final version = RegExp(r'(\d+)\.(\d+)').firstMatch(sdk)!;
  return '${version[1]}.${version[2]}';
}
