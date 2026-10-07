import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/app_entry_role_bundle.dart';
import 'package:smf_contracts/core.dart';

part 'app_entry_guide.dart';
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
/// - the project of each platform of the app ([AppIdentity.platforms]), at
///   the paths of Flutter's templates, such as [androidManifestFile] and
///   [xcodeProjectFile];
/// - [readmeFile], the README of the app.
///
/// The provider builds the root of the app, inside the [rootWrappers], as a
/// `MaterialApp`, or a `MaterialApp.router` when the router role is present.
/// So the screens of every module have the Material ancestors they rely
/// on, such as the theme of the app and `MaterialLocalizations`.
///
/// The provider creates that `MaterialApp` in the `build` of a widget and
/// evaluates the expressions of the [appArgs] there. So `context` in such
/// an expression is the `BuildContext` of that widget, which is below the
/// [rootWrappers], and the root rebuilds when an inherited widget that the
/// expression read notifies. The rules of the role check both places. Its
/// module rules check that the tags of the [rootWrappers] are in the body
/// of `main()` in [mainFile], which runs the root widget inside them. Its
/// structural rules check that the provider creates a `MaterialApp`, and
/// every one of its code in `lib/` in a method
/// `build(BuildContext context)` of a class, since they cannot tell which
/// of them is the root.
///
/// The role's template generates the guide for coding agents that work on
/// the app, whichever module provides the role: [agentsFile], with a
/// section for each role and module of the app that has notes for them
/// (see [agentSections]), and [claudeFile], which gives the same guide to
/// the agents that read that file instead. The structural rule
/// `app_entry.agent_guide_paths` checks the paths that the guide names
/// below the top-level directories of a Flutter project, and its paths to
/// Dart files: each is a file or a directory of the app.
///
/// The template also tells the system which icons of the status bar suit
/// the theme of the app, on every screen: it puts a widget into
/// [appBuilder] that reads the brightness of the theme below the root
/// `MaterialApp`, and asks for dark icons on a light theme and for light
/// ones on a dark theme. So a screen without an app bar tells nothing of
/// the status bar itself, in an app with a module that provides the theme
/// and in one without it; a screen with an `AppBar` gets the icons that
/// suit its bar.
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

  /// The path of the guide for coding agents that work on the app; see
  /// [agentSections].
  static const agentsFile = 'AGENTS.md';

  /// The path of the file that gives [agentsFile] to the agents that read
  /// `CLAUDE.md` instead: its whole content is `@AGENTS.md`.
  static const claudeFile = 'CLAUDE.md';

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
  ///
  /// The provider has the tags of the socket in the body of `main()` in
  /// [mainFile], around the root widget that `main()` runs. So the widget
  /// that creates the root `MaterialApp` is below the wrappers, and the
  /// expressions of the [appArgs] can read an inherited widget among them
  /// from `context`.
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

  /// Arguments of the root `MaterialApp`: `theme`, `darkTheme`, `themeMode`
  /// and `locale` take one value, `localizationsDelegates` takes the list
  /// items of every contributor, and `supportedLocales` takes the list
  /// items of one contributor ([ArgShape.listOfOneContributor]).
  ///
  /// Every delegate of the root has to support each of its locales, so a
  /// module that added a locale next to another contributor would break
  /// the delegates of the other. So the pipeline reports the items of a
  /// second contributor of `supportedLocales` as a conflict. In an app with
  /// the localization role, the template of that role is the contributor.
  ///
  /// The provider evaluates the expression of an argument in the `build` of
  /// the widget that creates the root `MaterialApp`. So the expression may
  /// read `context`, the `BuildContext` of that widget, which is below the
  /// [rootWrappers]: an argument can take its value from an inherited
  /// widget that a module put around the root, such as the theme mode or
  /// the locale that the user chose, and the root rebuilds with the new
  /// value when that widget notifies. That context is above the
  /// `MaterialApp`, so it has neither the theme nor the localizations of
  /// the app.
  static const appArgs = SocketRef<ArgsSocket>.role(
    appEntryRole,
    'app_args',
    ArgsSocket({
      'theme': ArgShape.scalar,
      'darkTheme': ArgShape.scalar,
      'themeMode': ArgShape.scalar,
      'locale': ArgShape.scalar,
      'localizationsDelegates': ArgShape.list,
      'supportedLocales': ArgShape.listOfOneContributor,
    }),
  );

  /// Widgets around the content of every route, in the `builder` of the
  /// root `MaterialApp`; the first contribution is outermost. They are below
  /// the theme and the localizations of the app. The template of the role
  /// puts one here itself, for the icons of the status bar, in every app:
  /// so the templates of every provider have the tags of this socket, and
  /// the pipeline reports a provider without them.
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

  /// Sections of [agentsFile], the guide for coding agents that work on the
  /// app, keyed by their heading, each with an [AgentNote] in Markdown.
  ///
  /// A note tells what the code of the app does not show: a rule that holds
  /// across files, an order, what not to do and what to do instead, a
  /// placeholder, a step that needs a person. The section of a role has the
  /// [Role.description] of the role as its heading: the template of the
  /// role tells there, with [AgentNote.ofRole], what holds whichever module
  /// provides the role, and a provider adds what its package brings under
  /// the same heading. A module without a role has a heading of its own.
  ///
  /// The sections follow the introduction of the guide as `## <heading>`
  /// sections: that of this role first, then the others in the order of
  /// their headings. A section has the notes of the roles first, then the
  /// others in the order of the ids of their contributors, each once, with
  /// an empty line between two notes. So replacing the provider of a role
  /// changes only its own note. The socket does not follow the order edges
  /// of its contributors (see [SocketKind.followsOrderEdges]): a role in
  /// the [Contribution.when] of a note adds no edge, so no note can make
  /// the app impossible to generate.
  ///
  /// A heading is one line without spaces around it. A note has text,
  /// starts neither a title nor a section, with a line that starts with
  /// `# ` or `## ` or a line of `=` or `-` under a line of text, and closes
  /// its fenced code blocks. Only the template of a role contributes a
  /// note of a role ([AgentNote.ofRole]).
  ///
  /// A note names a file or a directory of the app in backticks, by its
  /// path from the root of the app, such as `lib/core/di/`. The structural
  /// rule `app_entry.agent_guide_paths` reads the paths below a top-level
  /// directory of a Flutter project, such as `lib/`, `test/` or `android/`,
  /// whether the app has that directory or not, and the paths to Dart
  /// files, and reports one that the app does not have. It does not read
  /// the name of a file at the root of the app, such as `pubspec.yaml`,
  /// which nothing tells from other names. So what a note tells of a file
  /// of a role that the app may lack is a contribution of its own, with
  /// that role in its [Contribution.when], and what depends on the data of
  /// a role comes from the render hook of the role or of its provider. A
  /// file that a later step writes, such as one of a tool that runs after
  /// generation, is named as a pattern, with `<…>` or `*`, or left to the
  /// README.
  static const agentSections = SocketRef<KeyedSocket<AgentNote>>.role(
    appEntryRole,
    'agent_sections',
    KeyedSocket(
      policy: _AgentNotePolicy(),
      renderer: _renderAgentSections,
      followsOrderEdges: false,
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
        agentSections,
      ];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [agentsFile, claudeFile],
        symbols: [main, bootstrap, fallbackStartScreen],
      );

  @override
  RoleTemplate<NoDsl> get template => const _AppEntryTemplate();

  @override
  List<ModuleRule<NoDsl>> get moduleRules => const [
        ModuleRule(
          id: 'app_entry.bootstrap_phases',
          description: 'The tags of the phases of start-up are in the body '
              'of bootstrap() in lib/bootstrap.dart, in the order early, '
              'platform, di, late.',
          check: _checkBootstrapPhases,
        ),
        ModuleRule(
          id: 'app_entry.root_wrappers_in_main',
          description: 'The tags of the root wrappers are in the body of '
              'main() in lib/main.dart, which runs the root widget inside '
              'them, so the widget that creates the root MaterialApp is '
              'below the widgets that the modules put around the root.',
          check: _checkRootWrappersInMain,
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
          id: 'app_entry.material_root',
          description: 'The provider builds the root of the app as a '
              'MaterialApp, or a MaterialApp.router with a router.',
          check: _checkMaterialRoot,
        ),
        StructuralRule(
          id: 'app_entry.root_in_build',
          description: 'The provider creates every MaterialApp of lib/, one '
              'of which is the root of the app, in a method '
              'build(BuildContext context) of a class, so the arguments '
              'that the modules give the root read the context of that '
              'build.',
          check: _checkRootInBuild,
        ),
        StructuralRule(
          id: 'app_entry.native_keys',
          description: 'The native files name every key once: the keys of '
              'the top-level dictionary of Info.plist, the permissions and '
              'the meta-data of the application in the Android manifest, and '
              'the plugins of each plugins block of the Gradle files.',
          check: _checkNativeKeys,
        ),
        StructuralRule(
          id: 'app_entry.agent_guide_paths',
          description: 'A path that the guide for coding agents names in '
              'inline code below a top-level directory of a Flutter '
              'project, or to a Dart file, is a file or a directory of the '
              'app, written from the root of the app.',
          check: _checkAgentGuidePaths,
        ),
      ];
}

