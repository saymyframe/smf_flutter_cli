import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

/// The registry of the tests: flutter_core, a router, the texts of the app
/// with the preferences that their role requires, and a module that fills
/// every socket of the app entry.
///
/// The providers of the roles are those of this file: the package of
/// flutter_core depends on no module, since the other modules render the
/// apps of their tests with it.
ModuleRegistry testRegistry() => ModuleRegistry(const [
      FlutterCoreModule(),
      TestRouterModule(),
      TestTextsModule(),
      TestPreferencesModule(),
      EverySocketModule(),
    ]);

/// Renders the app of [modules] with the contract harness and returns the
/// result, which has no errors.
Future<ContractResult> renderedApp(List<ModuleId> modules) async {
  final result = await ContractHarness(testRegistry()).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  final errors = result.errors;
  if (errors.isNotEmpty || result.app == null) {
    throw StateError('The app of $modules has errors: ${errors.join('\n')}');
  }
  return result;
}

/// A router for the tests: `createAppRouter()` returns a router that shows
/// the fallback start screen, calls the observer factories of its navigator,
/// and tells the screen listeners about the fallback start screen once.
final class TestRouterModule extends SmfModule {
  /// Creates the module.
  const TestRouterModule();

  /// The id of the module.
  static const id = ModuleId('test_router');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A router for the tests',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(routerRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('test_router', {
            RouterRole.appRouterFactoryFile: '''
import 'package:flutter/material.dart';

import '../app/fallback_start_screen.dart';
import 'app_router.dart';
import 'navigation.dart';

/// Creates the router of the app, which shows the fallback start screen.
AppRouter createAppRouter() => _TestRouter();

final class _TestRouter implements AppRouter {
  @override
  late final RouterConfig<Object> config =
      RouterConfig(routerDelegate: _TestDelegate());

  @override
  AppNavigator navigatorOf(BuildContext context) =>
      throw UnsupportedError('The test router does not navigate.');
}

final class _TestDelegate extends RouterDelegate<Object> with ChangeNotifier {
  final List<NavigatorObserver> _observers = [
    for (final create in <NavigatorObserver Function()>[
{{{${RouterRole.observers.tag}}}}
    ])
      create(),
  ];

  final _screenListeners = <void Function(String? route, String location)>[
{{{${RouterRole.screenListeners.tag}}}}
  ];

  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    // The fallback start screen, the only screen, is no route of a module.
    if (!_shown) {
      _shown = true;
      for (final listener in _screenListeners) {
        listener(null, '/');
      }
    }
    return Navigator(
      observers: _observers,
      pages: const [MaterialPage<Object?>(child: FallbackStartScreen())],
      onDidRemovePage: (page) {},
    );
  }

  @override
  Future<bool> popRoute() async => false;

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
''',
          }),
        ),
      ];
}

/// A provider of the localization role for the tests, which keeps the texts
/// of the app in one Dart file: a getter for each text, which returns the
/// text in the language of the texts, among the languages of the app, or in
/// English. Its texts take their language from the locale of the context,
/// so the root of the app gets no delegate for them.
final class TestTextsModule extends SmfModule {
  /// Creates the module.
  const TestTextsModule();

  /// The id of the module.
  static const id = ModuleId('test_texts');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The texts of the app for the tests',
        kind: ModuleKinds.infrastructure,
        providers: [_TestTextsProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('test_texts', {
            LocalizationRole.textsFile: '''
import 'package:flutter/widgets.dart';

/// The texts of the app in the language of a context: `context.l10n`.
extension AppTexts on BuildContext {
  /// The texts of the app in the language of this context.
  TestTexts get l10n => TestTexts(Localizations.localeOf(this).languageCode);
}

/// The texts of the app in one language.
class TestTexts {
  /// Creates the texts in the language of the code [language].
  const TestTexts(this.language);

  /// The code of the language of the texts, such as `uk`.
  final String language;

{{{getters}}}
}
''',
          }),
        ),
      ];
}

final class _TestTextsProvider extends RoleProvider<TextsData> {
  const _TestTextsProvider();

  @override
  Role<TextsData> get role => localizationRole;

  @override
  RoleOutput render(RoleHookInput<TextsData> input) {
    final locales = localizationRole.localesIn(input);
    return RoleOutput(
      vars: {
        'getters': Fragment(
          [
            for (final text in localizationRole.textsIn(input))
              _getterOf(text, locales),
          ].join('\n\n'),
        ),
      },
    );
  }

  /// The getter of [text] in the class of the texts, which returns its
  /// translation into the language of the texts, among [locales], or its
  /// English text.
  String _getterOf(AppText text, List<String> locales) {
    final translations = {
      for (final language in locales)
        if (text.text.translations[language] case final translation?)
          language: SmfNames.dartString(translation),
    };
    return [
      '  /// The $text.',
      '  String get ${text.getter} => switch (language) {',
      for (final MapEntry(key: language, value: translation)
          in translations.entries)
        "        '$language' => $translation,",
      '        _ => ${SmfNames.dartString(text.text.en)},',
      '      };',
    ].join('\n');
  }
}

