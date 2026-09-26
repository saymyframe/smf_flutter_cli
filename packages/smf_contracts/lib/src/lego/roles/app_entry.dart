import 'dart:convert';

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
/// - the Android and iOS projects, at the paths of Flutter's templates,
///   such as [androidManifestFile];
/// - [readmeFile], the README of the app.
///
/// The keyed sockets of the native files and of the README, and
/// [mainActivityIntentFilters], render complete lines, so their tags stand
/// alone at the start of a line of their file, like the tags of
/// [PipelineSockets]. The tag of [iosDeploymentTarget] stands where the
/// version goes, as in `IPHONEOS_DEPLOYMENT_TARGET = {{{tag}}};`. The module
/// rules of the role check these tags in the templates of its provider, and
/// its structural rules check that the native files name every key once.
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

  /// The path of the manifest of the Android app.
  static const androidManifestFile = 'android/app/src/main/AndroidManifest.xml';

  /// The path of the Gradle settings of the Android project.
  static const gradleSettingsFile = 'android/settings.gradle.kts';

  /// The path of the Gradle build script of the Android app module.
  static const gradleAppFile = 'android/app/build.gradle.kts';

  /// The path of the `Info.plist` of the iOS app.
  static const infoPlistFile = 'ios/Runner/Info.plist';

  /// The path of the Xcode project of the iOS app.
  static const xcodeProjectFile = 'ios/Runner.xcodeproj/project.pbxproj';

  /// The path of the README of the app.
  static const readmeFile = 'README.md';

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
  /// Its tag appears in the build settings of [xcodeProjectFile], once for
  /// each build configuration. When Flutter builds or runs the app, it
  /// raises the minimum iOS version of the Swift package of the plugins to
  /// this one. CocoaPods takes it for the pods through the Podfile that
  /// Flutter writes when a plugin needs pods or Swift Package Manager is
  /// off, which leaves the platform unset. The provider contributes the
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
  ///
  /// A permission that the manifest of the provider has already cannot be
  /// contributed: the manifest must not name one twice.
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
  ///
  /// A name that the `<application>` of the provider has already, such as
  /// `flutterEmbedding`, cannot be contributed.
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
  /// The keys of the provider's `Info.plist`, such as `CFBundleName`, cannot
  /// be contributed: the dictionary must not have a key twice.
  static const infoPlist = SocketRef<KeyedSocket<PlistValue>>.role(
    appEntryRole,
    'info_plist',
    KeyedSocket(policy: PlistMergePolicy(), renderer: _renderInfoPlist),
  );

  /// Gradle plugins declared in [gradleSettingsFile], keyed by plugin id,
  /// with the highest version any module needs.
  ///
  /// They render as `id("<id>") version("<version>") apply false`.
  ///
  /// The provider declares the Flutter plugin loader and the Android and
  /// Kotlin plugins, with their versions in the form `version "<version>"`
  /// that Flutter reads, so the socket does not take them.
  static const gradleSettingsPlugins = SocketRef<KeyedSocket<String>>.role(
    appEntryRole,
    'gradle_settings_plugins',
    KeyedSocket(
      policy: MaxPolicy(),
      renderer: _renderGradleSettingsPlugins,
      reservedKeys: {
        'dev.flutter.flutter-plugin-loader': _declaredByProvider,
        'com.android.application': _declaredByProvider,
        'org.jetbrains.kotlin.android': _declaredByProvider,
      },
    ),
  );

  /// Gradle plugins applied in [gradleAppFile], keyed by plugin id; declare
  /// their versions in [gradleSettingsPlugins].
  ///
  /// The provider applies them after the Flutter Gradle plugin, which
  /// applies the Kotlin plugin itself when the block does not, so a plugin
  /// that needs Kotlin finds it. The socket does not take the Kotlin plugin
  /// or the plugins the provider applies.
  static const gradleAppPlugins = SocketRef<KeyedSocket<NoValue>>.role(
    appEntryRole,
    'gradle_app_plugins',
    KeyedSocket(
      policy: ConflictPolicy(),
      renderer: _renderGradleAppPlugins,
      reservedKeys: {
        'com.android.application': _appliedByProvider,
        'dev.flutter.flutter-gradle-plugin': _appliedByProvider,
        'kotlin-android': _appliedByFlutter,
        'org.jetbrains.kotlin.android': _appliedByFlutter,
      },
    ),
  );

  /// `implementation` dependencies of [gradleAppFile], keyed by
  /// `group:artifact`, with the highest version any module needs.
  static const gradleAppDependencies = SocketRef<KeyedSocket<String>>.role(
    appEntryRole,
    'gradle_app_dependencies',
    KeyedSocket(policy: MaxPolicy(), renderer: _renderGradleDependencies),
  );

  /// Sections of [readmeFile], keyed by their heading, each with its text
  /// in Markdown, such as how to set up a service that the app uses.
  ///
  /// They follow the description of the app as `## <heading>` sections, in
  /// the order of the contributions (see [SocketContribution]). A heading is
  /// one line without spaces around it, a section has text, and two
  /// different texts under one heading conflict. Without sections, the
  /// README is that of the provider's template.
  static const readmeSections = SocketRef<KeyedSocket<String>>.role(
    appEntryRole,
    'readme_sections',
    KeyedSocket(
      policy: _ReadmeSectionPolicy(),
      renderer: _renderReadmeSections,
    ),
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
        readmeSections,
      ];

  @override
  RoleInterface get interface => const RoleInterface(
        symbols: [main, bootstrap, fallbackStartScreen],
      );

  @override
  List<ModuleRule<NoDsl>> get moduleRules => const [
        ModuleRule(
          id: 'app_entry.bootstrap_phases',
          description: 'The tags of the phases of start-up are in '
              'lib/bootstrap.dart in the order early, platform, di, late.',
          check: _checkBootstrapPhases,
        ),
        ModuleRule(
          id: 'app_entry.tag_lines',
          description: 'The tags of the sockets that render lines of a file, '
              'such as a native file or the README, stand alone at the start '
              'of a line of that file.',
          check: _checkTagLines,
        ),
      ];

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
        StructuralRule(
          id: 'app_entry.native_keys',
          description: 'The native files name every key once: the keys of '
              'the top-level dictionary of Info.plist, the permissions and '
              'the meta-data of the application in the Android manifest, and '
              'the plugins of each plugins block of the Gradle files.',
          check: _checkNativeKeys,
        ),
      ];
}

