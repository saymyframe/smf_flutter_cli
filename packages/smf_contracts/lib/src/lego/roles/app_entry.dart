import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

part 'app_entry_native.dart';

/// The app entry role; see [AppEntryRole].
const appEntryRole = AppEntryRole._();

/// The role of the app's entry point: `main()`, the start-up sequence and
/// the native project files.
///
/// Every app has exactly one provider, the scaffold module, which generates:
/// - `lib/main.dart`, whose `main()` calls
///   `WidgetsFlutterBinding.ensureInitialized()`, then awaits `bootstrap()`,
///   then calls `runApp()`;
/// - `lib/bootstrap.dart`, whose `Future<void> bootstrap()` runs the
///   start-up code of all modules and imports neither `material` nor
///   `cupertino`;
/// - [fallbackStartScreen], the screen of an app without a router;
/// - the Android and iOS projects.
///
/// The keyed and value sockets of the native files render complete,
/// indented lines, so their tags stand at the start of a line of their own,
/// like the tags of [PipelineSockets].
///
/// Unlike other roles, its sockets and symbols are open to every module
/// (see [openToAllModules]), so any module can take part in start-up.
final class AppEntryRole extends Role<NoDsl> {
  const AppEntryRole._();

  /// The path of the file with `main()`.
  static const mainFile = 'lib/main.dart';

  /// The path of the file with `bootstrap()`.
  static const bootstrapFile = 'lib/bootstrap.dart';

  /// The path of the file with [fallbackStartScreen].
  static const fallbackStartScreenFile =
      'lib/core/app/fallback_start_screen.dart';

  /// The screen an app shows when no router provides one, created as
  /// `const FallbackStartScreen()`; import it with
  /// [RequiredSymbol.importRef].
  static const fallbackStartScreen = RequiredClass(
    'FallbackStartScreen',
    path: fallbackStartScreenFile,
    constConstructor: true,
  );

  /// `Future<void> bootstrap()`, which runs the start-up code of all modules
  /// before the app starts.
  static const bootstrap = RequiredFunction(
    'bootstrap',
    path: bootstrapFile,
    returnType: 'Future<void>',
  );

  /// `Future<void> main()`, the entry point of the app.
  static const main = RequiredFunction(
    'main',
    path: mainFile,
    returnType: 'Future<void>',
  );

  /// Start-up code that runs first in `bootstrap()`, before any platform
  /// service is set up.
  static const bootstrapEarly = SocketRef<CodeSocket>.role(
    appEntryRole,
    'bootstrap_early',
    CodeSocket(),
  );

  /// Start-up code that sets up platform services in `bootstrap()`, such
  /// as `await Firebase.initializeApp(...)` and `installCrashReporting()`.
  static const bootstrapPlatform = SocketRef<CodeSocket>.role(
    appEntryRole,
    'bootstrap_platform',
    CodeSocket(),
  );

  /// Start-up code that fills the DI container in `bootstrap()`, after the
  /// platform services: `await registerDependencies();`.
  static const bootstrapDi = SocketRef<CodeSocket>.role(
    appEntryRole,
    'bootstrap_di',
    CodeSocket(),
  );

  /// Start-up code that runs last in `bootstrap()`, when services are ready.
  static const bootstrapLate = SocketRef<CodeSocket>.role(
    appEntryRole,
    'bootstrap_late',
    CodeSocket(),
  );

  /// Widgets around the root widget in `runApp()`, such as Riverpod's
  /// `ProviderScope(child: ` and `)`; the first contribution is outermost.
  static const rootWrappers = SocketRef<WrapperSocket>.role(
    appEntryRole,
    'root_wrappers',
    WrapperSocket(),
  );