const _declaredByProvider = 'the provider of the app entry role declares it';
const _appliedByProvider = 'the provider of the app entry role applies it';
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
  final offsets = [
    for (final tag in tags)
      if (text.indexOf(tag) case final offset when offset >= 0) offset,
  ];
  return [
    ..._tagsOutsideBodyOf(
      AppEntryRole.bootstrap.name,
      path: path,
      does: 'runs the phases of start-up',
      tags: tags,
      templates: templates,
      origin: origin,
    ),
    if (!_ascending(offsets))
      SmfIssue(
        'The tags of the phases of start-up in $path are not in the order '
        'early, platform, di, late.',
        origin: origin,
        path: path,
      ),
  ];
}

List<SmfIssue> _checkRootWrappersInMain(ModuleRuleInput<NoDsl> input) =>
    _tagsOutsideBodyOf(
      AppEntryRole.main.name,
      path: AppEntryRole.mainFile,
      does: 'runs the root widget inside the root wrappers',
      tags: [for (final tag in AppEntryRole.rootWrappers.tags) '{{{$tag}}}'],
      templates: _templatesOf(input.contributions),
      origin: ModuleOrigin(input.module.id),
    );

/// The problems of [tags], the tags of sockets that belong in the body of
/// the function [function] of the template at [path], among the [templates]
/// of a module: first each tag that the module has in another template
/// only, then each that is in that template outside the body. [does] says
/// what the function does there, such as `runs the phases of start-up`.
List<SmfIssue> _tagsOutsideBodyOf(
  String function, {
  required String path,
  required String does,
  required List<String> tags,
  required Map<String, String> templates,
  required ContributionOrigin origin,
}) {
  final text = templates[path] ?? '';
  final body = _bodyOf(text, function);
  SmfIssue issue(String problem) =>
      SmfIssue(problem, origin: origin, path: path);
  return [
    for (final tag in tags)
      if (!text.contains(tag) &&
          templates.values.any((template) => template.contains(tag)))
        issue('The tag $tag is not in $path, where $function() $does.'),
    for (final tag in tags)
      if (text.indexOf(tag) case final offset
          when offset >= 0 &&
              (body == null || offset <= body.start || offset >= body.end))
        issue(
          'The tag $tag is in $path, but not in the body of $function(), '
          'which $does.',
        ),
  ];
}