const _declaredByProvider = 'the provider of the app entry declares it';
const _appliedByProvider = 'the provider of the app entry applies it';
const _appliedByFlutter =
    'the Flutter Gradle plugin applies the Kotlin plugin itself';

/// The templates of the text files of the bricks among [contributions], by
/// path.
Map<String, String> _templatesOf(List<Contribution> contributions) => {
      for (final contribution in contributions)
        if (contribution is BrickContribution)
          for (final file in contribution.bundle.files)
            if (file.type == 'text')
              file.path.replaceAll(r'\', '/'): utf8.decode(
                base64.decode(file.data),
                allowMalformed: true,
              ),
    };

List<SmfIssue> _checkBootstrapPhases(ModuleRuleInput<NoDsl> input) {
  const path = AppEntryRole.bootstrapFile;
  const phases = [
    AppEntryRole.bootstrapEarly,
    AppEntryRole.bootstrapPlatform,
    AppEntryRole.bootstrapDi,
    AppEntryRole.bootstrapLate,
  ];
  final origin = ModuleOrigin(input.module.id);
  final templates = _templatesOf(input.contributions);
  final text = templates[path] ?? '';
  final tags = [for (final socket in phases) '{{{${socket.tag}}}}'];
  final issues = <SmfIssue>[
    for (final tag in tags)
      if (!text.contains(tag) &&
          templates.values.any((template) => template.contains(tag)))
        SmfIssue(
          'The tag $tag is not in $path, where bootstrap() runs the phases '
          'of start-up.',
          origin: origin,
          path: path,
        ),
  ];
  final offsets = [
    for (final tag in tags)
      if (text.indexOf(tag) case final offset when offset >= 0) offset,
  ];
  for (var i = 1; i < offsets.length; i++) {
    if (offsets[i - 1] > offsets[i]) {
      issues.add(
        SmfIssue(
          'The tags of the phases of start-up in $path are not in the order '
          'early, platform, di, late.',
          origin: origin,
          path: path,
        ),
      );
      break;
    }
  }
  return issues;
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
