import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// A question that `smf create` asked: its message and the choices it
/// showed.
typedef _Question = ({String message, List<String> shown});

/// Answers the questions of a run in a terminal from a script, which gives
/// each question the starts of the choices to pick, and records them.
final class _Prompter implements SmfPrompter {
  _Prompter(this._answers);

  final Map<String, List<String>> _answers;

  final List<_Question> asked = [];

  List<T> _pick<T extends Object>(
    String message,
    List<T> choices,
    String Function(T choice)? display,
  ) {
    final shown = [
      for (final choice in choices) display?.call(choice) ?? '$choice',
    ];
    asked.add((message: message, shown: shown));
    final answer = _answers.entries
        .firstWhere(
          (entry) => message.startsWith(entry.key),
          orElse: () => throw StateError('Unexpected question: $message'),
        )
        .value;
    return [
      for (final start in answer)
        choices[shown.indexWhere((label) => label.startsWith(start))],
    ];
  }

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) async =>
      _pick(message, choices, display).single;

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) async =>
      _pick(message, choices, display);

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) =>
      throw StateError('Unexpected question: $message');

  @override
  Future<String> input(String message, {String? defaultValue}) =>
      throw StateError('Unexpected question: $message');
}

/// Records what the run reports.
final class _Logger implements SmfLogger {
  final List<String> lines = [];

  @override
  void info(String message) => lines.add(message);

  @override
  void detail(String message) {}

  @override
  void warn(String message) => lines.add(message);

  @override
  void error(String message) => lines.add(message);

  @override
  void success(String message) => lines.add(message);

  @override
  SmfProgress progress(String message) => _Progress();
}

final class _Progress implements SmfProgress {
  @override
  void update(String message) {}

  @override
  void complete([String? message]) {}

  @override
  void fail([String? message]) {}
}

/// Runs every command with success, as the tools that `smf create` runs
/// in the new app would.
final class _Commands implements SmfProcessRunner {
  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
    Duration? timeout,
  }) async =>
      const SmfProcessResult(exitCode: 0);

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async =>
      0;
}

/// What a run of `smf create` in a terminal did: its exit code, the
/// questions it asked, what it reported, and the file system with the app.
typedef _Run = ({
  int code,
  List<_Question> asked,
  List<String> lines,
  MemoryFileSystem files,
});

/// Runs `smf create my_app` with [options] and the modules of the CLI in a
/// terminal that answers with [answers], on a machine with a Flutter SDK
/// whose commands all succeed; the app goes to `/work/my_app`.
Future<_Run> _create(
  Map<String, List<String>> answers, {
  List<String> options = const [],
}) async {
  final files = MemoryFileSystem.test();
  files.directory('/sdk/bin/cache/dart-sdk').createSync(recursive: true);
  files.file('/sdk/bin/cache/flutter.version.json').writeAsStringSync(
        '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2"}',
      );
  for (final tool in ['flutter', 'dart']) {
    files.file('/sdk/bin/$tool').createSync();
  }
  files.directory('/work').createSync();
  files.currentDirectory = '/work';
  final prompter = _Prompter(answers);
  final logger = _Logger();
  final code = await runSmf(
    ['create', 'my_app', '--org', 'com.example', ...options],
    modules: smfModules,
    hostFor: ({required verbose}) => SmfHost(
      prompter: prompter,
      processRunner: _Commands(),
      logger: logger,
      fileSystem: files,
      environmentVariables: const {'PATH': '/sdk/bin'},
      operatingSystem: HostOperatingSystem.macos,
      hasTerminal: true,
    ),
  );
  return (code: code, asked: prompter.asked, lines: logger.lines, files: files);
}

void main() {
  test(
      'a run in a terminal asks for the features first, and not for the '
      'router once the app has home', () async {
    final run = await _create({
      'Features': ['home'],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['None'],
      'State management': ['bloc'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'Settings screen: which module provides it?',
      'Localization: which module provides it?',
      'Theme: which module provides it?',
      'Preferences: which module provides it?',
      'Dependency injection: which module provides it?',
      'State management: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
      'Authentication: which module provides it?',
    ]);
    expect(run.asked[0].shown, [
      'home — Start screen with a welcome and the next steps',
      'onboarding — Onboarding on the first launch of the app',
      'sign_in — Email sign-in: sign-up, password reset and an account screen',
    ]);
    expect(run.asked[1].shown, [
      'firebase_core — Firebase with firebase_core',
    ]);
    expect(run.asked[2].shown, [
      'bottom_tabs — Tabs in a bar at the bottom of the app',
      'None',
    ]);
    expect(run.asked[3].shown, [
      'settings — Settings screen with the settings of the modules',
      'None',
    ]);
    // The roles come in the order in which the modules of the list bring
    // them: the layout, with the router, brings the localization, whose
    // labels it shows. The theme follows, and then the preferences of both
    // and the DI container, all before the state managers.
    expect(run.asked[8].shown, [
      'bloc — BLoC with flutter_bloc',
      'riverpod — Riverpod with flutter_riverpod',
      'None',
    ]);
    // go_router is the only module that provides the router.
    expect(
      run.lines,
      contains(
        'Adding go_router: the only provider of the router role, which home '
        'requires.',
      ),
    );
    final app = run.files.directory('/work/my_app');
    expect(
      app.childFile('lib/features/home/home_screen.dart').existsSync(),
      isTrue,
    );
    expect(
      app
          .childFile('lib/core/router/app_router_factory.dart')
          .readAsStringSync(),
      allOf(
        contains("initialLocation: '/home',"),
        isNot(contains('StatefulShellRoute')),
      ),
    );
    expect(app.childDirectory('lib/core/layout').existsSync(), isFalse);
    expect(app.childDirectory('lib/core/di').existsSync(), isFalse);
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(contains('  go_router: '), contains('  flutter_bloc: ')),
    );
  });

  test(
      'a run in a terminal offers bottom tabs as the layout, which shows the '
      'features', () async {
    final run = await _create({
      'Features': ['home'],
      'Infrastructure': [],
      'Layout': ['bottom_tabs'],
      'Settings screen': ['None'],
      'State management': ['riverpod'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'Settings screen: which module provides it?',
      'Localization: which module provides it?',
      'Theme: which module provides it?',
      'Preferences: which module provides it?',
      'Dependency injection: which module provides it?',
      'State management: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
      'Authentication: which module provides it?',
    ]);
    expect(
      run.lines,
      contains(
        'Adding go_router: the only provider of the router role, which home '
        'requires.',
      ),
    );
    final app = run.files.directory('/work/my_app');
    expect(
      app.childFile('lib/core/layout/app_shell.dart').readAsStringSync(),
      contains('class AppShell extends StatelessWidget'),
    );
    expect(
      app
          .childFile('lib/core/router/app_router_factory.dart')
          .readAsStringSync(),
      allOf(
        contains('StatefulShellRoute.indexedStack('),
        contains('destinations: appDestinations,'),
        contains("initialLocation: '/home',"),
      ),
    );
    // The tab of the start screen, whose label is in English in an app
    // without a module that keeps its texts.
    expect(
      app.childFile('lib/core/layout/destination.dart').readAsStringSync(),
      allOf(
        contains('Destination(label: _homeHomeLabel, icon: Icons.home),'),
        contains("String _homeHomeLabel(BuildContext context) => 'Home';"),
      ),
    );
  });

  test(
      'a run in a terminal asks which module provides the settings screen '
      'after the layout, and offers settings, which the layout shows after '
      'the start screen', () async {
    final run = await _create({
      'Features': ['home'],
      'Infrastructure': [],
      'Layout': ['bottom_tabs'],
      'Settings screen': ['settings'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    final messages = [for (final question in run.asked) question.message];
    final settings = messages.indexOf(
      'Settings screen: which module provides it?',
    );
    // Both roles require the router, so their questions come before its
    // own, in the order of the roles of the registry: the layout first,
    // which the router role uses, so it comes with the router, and then the
    // settings screen, which comes with the settings module.
    expect(settings, messages.indexOf('Layout: which module provides it?') + 1);
    expect(run.asked[settings].shown, [
      'settings — Settings screen with the settings of the modules',
      'None',
    ]);
    // The module provides a role, so it is not among the features to pick.
    expect(run.asked[0].shown, [
      'home — Start screen with a welcome and the next steps',
      'onboarding — Onboarding on the first launch of the app',
      'sign_in — Email sign-in: sign-up, password reset and an account screen',
    ]);
    expect(
      run.lines,
      contains(
        'Adding go_router: the only provider of the router role, which home '
        'requires.',
      ),
    );
    final app = run.files.directory('/work/my_app');
    expect(
      app
          .childFile('lib/features/settings/settings_screen.dart')
          .readAsStringSync(),
      allOf(
        contains('class SettingsScreen extends StatelessWidget'),
        // No module of this app has a setting, so the screen has its note
        // for the developer of the app.
        contains('class _NoSettings extends StatelessWidget'),
      ),
    );
    // The tabs are Home and Settings, in the order of the list of modules,
    // and the app starts on the start screen.
    final destinations =
        app.childFile('lib/core/layout/destination.dart').readAsStringSync();
    final home = destinations.indexOf(
      'Destination(label: _homeHomeLabel, icon: Icons.home),',
    );
    expect(home, isNonNegative);
    expect(
      destinations.indexOf(
        'Destination(label: _settingsSettingsLabel, icon: Icons.settings),',
      ),
      greaterThan(home),
    );
    expect(
      destinations,
      allOf(
        contains("String _homeHomeLabel(BuildContext context) => 'Home';"),
        contains(
          'String _settingsSettingsLabel(BuildContext context) => '
          "'Settings';",
        ),
      ),
    );
    final router = app
        .childFile('lib/core/router/app_router_factory.dart')
        .readAsStringSync();
    expect(router, contains('destinations: appDestinations,'));
    expect(router, contains("initialLocation: '/home',"));
  });

  test(
      'a run in a terminal adds the router that the settings screen requires '
      'without a question, and the app does not start on that screen',
      () async {
    final run = await _create({
      'Features': [],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['settings'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(
      run.asked.map((question) => question.message),
      isNot(contains('Router: which module provides it?')),
    );
    const added = 'Adding go_router: the only provider of the router role, '
        'which settings requires.';
    // The screen is a route that nothing opens in an app without a layout.
    const start = 'No route is marked as a start candidate, so the app starts '
        'on its fallback screen. Choose a start route with --start.';
    expect(run.lines, containsAll([added, start]));
    final app = run.files.directory('/work/my_app');
    expect(
      app
          .childFile('lib/core/router/app_router_factory.dart')
          .readAsStringSync(),
      allOf(
        contains("initialLocation: '/',"),
        contains("path: '/settings',"),
        isNot(contains('AppShell')),
      ),
    );
  });

  test(
      'a run in a terminal adds the router that the layout requires without '
      'a question', () async {
    final run = await _create({
      'Features': [],
      'Infrastructure': [],
      'Layout': ['bottom_tabs'],
      'Settings screen': ['None'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'Settings screen: which module provides it?',
      'Localization: which module provides it?',
      'Theme: which module provides it?',
      'Preferences: which module provides it?',
      'Dependency injection: which module provides it?',
      'State management: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
      'Authentication: which module provides it?',
    ]);
    expect(
      run.lines,
      contains(
        'Adding go_router: the only provider of the router role, which '
        'bottom_tabs requires.',
      ),
    );
    final app = run.files.directory('/work/my_app');
    // Without features, the app has no destinations to show.
    expect(
      app.childFile('lib/core/layout/app_shell.dart').existsSync(),
      isTrue,
    );
    expect(
      app
          .childFile('lib/core/router/app_router_factory.dart')
          .readAsStringSync(),
      allOf(
        contains("initialLocation: '/',"),
        isNot(contains('AppShell')),
      ),
    );
  });

  test('a run in a terminal asks for the router of an app without features',
      () async {
    final run = await _create({
      'Features': [],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['None'],
      'Router': ['go_router'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'Settings screen: which module provides it?',
      'Router: which module provides it?',
      'Localization: which module provides it?',
      'Theme: which module provides it?',
      'Preferences: which module provides it?',
      'Dependency injection: which module provides it?',
      'State management: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
      'Authentication: which module provides it?',
    ]);
    expect(run.asked[4].shown, [
      'go_router — Routes and navigation with go_router',
      'None',
    ]);
    final app = run.files.directory('/work/my_app');
    expect(app.childDirectory('lib/features').existsSync(), isFalse);
    expect(
      app
          .childFile('lib/core/router/app_router_factory.dart')
          .readAsStringSync(),
      contains("initialLocation: '/',"),
    );
  });

  test(
      'a run in a terminal asks which module provides the localization after '
      'the settings screen, and offers gen_l10n, which keeps the texts of '
      'the app in ARB files and brings the preferences, in which the app '
      'remembers its language', () async {
    final run = await _create({
      'Features': ['home'],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['None'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['gen_l10n'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    final messages = [for (final question in run.asked) question.message];
    final localization = messages.indexOf(
      'Localization: which module provides it?',
    );
    // The roles come in the order in which the modules of the list bring
    // them. The router brings the layout, which its role uses, and the
    // layout the localization, in which it shows the labels of its
    // destinations. So the question comes after those of the roles that
    // require the router, and before that of the theme, the next role that
    // the modules of the list bring.
    expect(
      localization,
      messages.indexOf('Settings screen: which module provides it?') + 1,
    );
    // The preferences have one provider, so the run does not ask for them.
    expect(
      messages.sublist(localization + 1, localization + 3),
      [
        'Theme: which module provides it?',
        'Dependency injection: which module provides it?',
      ],
    );
    expect(run.asked[localization].shown, [
      'gen_l10n — Texts in ARB files with gen-l10n of Flutter',
      'None',
    ]);
    final app = run.files.directory('/work/my_app');
    // The texts of the app are those of the start screen, after the label
    // of that screen in a main navigation, and then the two of the fallback
    // start screen of the app entry, in English and in Ukrainian, so the
    // app is in both.
    for (final (language, label) in [('en', 'Home'), ('uk', 'Головна')]) {
      final texts = jsonDecode(
        app.childFile('lib/l10n/app_$language.arb').readAsStringSync(),
      ) as Map<String, Object?>;
      expect(texts.keys.take(2), ['@@locale', 'homeLabel'], reason: language);
      expect(texts['@@locale'], language);
      expect(texts['homeLabel'], label);
      expect(
        texts.keys.skip(1),
        [
          ...texts.keys.where((key) => key.startsWith('home')),
          'flutterCoreFallbackHint',
          'flutterCoreFallbackCopied',
        ],
        reason: language,
      );
    }
    expect(
      [
        for (final file in app.childDirectory('lib/l10n').listSync())
          file.basename,
      ]..sort(),
      ['app_en.arb', 'app_uk.arb'],
    );
    expect(
      app.childFile('l10n.yaml').readAsStringSync(),
      contains('nullable-getter: false'),
    );
    expect(
      app.childFile('lib/core/l10n/l10n.dart').readAsStringSync(),
      contains('AppLocalizations get l10n => AppLocalizations.of(this);'),
    );
    expect(
      app.childFile('lib/core/l10n/app_locale.dart').readAsStringSync(),
      contains("const appLocales = <Locale>[Locale('en'), Locale('uk')];"),
    );
    expect(
      app.childFile('lib/app.dart').readAsStringSync(),
      allOf(
        contains('locale: AppLocaleScope.of(context),'),
        contains('AppLocalizations.delegate,'),
        contains('supportedLocales: [...appLocales],'),
      ),
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(
        contains('  generate: true'),
        contains('  intl: "any"'),
        contains('  flutter_localizations:\n    sdk: flutter'),
      ),
    );
    expect(
      app.childFile('README.md').readAsStringSync(),
      contains('\n## Languages\n'),
    );
    // The localization requires the preferences, in which the app
    // remembers the language that the user chose. One module provides
    // them, so the run takes it without a question and says why.
    expect(messages, isNot(contains(startsWith('Preferences'))));
    expect(
      run.lines,
      contains(
        'Adding shared_preferences: the only provider of the preferences '
        'role, which gen_l10n requires.',
      ),
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      contains('  shared_preferences: '),
    );
    expect(
      app
          .childFile('lib/core/preferences/app_preferences.dart')
          .readAsStringSync(),
      contains('restoreAppLocale,'),
    );
  });

  test(
      'a run in a terminal asks which module provides dependency injection '
      'after the localization and its preferences, and offers get_it',
      () async {
    final run = await _create({
      'Features': ['home'],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['None'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['get_it'],
      'Events': ['None'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    final messages = [for (final question in run.asked) question.message];
    final di = messages.indexOf(
      'Dependency injection: which module provides it?',
    );
    // The roles come in the order in which the modules of the list bring
    // them: the preferences, which the localization requires, use the DI
    // container, so its question follows theirs, before that of the state
    // management, which comes with its own modules.
    expect(
      di,
      messages.indexOf('Preferences: which module provides it?') + 1,
    );
    expect(
      messages[di + 1],
      'State management: which module provides it?',
    );
    expect(run.asked[di].shown, [
      'get_it — Service locator with get_it',
      'None',
    ]);
    final app = run.files.directory('/work/my_app');
    // Without the events, no module of the app registers a service.
    expect(
      app.childFile('lib/core/di/dependencies.dart').readAsStringSync(),
      allOf(
        contains('ServiceLocator createServiceLocator() =>'),
        contains('Future<void> registerDependencies() async {'),
        isNot(contains('.register')),
      ),
    );
    expect(
      app.childFile('lib/core/di/service_locator.dart').existsSync(),
      isTrue,
    );
    expect(
      app.childFile('lib/bootstrap.dart').readAsStringSync(),
      contains('await registerDependencies();'),
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      contains('  get_it: '),
    );
  });

  test(
      'a run in a terminal asks which module provides the events after '
      'dependency injection, and offers event_bus, whose service the DI '
      'container registers', () async {
    final run = await _create({
      'Features': [],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['None'],
      'Router': ['None'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['get_it'],
      'Events': ['event_bus'],
      'Preferences': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    final messages = [for (final question in run.asked) question.message];
    final events = messages.indexOf('Events: which module provides it?');
    // The roles come in the order of the list of modules, and event_bus is
    // after get_it.
    expect(
      events,
      greaterThan(
        messages.indexOf('Dependency injection: which module provides it?'),
      ),
    );
    expect(run.asked[events].shown, [
      'event_bus — Event bus with event_bus',
      'None',
    ]);
    final app = run.files.directory('/work/my_app');
    expect(
      app
          .childFile('lib/core/events/communication_service.dart')
          .readAsStringSync(),
      allOf(
        contains('abstract interface class CommunicationService'),
        contains('createEventBusCommunicationService()'),
      ),
    );
    expect(
      app
          .childFile('lib/core/events/event_bus_communication_service.dart')
          .readAsStringSync(),
      contains('EventBus()'),
    );
    expect(
      app.childFile('lib/core/di/dependencies.dart').readAsStringSync(),
      allOf(
        contains('.registerLazySingleton<'),
        contains('.createCommunicationService()'),
      ),
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(contains('  event_bus: '), contains('  get_it: ')),
    );
  });

  test(
      'a run in a terminal asks which module provides the preferences after '
      'the localization and the theme, which require them, and offers '
      'shared_preferences, which the start-up opens and the DI container '
      'registers', () async {
    final run = await _create({
      'Features': [],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['None'],
      'Router': ['None'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['get_it'],
      'Events': ['None'],
      'Preferences': ['shared_preferences'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    final messages = [for (final question in run.asked) question.message];
    final preferences = messages.indexOf(
      'Preferences: which module provides it?',
    );
    // The roles come in the order in which the modules of the list bring
    // them, and the localization and the theme, whose roles require the
    // preferences, come before the preferences and before get_it. So the
    // question of the preferences knows whether the answers on the
    // localization and on the theme need them.
    expect(
      messages.sublist(preferences - 2, preferences + 1),
      [
        'Localization: which module provides it?',
        'Theme: which module provides it?',
        'Preferences: which module provides it?',
      ],
    );
    expect(
      preferences,
      lessThan(
        messages.indexOf('Dependency injection: which module provides it?'),
      ),
    );
    expect(run.asked[preferences].shown, [
      'shared_preferences — Preferences with shared_preferences',
      'None',
    ]);
    final app = run.files.directory('/work/my_app');
    expect(
      app
          .childFile('lib/core/preferences/app_preferences.dart')
          .readAsStringSync(),
      allOf(
        contains('abstract interface class AppPreferences'),
        contains('await impl0.openSharedAppPreferences()'),
      ),
    );
    expect(
      app
          .childFile('lib/core/preferences/shared_app_preferences.dart')
          .readAsStringSync(),
      contains('SharedPreferencesWithCache.create('),
    );
    // The start-up opens the preferences before it fills the container.
    final bootstrap = app.childFile('lib/bootstrap.dart').readAsStringSync();
    expect(
      bootstrap.indexOf('await initPreferences();'),
      inInclusiveRange(0, bootstrap.indexOf('await registerDependencies();')),
    );
    expect(
      app.childFile('lib/core/di/dependencies.dart').readAsStringSync(),
      allOf(
        contains('.registerLazySingleton<'),
        contains('.createAppPreferences()'),
      ),
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(contains('  shared_preferences: '), contains('  get_it: ')),
    );
  });

  test(
      'a run in a terminal asks which module provides the theme after the '
      'localization, and offers material_theme, which brings the '
      'preferences that remember the theme mode without a question, and '
      'whose mode the settings screen lets the user select', () async {
    final run = await _create({
      'Features': ['home'],
      'Infrastructure': [],
      'Layout': ['bottom_tabs'],
      'Settings screen': ['settings'],
      'State management': ['None'],
      'Theme': ['material_theme'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    final messages = [for (final question in run.asked) question.message];
    final theme = messages.indexOf('Theme: which module provides it?');
    expect(
      theme,
      messages.indexOf('Localization: which module provides it?') + 1,
    );
    const materialTheme =
        'material_theme — Light and dark Material 3 themes with a palette '
        'and a bundled font';
    expect(run.asked[theme].shown, [materialTheme, 'None']);
    // The theme role requires the preferences, and shared_preferences is the
    // only module that provides them, so the run does not ask for them.
    expect(messages, isNot(contains(startsWith('Preferences'))));
    expect(
      run.lines,
      contains(
        'Adding shared_preferences: the only provider of the preferences '
        'role, which material_theme requires.',
      ),
    );
    final app = run.files.directory('/work/my_app');
    DartFileIndex indexOf(String path) =>
        DartFileIndexer.index(path, app.childFile(path).readAsStringSync());
    // The file of the module, with the two themes that the root of the app
    // takes, and the files of the role, with the mode and its entry.
    expect(
      [
        for (final declaration
            in indexOf('lib/core/theme/app_theme.dart').declarations)
          declaration.name,
      ],
      containsAll(['seedColor', 'createLightTheme', 'createDarkTheme']),
    );
    expect(
      indexOf('lib/core/theme/theme_mode.dart').declaration('appThemeMode'),
      isNotNull,
    );
    expect(
      indexOf('lib/app.dart')
          .invocations
          .singleWhere((invocation) => invocation.target == 'MaterialApp')
          .namedArguments,
      containsAll(['theme', 'darkTheme', 'themeMode']),
    );
    // The settings screen shows the entry of the theme mode.
    expect(
      [
        for (final invocation
            in indexOf('lib/features/settings/settings_screen.dart')
                .invocations)
          invocation.name,
      ],
      contains('ThemeModeSetting'),
    );
    expect(
      indexOf('lib/core/theme/theme_mode_setting.dart')
          .declaration('ThemeModeSetting'),
      isNotNull,
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      contains('  shared_preferences: '),
    );
  });

  test(
      'a run in a terminal offers the onboarding among the features, and '
      'adds the preferences that it requires without a question; the app '
      'still starts on the start screen', () async {
    final run = await _create({
      'Features': ['home', 'onboarding'],
      'Infrastructure': [],
      'Layout': ['None'],
      'Settings screen': ['None'],
      'State management': ['None'],
      'Theme': ['None'],
      'Localization': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
      'Authentication': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    // shared_preferences is the only module that provides the preferences,
    // which the onboarding requires, so there is nothing to ask.
    expect(
      run.asked.map((question) => question.message),
      isNot(contains(startsWith('Preferences:'))),
    );
    expect(
      run.lines,
      contains(
        'Adding shared_preferences: the only provider of the preferences '
        'role, which onboarding requires.',
      ),
    );
    final app = run.files.directory('/work/my_app');
    expect(
      app
          .childFile('lib/features/onboarding/onboarding_pages.dart')
          .readAsStringSync(),
      allOf(
        // The symbol and the name of the app that the run names.
        contains("symbol: 'Ma',"),
        contains("title: 'My App',"),
        contains("text: 'Welcome! We are glad you are here.',"),
      ),
    );
    // The router asks the guard of the onboarding, which reads what the
    // start-up restored from the preferences.
    expect(
      app.childFile('lib/core/router/app_router.dart').readAsStringSync(),
      allOf(
        contains("'onboarding.firstRun',"),
        contains('allows: guard0.onboardingCompleted(),'),
        contains('redirectTo: const OnboardingOnboardingLocation(),'),
      ),
    );
    expect(
      app
          .childFile('lib/core/preferences/app_preferences.dart')
          .readAsStringSync(),
      contains('restoreOnboarding,'),
    );
    expect(
      app.childFile('lib/bootstrap.dart').readAsStringSync(),
      contains('await initPreferences();'),
    );
    // The onboarding is a route that cannot start the app: once it is
    // finished, the app shows its start screen.
    expect(
      app
          .childFile('lib/core/router/app_router_factory.dart')
          .readAsStringSync(),
      allOf(
        contains("initialLocation: '/home',"),
        contains("path: '/onboarding',"),
      ),
    );
  });

  test(
      'a run in a terminal asks for the infrastructure after the features, '
      'and offers Firebase, which a run that skips external setup leaves for '
      'later', () async {
    final run = await _create(
      {
        'Features': [],
        'Infrastructure': ['firebase_core'],
        'Layout': ['None'],
        'Settings screen': ['None'],
        'Router': ['None'],
        'State management': ['None'],
        'Theme': ['None'],
        'Localization': ['None'],
        'Dependency injection': ['None'],
        'Events': ['None'],
        'Preferences': ['None'],
        'Crash reporting': [],
        'Analytics': [],
        'Authentication': ['None'],
      },
      options: ['--skip-external-setup'],
    );

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message).take(3), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
    ]);
    final app = run.files.directory('/work/my_app');
    expect(app.childFile('lib/firebase_options.dart').existsSync(), isTrue);
    expect(
      app.childFile('lib/bootstrap.dart').readAsStringSync(),
      contains(
        'Firebase.initializeApp(options: '
        'DefaultFirebaseOptions.currentPlatform)',
      ),
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      contains('  firebase_core: '),
    );
    expect(
      app.childFile('README.md').readAsStringSync(),
      contains('\n## Firebase\n'),
    );
    expect(
      run.lines,
      contains(
        // The reason names what the command needs too, which the machine of
        // the test lacks.
        'Configuring Firebase with flutterfire is not done, because the run '
        'skips external setup, and Firebase CLI, Firebase login, FlutterFire '
        'CLI 1.4.1 or a later 1.x and Xcode project tools of flutterfire are '
        'missing. Run it in the app: dart pub global run '
        'flutterfire_cli:flutterfire configure --platforms=android,ios '
        '--overwrite-firebase-options --ios-bundle-id=com.example.my-app '
        '--android-package-name=com.example.my_app',
      ),
    );
    // Nothing continues the configuration in an app without the modules
    // that depend on firebase_core.
    expect(run.lines, isNot(contains(contains('Crashlytics'))));
  });

  test(
      'a run in a terminal asks which modules provide the crash reporting '
      'after the events, and offers Firebase Crashlytics, which brings '
      'Firebase', () async {
    final run = await _create(
      {
        'Features': [],
        'Infrastructure': [],
        'Layout': ['None'],
        'Settings screen': ['None'],
        'Router': ['None'],
        'State management': ['None'],
        'Theme': ['None'],
        'Localization': ['None'],
        'Dependency injection': ['get_it'],
        'Events': ['None'],
        'Preferences': ['None'],
        'Crash reporting': ['firebase_crashlytics'],
        'Analytics': [],
        'Authentication': ['None'],
      },
      options: ['--skip-external-setup'],
    );

    expect(run.code, 0, reason: run.lines.join('\n'));
    // The roles come in the order of the list of modules, and
    // firebase_crashlytics comes after event_bus. An app can report to more
    // than one service, so the question takes any number of answers, none
    // included.
    final messages = [for (final question in run.asked) question.message];
    final crashReporting = messages.indexOf(
      'Crash reporting: which module provides it?',
    );
    expect(
      crashReporting,
      greaterThan(messages.indexOf('Events: which module provides it?')),
    );
    expect(run.asked[crashReporting].shown, [
      'firebase_crashlytics — Firebase Crashlytics with firebase_crashlytics',
    ]);
    // Firebase was not chosen among the infrastructure, but Crashlytics
    // depends on it.
    expect(
      run.lines,
      contains('Adding firebase_core: a dependency of firebase_crashlytics.'),
    );
    final app = run.files.directory('/work/my_app');
    expect(
      app
          .childFile('lib/core/crash_reporting/crash_reporter.dart')
          .readAsStringSync(),
      allOf(
        contains('abstract interface class CrashReporter'),
        contains('impl0.createCrashlyticsCrashReporter'),
      ),
    );
    expect(
      app
          .childFile('lib/core/crash_reporting/crashlytics_crash_reporter.dart')
          .readAsStringSync(),
      contains('FirebaseCrashlytics.instance'),
    );
    expect(app.childFile('lib/firebase_options.dart').existsSync(), isTrue);
    // Firebase starts first, then the crash reporting, then the services
    // of the app.
    const bootstrap = 'lib/bootstrap.dart';
    final calls = DartFileIndexer.index(
      bootstrap,
      app.childFile(bootstrap).readAsStringSync(),
    ).invocations;
    expect(
      [
        for (final call in calls)
          if (call.enclosingDeclaration == 'bootstrap') call.name,
      ],
      ['initializeApp', 'installCrashReporting', 'registerDependencies'],
    );
    expect(
      app.childFile('lib/core/di/dependencies.dart').readAsStringSync(),
      contains('.createCrashReporter()'),
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(
        contains('  firebase_crashlytics: '),
        contains('  firebase_core: '),
      ),
    );
    // The fix of the phase for Crashlytics that flutterfire adds is left
    // for later with the configuration, which it continues.
    expect(
      run.lines,
      containsAllInOrder([
        startsWith('Configuring Firebase with flutterfire is not done'),
        startsWith(
          'Fixing the Crashlytics phase of flutterfire for flutter build ipa '
          'is not done, because it runs after "Configuring Firebase with '
          'flutterfire", which is not done. Run it in the app: ruby -e '
          "'f = ARGV[0]; ",
        ),
      ]),
    );
    expect(
      app.childFile('README.md').readAsStringSync(),
      allOf(contains('\n## Firebase\n'), contains('\n## Crashlytics\n')),
    );
  });

  test(
      'a run in a terminal asks which modules provide the analytics after '
      'the crash reporting, and offers Firebase Analytics, which brings '
      'Firebase and listens to the screen the user sees', () async {
    final run = await _create(
      {
        'Features': ['home'],
        'Infrastructure': [],
        'Layout': ['bottom_tabs'],
        'Settings screen': ['None'],
        'State management': ['None'],
        'Theme': ['None'],
        'Localization': ['None'],
        'Dependency injection': ['None'],
        'Events': ['None'],
        'Preferences': ['None'],
        'Crash reporting': [],
        'Analytics': ['firebase_analytics'],
        'Authentication': ['None'],
      },
      options: ['--skip-external-setup'],
    );

    expect(run.code, 0, reason: run.lines.join('\n'));
    // The roles come in the order of the list of modules, and
    // firebase_analytics comes after firebase_crashlytics. An app can
    // record to more than one service, so the question takes any number of
    // answers, none included.
    final messages = [for (final question in run.asked) question.message];
    final analytics = messages.indexOf('Analytics: which module provides it?');
    expect(
      analytics,
      greaterThan(
        messages.indexOf('Crash reporting: which module provides it?'),
      ),
    );
    expect(run.asked[analytics].shown, [
      'firebase_analytics — Firebase Analytics with firebase_analytics',
    ]);
    // Firebase was not chosen among the infrastructure, but Analytics
    // depends on it.
    expect(
      run.lines,
      contains('Adding firebase_core: a dependency of firebase_analytics.'),
    );
    final app = run.files.directory('/work/my_app');
    expect(
      app
          .childFile('lib/core/analytics/analytics_service.dart')
          .readAsStringSync(),
      allOf(
        contains('abstract interface class AnalyticsService'),
        contains('impl0.createFirebaseAnalyticsService'),
      ),
    );
    expect(
      app
          .childFile('lib/core/analytics/firebase_analytics_service.dart')
          .readAsStringSync(),
      allOf(
        contains('FirebaseAnalytics.instance'),
        contains('void logFirebaseScreenView(String? route, String location)'),
      ),
    );
    // The router tells the listener of Firebase Analytics about the screen
    // the user sees, in the main navigation too, and its navigators have no
    // observer.
    final router = app
        .childFile('lib/core/router/app_router_factory.dart')
        .readAsStringSync();
    expect(
      router,
      allOf(
        contains('show logFirebaseScreenView;'),
        contains('\nlogFirebaseScreenView,\n'),
        contains('..routerDelegate.addListener(_pagesChanged);'),
        contains('_showScreen();'),
        contains('StatefulShellBranch('),
        isNot(contains('FirebaseAnalyticsObserver')),
      ),
    );
    // The service starts without waiting, so bootstrap() only initializes
    // Firebase.
    const bootstrap = 'lib/bootstrap.dart';
    final calls = DartFileIndexer.index(
      bootstrap,
      app.childFile(bootstrap).readAsStringSync(),
    ).invocations;
    expect(
      [
        for (final call in calls)
          if (call.enclosingDeclaration == 'bootstrap') call.name,
      ],
      ['initializeApp'],
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(
        contains('  firebase_analytics: '),
        contains('  firebase_core: '),
      ),
    );
    expect(
      run.lines,
      contains(startsWith('Configuring Firebase with flutterfire is not done')),
    );
  });

  test(
      'a run in a terminal gives an app without a router Firebase Analytics '
      'without screen views, and registers its service in the DI container',
      () async {
    final run = await _create(
      {
        'Features': [],
        'Infrastructure': [],
        'Layout': ['None'],
        'Settings screen': ['None'],
        'Router': ['None'],
        'State management': ['None'],
        'Theme': ['None'],
        'Localization': ['None'],
        'Dependency injection': ['get_it'],
        'Events': ['None'],
        'Preferences': ['None'],
        'Crash reporting': [],
        'Analytics': ['firebase_analytics'],
        'Authentication': ['None'],
      },
      options: ['--skip-external-setup'],
    );

    expect(run.code, 0, reason: run.lines.join('\n'));
    final app = run.files.directory('/work/my_app');
    expect(app.childDirectory('lib/core/router').existsSync(), isFalse);
    expect(
      app
          .childFile('lib/core/analytics/firebase_analytics_service.dart')
          .existsSync(),
      isTrue,
    );
    final lib = [
      for (final entity in app.childDirectory('lib').listSync(recursive: true))
        if (entity is File) entity.readAsStringSync(),
    ];
    expect(
      lib,
      everyElement(
        allOf(
          isNot(contains('logScreenView')),
          isNot(contains('logFirebaseScreenView')),
          isNot(contains('FirebaseAnalyticsObserver')),
        ),
      ),
    );
    expect(
      app.childFile('lib/core/di/dependencies.dart').readAsStringSync(),
      contains('.createAnalyticsService()'),
    );
  });

  test(
      'a run in a terminal asks last which module provides the '
      'authentication, offers Firebase Authentication, which brings '
      'Firebase, and then asks who may use the app without an account',
      () async {
    final run = await _create(
      {
        'Features': [],
        'Infrastructure': [],
        'Layout': ['None'],
        'Settings screen': ['None'],
        'Router': ['None'],
        'State management': ['None'],
        'Theme': ['None'],
        'Localization': ['None'],
        'Dependency injection': ['None'],
        'Events': ['None'],
        'Preferences': ['None'],
        'Crash reporting': [],
        'Analytics': [],
        'Authentication': ['firebase_auth'],
        'Who may use the app': ['Everyone, as an anonymous user'],
      },
      options: ['--skip-external-setup'],
    );

    expect(run.code, 0, reason: run.lines.join('\n'));
    // The roles come in the order of the list of modules, and firebase_auth
    // is last. An app has one provider of sign-in, or none. The mode of the
    // auth role is a choice of the role, which it asks for once the modules
    // of the app are known, with the default first.
    final [..., provider, mode] = run.asked;
    expect(provider.message, 'Authentication: which module provides it?');
    expect(provider.shown, [
      'firebase_auth — Firebase Authentication with firebase_auth',
      'None',
    ]);
    expect(mode.message, 'Who may use the app without an account?');
    expect(mode.shown, [
      'Nobody: the user signs in first',
      'Everyone: an account only where a screen needs one',
      'Everyone, as an anonymous user with an id from the start',
    ]);
    // Firebase was not chosen among the infrastructure, but Firebase
    // Authentication depends on it.
    expect(
      run.lines,
      contains('Adding firebase_core: a dependency of firebase_auth.'),
    );
    final app = run.files.directory('/work/my_app');
    expect(
      app.childFile('lib/core/auth/app_session.dart').readAsStringSync(),
      allOf(
        contains('const AuthMode authMode = AuthMode.anonymous;'),
        contains('_authService = impl0.createFirebaseAuthService();'),
      ),
    );
    expect(
      app
          .childFile('lib/core/auth/firebase_auth_service.dart')
          .readAsStringSync(),
      contains('FirebaseAuthService(FirebaseAuth.instance)'),
    );
    // Firebase starts first, then the session of the app on it.
    const bootstrap = 'lib/bootstrap.dart';
    final calls = DartFileIndexer.index(
      bootstrap,
      app.childFile(bootstrap).readAsStringSync(),
    ).invocations;
    expect(
      [
        for (final call in calls)
          if (call.enclosingDeclaration == 'bootstrap') call.name,
      ],
      ['initializeApp', 'initAuth'],
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(contains('  firebase_auth: '), contains('  firebase_core: ')),
    );
    // The README tells the mode of the app, and where the ways to sign in
    // of that mode are enabled in the Firebase project.
    expect(
      app.childFile('README.md').readAsStringSync(),
      allOf(
        contains('\n## Firebase\n'),
        contains('\n## Firebase Authentication\n'),
        contains('\n## Sign-in\n'),
        contains('This app was generated in the mode `anonymous`'),
      ),
    );
  });

  test(
      'a run in a terminal offers the sign-in among the features, asks '
      'which module manages the state of its screens, with no choice of '
      'none, adds the only providers of the authentication and of the '
      'settings screen without a question, and asks who may use the app '
      'without an account', () async {
    final run = await _create(
      {
        'Features': ['home', 'sign_in'],
        'Infrastructure': [],
        'Layout': ['None'],
        'State management': ['riverpod'],
        'Theme': ['None'],
        'Localization': ['None'],
        'Dependency injection': ['None'],
        'Events': ['None'],
        'Preferences': ['None'],
        'Crash reporting': [],
        'Analytics': [],
        'Who may use the app': ['Nobody'],
      },
      options: ['--skip-external-setup'],
    );

    expect(run.code, 0, reason: run.lines.join('\n'));
    final asked = {
      for (final question in run.asked) question.message: question.shown,
    };
    // The screens of the sign-in keep their state with the state manager
    // of the app, so the app has one: the question says who requires it
    // and has no None.
    expect(
      asked['State management: sign_in requires the state management role. '
          'Which module provides it?'],
      [
        'bloc — BLoC with flutter_bloc',
        'riverpod — Riverpod with flutter_riverpod',
      ],
    );
    // firebase_auth is the only module that provides the authentication,
    // which the sign-in requires, so there is nothing to ask.
    expect(asked.keys, isNot(contains(startsWith('Authentication:'))));
    expect(
      run.lines,
      contains(
        'Adding firebase_auth: the only provider of the authentication '
        'role, which sign_in requires.',
      ),
    );
    expect(
      run.lines,
      contains('Adding firebase_core: a dependency of firebase_auth.'),
    );
    // Nor about the settings screen, which has the entry of the account.
    expect(asked.keys, isNot(contains(startsWith('Settings screen'))));
    expect(
      run.lines,
      contains(
        'Adding settings: the only provider of the settings screen role, '
        'which sign_in requires.',
      ),
    );
    // The mode of the auth role is asked last, as in an app without the
    // screens.
    expect(run.asked.last.message, 'Who may use the app without an account?');
    final app = run.files.directory('/work/my_app');
    // The screens come with the state layer of the chosen state manager.
    expect(
      app.childFile('lib/features/sign_in/sign_in_notifier.dart').existsSync(),
      isTrue,
    );
    expect(
      app.childFile('lib/features/sign_in/sign_in_cubit.dart').existsSync(),
      isFalse,
    );
    // The settings screen has the entry of the account, which leads to the
    // screen of the account.
    expect(
      app
          .childFile('lib/features/settings/settings_screen.dart')
          .readAsStringSync(),
      contains('AccountSetting()'),
    );
    expect(
      app.childFile('lib/features/sign_in/account_screen.dart').existsSync(),
      isTrue,
    );
    expect(
      app.childFile('pubspec.yaml').readAsStringSync(),
      allOf(contains('  flutter_riverpod: '), isNot(contains('flutter_bloc'))),
    );
    // The router asks the two guards of the sign-in, which read the
    // session of the app, and the app starts on the start screen once the
    // gate allows.
    expect(
      app.childFile('lib/core/router/app_router.dart').readAsStringSync(),
      allOf(
        contains("'sign_in.gate',"),
        contains('allows: guard0.signInAllowsApp(),'),
        contains("'sign_in.hasAccount',"),
        contains('allows: guard0.signInHasAccount(),'),
        contains('redirectTo: const SignInSignInLocation(),'),
      ),
    );
    expect(
      app
          .childFile('lib/core/router/app_router_factory.dart')
          .readAsStringSync(),
      allOf(
        contains("initialLocation: '/home',"),
        contains("path: '/sign_in',"),
      ),
    );
  });

  test(
      'the router asks the guard of the onboarding before the gate of the '
      'sign-in, whichever of the two features was picked first, so a first '
      'launch shows the onboarding and then the sign-in', () async {
    final guards = <String, List<String>>{};
    for (final modules in [
      'onboarding,sign_in,bloc',
      'sign_in,bloc,onboarding',
    ]) {
      final run = await _create(
        {},
        options: ['--no-input', '--skip-external-setup', '-m', modules],
      );
      expect(run.code, 0, reason: run.lines.join('\n'));
      final router = run.files
          .file('/work/my_app/lib/core/router/app_router.dart')
          .readAsStringSync();
      guards[modules] = [
        for (final match
            in RegExp(r"RouteGuard\(\s*'([^']+)',").allMatches(router))
          match.group(1)!,
      ];
    }

    // The router shows the target of the first guard that does not allow.
    // The guard of the onboarding is of an earlier stage than those of the
    // sign-in, which decides their order, not the order of the modules.
    expect(guards, {
      'onboarding,sign_in,bloc': [
        'onboarding.firstRun',
        'sign_in.gate',
        'sign_in.hasAccount',
      ],
      'sign_in,bloc,onboarding': [
        'onboarding.firstRun',
        'sign_in.gate',
        'sign_in.hasAccount',
      ],
    });
  });
}