  /// The minimum iOS version of the app, such as `15.0`: the highest version
  /// any module needs.
  ///
  /// Its tag appears in `ios/Podfile` and in the build settings of
  /// `ios/Runner.xcodeproj/project.pbxproj`. The provider contributes the
  /// version of its template, so the socket always has a value.
  static const iosDeploymentTarget = SocketRef<ValueSocket<String>>.role(
    appEntryRole,
    'ios_deployment_target',
    ValueSocket(policy: MaxPolicy(), renderer: _renderString, required: true),
  );

  /// Top-level declarations in `lib/bootstrap.dart`, such as a handler of
  /// background push messages that `bootstrap()` registers.
  static const topLevel = SocketRef<CodeSocket>.role(
    appEntryRole,
    'top_level',
    CodeSocket(),
  );

  /// Arguments of the root `MaterialApp`: `theme` and `darkTheme` take one
  /// value, `localizationsDelegates` and `supportedLocales` take list items.
  static const appArgs = SocketRef<ArgsSocket>.role(
    appEntryRole,
    'app_args',
    ArgsSocket({
      'theme': ArgShape.scalar,
      'darkTheme': ArgShape.scalar,
      'localizationsDelegates': ArgShape.list,
      'supportedLocales': ArgShape.list,
    }),
  );

  /// Widgets around the content of every route, in the `builder` of the
  /// root `MaterialApp`; the first contribution is outermost.
  static const appBuilder = SocketRef<WrapperSocket>.role(
    appEntryRole,
    'app_builder',
    WrapperSocket(),
  );

  /// `<uses-permission>` elements of the Android manifest, keyed by
  /// permission, such as `android.permission.INTERNET`.
  static const androidManifestPermissions =
      SocketRef<KeyedSocket<NoValue>>.role(
    appEntryRole,
    'android_manifest_permissions',
    KeyedSocket(
      policy: ConflictPolicy(),
      renderer: _renderAndroidPermissions,
    ),
  );

  /// `<meta-data>` elements of the `<application>` of the Android manifest,
  /// keyed by `android:name`, with an `android:value` or an
  /// `android:resource`.
  static const androidManifestApplicationMeta =
      SocketRef<KeyedSocket<AndroidMetaData>>.role(
    appEntryRole,
    'android_manifest_application_meta',
    KeyedSocket(
      policy: ConflictPolicy(),
      renderer: _renderAndroidMetaData,
    ),
  );

  /// `<intent-filter>` elements of the main activity of the Android
  /// manifest, such as deep links, as XML without imports.
  static const mainActivityIntentFilters = SocketRef<CodeSocket>.role(
    appEntryRole,
    'main_activity_intent_filters',
    CodeSocket.text(),
  );

  /// Keys of the iOS `Info.plist`, such as `UIBackgroundModes`: scalar
  /// values must agree, string arrays are united.
  ///
  /// The template's own keys cannot be contributed here.
  static const infoPlist = SocketRef<KeyedSocket<PlistValue>>.role(
    appEntryRole,
    'info_plist',
    KeyedSocket(policy: PlistMergePolicy(), renderer: _renderInfoPlist),
  );

  /// Gradle plugins declared in `android/settings.gradle.kts`, keyed by
  /// plugin id, with the highest version any module needs.
  ///
  /// They render as `id("<id>") version("<version>") apply false`, the form
  /// flutterfire writes and looks for. flutterfire adds the Firebase plugins
  /// itself when it configures the app.
  static const gradleSettingsPlugins = SocketRef<KeyedSocket<String>>.role(
    appEntryRole,
    'gradle_settings_plugins',
    KeyedSocket(policy: MaxPolicy(), renderer: _renderGradleSettingsPlugins),
  );

  /// Gradle plugins applied in `android/app/build.gradle.kts`, keyed by
  /// plugin id; declare their versions in [gradleSettingsPlugins].
  static const gradleAppPlugins = SocketRef<KeyedSocket<NoValue>>.role(
    appEntryRole,
    'gradle_app_plugins',
    KeyedSocket(policy: ConflictPolicy(), renderer: _renderGradleAppPlugins),
  );

  /// `implementation` dependencies of `android/app/build.gradle.kts`, keyed
  /// by `group:artifact`, with the highest version any module needs.
  static const gradleAppDependencies = SocketRef<KeyedSocket<String>>.role(
    appEntryRole,
    'gradle_app_dependencies',
    KeyedSocket(policy: MaxPolicy(), renderer: _renderGradleDependencies),
  );

  @override
  String get id => 'app_entry';

  @override
  String get description => 'App entry';

  @override
  RoleCardinality get cardinality => RoleCardinality.exactlyOne;

  @override
  bool get openToAllModules => true;

  @override
  List<SocketRef> get sockets => const [
        bootstrapEarly,
        bootstrapPlatform,
        bootstrapDi,
        bootstrapLate,
        rootWrappers,
        iosDeploymentTarget,
        topLevel,
        appArgs,
        appBuilder,
        androidManifestPermissions,
        androidManifestApplicationMeta,
        mainActivityIntentFilters,
        infoPlist,
        gradleSettingsPlugins,
        gradleAppPlugins,
        gradleAppDependencies,
      ];

  @override
  RoleInterface get interface => const RoleInterface(
        symbols: [main, bootstrap, fallbackStartScreen],
      );

  @override
  List<StructuralRule<NoDsl>> get structuralRules => const [
        StructuralRule(
          id: 'app_entry.bootstrap_without_material',
          description: 'lib/bootstrap.dart imports neither material nor '
              'cupertino, so start-up code does not depend on a design '
              'library.',
          check: _checkBootstrapWithoutMaterial,
        ),
        StructuralRule(
          id: 'app_entry.main_sequence',
          description:
              'main() calls WidgetsFlutterBinding.ensureInitialized(), '
              'awaits bootstrap(), then calls runApp(), in this order.',
          check: _checkMainSequence,
        ),
      ];
}

const _designLibraries = {
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
};

List<SmfIssue> _checkBootstrapWithoutMaterial(
  StructuralRuleInput<NoDsl> input,
) {
  const path = AppEntryRole.bootstrapFile;
  final file = input.files[path];
  if (file == null) return const [];
  return [
    for (final import in file.imports)
      if (_designLibraries.contains(import.uri))
        SmfIssue(
          '$path imports ${import.uri}, but start-up code must not depend on '
          'a design library.',
          hint: 'Import package:flutter/widgets.dart or '
              'package:flutter/foundation.dart instead.',
          origin: input.owners[path],
          path: path,
        ),
  ];
}

const _outOfOrder =
    'main() must call WidgetsFlutterBinding.ensureInitialized(), '
    'bootstrap() and runApp() in this order.';

List<SmfIssue> _checkMainSequence(StructuralRuleInput<NoDsl> input) {
  const path = AppEntryRole.mainFile;
  final file = input.files[path];
  if (file == null) return const [];

  IndexedInvocation? call(String name, {String? target}) {
    for (final invocation in file.invocationsOf(name, within: 'main')) {
      if (target == null || invocation.target == target) return invocation;
    }
    return null;
  }

  final ensureInitialized =
      call('ensureInitialized', target: 'WidgetsFlutterBinding');
  final bootstrap = call('bootstrap');
  final runApp = call('runApp');
  final problems = [
    if (ensureInitialized == null)
      'main() does not call WidgetsFlutterBinding.ensureInitialized().',
    if (bootstrap == null)
      'main() does not call bootstrap().'
    else if (!bootstrap.awaited)
      'main() does not await bootstrap().',
    if (runApp == null) 'main() does not call runApp().',
    if (ensureInitialized != null &&
        bootstrap != null &&
        runApp != null &&
        !(ensureInitialized.offset < bootstrap.offset &&
            bootstrap.offset < runApp.offset))
      _outOfOrder,
  ];
  return [
    for (final problem in problems)
      SmfIssue(problem, origin: input.owners[path], path: path),
  ];
}