/// Whether none of [offsets] is before the one in front of it.
bool _ascending(List<int> offsets) {
  for (var i = 1; i < offsets.length; i++) {
    if (offsets[i - 1] > offsets[i]) return false;
  }
  return true;
}

/// The offsets from the opening brace to the closing brace of the body of
/// the function [name] in [template], the template of a Dart file, or
/// `null` if it declares no such function with a body in braces.
///
/// The tags of the template, and the comments and strings of its code, do
/// not count, so a brace in them does not end the body.
({int start, int end})? _bodyOf(String template, String name) {
  final code = template.replaceAllMapped(
    _notCode,
    (match) => ' ' * match[0]!.length,
  );
  final declaration = RegExp(
    '\\b${RegExp.escape(name)}\\s*\\([^)]*\\)\\s*(?:async\\s*)?\\{',
  ).firstMatch(code);
  if (declaration == null) return null;
  final start = declaration.end - 1;
  var depth = 0;
  for (var i = start; i < code.length; i++) {
    switch (code[i]) {
      case '{':
        depth++;
      case '}' when --depth == 0:
        return (start: start, end: i);
    }
  }
  return null;
}

/// The parts of the template of a Dart file that are not code: the tags of
/// the template, comments and strings, raw or not, on one line or on
/// several.
final _notCode = RegExp(
  r'\{\{\{[\s\S]*?\}\}\}|\{\{[\s\S]*?\}\}|//[^\n]*|/\*[\s\S]*?\*/|'
  r"r?'''[\s\S]*?'''|"
  r'r?"""[\s\S]*?"""|'
  r"r?'(?:\\.|[^'\\\n])*'|"
  r'r?"(?:\\.|[^"\\\n])*"',
);

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

/// Whether [invocation] creates a `MaterialApp`, with or without `const`;
/// the index records `MaterialApp.router()` as `router()` on the target
/// `MaterialApp`.
bool _createsMaterialApp(IndexedInvocation invocation) =>
    switch ((invocation.name, invocation.target)) {
      ('MaterialApp', null) || ('router', 'MaterialApp') => true,
      _ => false,
    };

/// The Dart files in `lib/` of the provider of the app entry among the files
/// of [input], each with its path and the id of the provider: the root is
/// in the code of the app, not in its tests.
Iterable<(String, DartFileIndex, ModuleId)> _filesOfProvider(
  StructuralRuleInput<NoDsl> input,
) sync* {
  for (final MapEntry(key: path, value: file) in input.files.entries) {
    final owner = input.owners[path];
    if (owner is! ModuleOrigin || !path.startsWith('lib/')) continue;
    final module = input.module(owner.module);
    if (!(module?.provides.contains(appEntryRole) ?? false)) continue;
    yield (path, file, owner.module);
  }
}

List<SmfIssue> _checkMaterialRoot(StructuralRuleInput<NoDsl> input) {
  ModuleId? provider;
  for (final (_, file, module) in _filesOfProvider(input)) {
    if (file.invocations.any(_createsMaterialApp)) return const [];
    provider = module;
  }
  // The required symbols report the files of a provider that are missing.
  if (provider == null) return const [];
  return [
    SmfIssue(
      'The root of the app must be a MaterialApp, but the module $provider '
      'creates none in lib/.',
      hint: 'Build the root widget as a MaterialApp, or a MaterialApp.router '
          'when the router role is present: the screens of the modules need '
          'its theme and MaterialLocalizations.',
      origin: ModuleOrigin(provider),
    ),
  ];
}

/// The index cannot tell which `MaterialApp` of the provider is the root of
/// the app, so the rule asks the same of every one that the provider
/// creates in `lib/`: one in a helper of a widget or in a function, such as
/// an app for tests, is reported too.
List<SmfIssue> _checkRootInBuild(StructuralRuleInput<NoDsl> input) => [
      for (final (path, file, provider) in _filesOfProvider(input))
        for (final invocation in file.invocations)
          if (_createsMaterialApp(invocation) && !_inBuild(file, invocation))
            SmfIssue(
              '$path creates a MaterialApp outside a method '
              'build(BuildContext context) of a class. Every MaterialApp '
              'that the provider creates in lib/ counts, since each may be '
              'the root of the app, whose arguments from the modules read '
              'the context of such a build.',
              hint: 'Create it in the build(BuildContext context) of a '
                  'widget. main() runs the widget that creates the root '
                  'inside the root wrappers.',
              origin: ModuleOrigin(provider),
              path: path,
            ),
    ];

/// Whether [invocation] of [file] is in a method `build` of a class whose
/// first parameter is `BuildContext context`.
bool _inBuild(DartFileIndex file, IndexedInvocation invocation) =>
    invocation.enclosingMember == 'build' &&
    file.declarations.any(
      (declaration) =>
          declaration.name == invocation.enclosingDeclaration &&
          declaration.members.any(_isBuildWithContext),
    );

/// Whether [member] is a method `build`, not a getter or a setter of that
/// name, whose first parameter is the positional `BuildContext context`.
bool _isBuildWithContext(IndexedMember member) =>
    member.name == 'build' &&
    member.kind == MemberKind.method &&
    switch (member.parameters) {
      [
        IndexedParameter(
          name: 'context',
          type: 'BuildContext',
          kind: ParameterKind(isNamed: false),
        ),
        ...,
      ] =>
        true,
      _ => false,
    };