/// A provider of the preferences role for the tests, which the localization
/// role requires: its preferences keep the settings in memory.
final class TestPreferencesModule extends SmfModule {
  /// Creates the module.
  const TestPreferencesModule();

  /// The id of the module.
  static const id = ModuleId('test_preferences');

  static const _file = ImportRef.app(
    'core/preferences/test_app_preferences.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Preferences in memory for the tests',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(preferencesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('test_preferences', {
            'lib/core/preferences/test_app_preferences.dart': '''
import 'app_preferences.dart';

/// Opens the preferences of the tests, which have nothing saved.
AppPreferences createTestAppPreferences() => TestAppPreferences();

/// The preferences of the tests, in memory.
final class TestAppPreferences implements AppPreferences {
  final Map<String, Object> _values = {};

  T? _read<T>(String key) => switch (_values[key]) {
        final T value => value,
        _ => null,
      };

  @override
  String? getString(String key) => _read<String>(key);

  @override
  bool? getBool(String key) => _read<bool>(key);

  @override
  int? getInt(String key) => _read<int>(key);

  @override
  double? getDouble(String key) => _read<double>(key);

  @override
  List<String>? getStringList(String key) => _read<List<String>>(key);

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setDouble(String key, double value) async =>
      _values[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = List.of(value);

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
''',
          }),
        ),
        preferencesRole.data(
          const RoleImplementation(
            type: TypeRef('TestAppPreferences', import: _file),
            create: FactoryRef('createTestAppPreferences', import: _file),
          ),
        ),
      ];
}

/// A module that puts something into every socket of the app entry, as
/// other modules would.
final class EverySocketModule extends SmfModule {
  /// Creates the module.
  const EverySocketModule();

  /// The id of the module.
  static const id = ModuleId('every_socket');

  /// The theme mode that the module gives the root of the app, an
  /// expression that reads the context of the root.
  static const themeMode =
      'MediaQuery.platformBrightnessOf(context) == Brightness.dark '
      '? ThemeMode.dark : ThemeMode.light';

  /// The locale that the module gives the root of the app, an expression
  /// that reads the context of the root.
  static const locale = 'Localizations.maybeLocaleOf(context)';

  static const _foundation = ImportRef('package:flutter/foundation.dart');
  static const _material = ImportRef('package:flutter/material.dart');
  static const _widgets = ImportRef('package:flutter/widgets.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Something in every socket of the app entry',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        // The phases of start-up, in the reverse of their order.
        for (final (socket, phase) in [
          (AppEntryRole.bootstrapLate, 'late'),
          (AppEntryRole.bootstrapDi, 'di'),
          (AppEntryRole.bootstrapPlatform, 'platform'),
          (AppEntryRole.bootstrapEarly, 'early'),
        ])
          SocketContribution.code(
            socket,
            Fragment("debugPrint('$phase');", imports: const [_foundation]),
          ),
        const SocketContribution.code(
          AppEntryRole.topLevel,
          Fragment(
            "@pragma('vm:entry-point')\n"
            'Future<void> onBackgroundMessage() async {}',
          ),
        ),
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap('RepaintBoundary(child: ', ')', imports: [_widgets]),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'supportedLocales',
          Fragment("Locale('en')", imports: [_widgets]),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'locale',
          Fragment(locale, imports: [_widgets]),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'themeMode',
          Fragment(themeMode, imports: [_material]),
        ),
        const SocketContribution.wrap(
          AppEntryRole.appBuilder,
          Fragment.wrap(
            'MediaQuery.withNoTextScaling(child: ',
            ')',
            imports: [_widgets],
          ),
        ),
        AppEntryRole.iosDeploymentTarget.value('16.0'),
        AppEntryRole.androidManifestPermissions
            .key('android.permission.INTERNET'),
        AppEntryRole.androidManifestApplicationMeta.entry(
          'com.example.every_socket.KEY',
          const AndroidMetaData.value('every socket'),
        ),
        const SocketContribution.code(
          AppEntryRole.mainActivityIntentFilters,
          Fragment(
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.VIEW"/>\n'
            '                <category android:name="android.intent.category.DEFAULT"/>\n'
            '                <data android:scheme="everysocket"/>\n'
            '            </intent-filter>',
          ),
        ),
        AppEntryRole.infoPlist.entry(
          'UIBackgroundModes',
          const PlistStringArray(['fetch']),
        ),
        AppEntryRole.gradleSettingsPlugins.entry(
          'io.github.ben-manes.versions',
          '0.64.0',
        ),
        AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        AppEntryRole.gradleAppDependencies.entry(
          'androidx.annotation:annotation',
          '1.9.1',
        ),
        AppEntryRole.readmeSections.entry(
          'Every socket',
          'The app has something in every socket of its entry.',
        ),
        AppEntryRole.agentSections.entry(
          'Every socket',
          AgentNote('Leave what the sockets of `lib/bootstrap.dart` got.'),
        ),
      ];
}

/// A mason bundle named [name] with the text [files] by path.
MasonBundle bundleOf(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );
