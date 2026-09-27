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
      'State management': ['bloc'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
    ]);
    expect(run.asked[0].shown, [
      'home — Start screen with the name of the app',
    ]);
    expect(run.asked[1].shown, [
      'firebase_core — Firebase with firebase_core',
    ]);
    expect(run.asked[2].shown, [
      'bottom_tabs — Tabs in a bar at the bottom of the app',
      'None',
    ]);
    expect(run.asked[3].shown, [
      'bloc — BLoC with flutter_bloc',
      'riverpod — Riverpod with flutter_riverpod',
      'None',
    ]);
    // go_router is the only module that provides the router.
    expect(
      run.lines,
      contains(
        'Adding go_router: the only provider of the router (home requires '
        'the router).',
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
      'State management': ['riverpod'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
    ]);
    expect(
      run.lines,
      contains(
        'Adding go_router: the only provider of the router (home requires '
        'the router).',
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
        contains("Destination(label: 'Home', icon: Icons.home)"),
        contains("initialLocation: '/home',"),
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
      'State management': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
    ]);
    expect(
      run.lines,
      contains(
        'Adding go_router: the only provider of the router (bottom_tabs '
        'requires the router).',
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
      'Router': ['go_router'],
      'State management': ['None'],
      'Dependency injection': ['None'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Infrastructure: which do you want?',
      'Layout: which module provides it?',
      'Router: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
      'Events: which module provides it?',
      'Crash reporting: which module provides it?',
      'Analytics: which module provides it?',
    ]);
    expect(run.asked[3].shown, [
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
      'a run in a terminal asks which module provides dependency injection '
      'after the state management, and offers get_it', () async {
    final run = await _create({
      'Features': ['home'],
      'Infrastructure': [],
      'Layout': ['None'],
      'State management': ['None'],
      'Dependency injection': ['get_it'],
      'Events': ['None'],
      'Crash reporting': [],
      'Analytics': [],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    final messages = [for (final question in run.asked) question.message];
    final di = messages.indexOf(
      'Dependency injection: which module provides it?',
    );
    // The roles come in the order of the list of modules, and get_it is
    // after the modules of the state management.
    expect(
      di,
      greaterThan(
        messages.indexOf('State management: which module provides it?'),
      ),
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
      'Router': ['None'],
      'State management': ['None'],
      'Dependency injection': ['get_it'],
      'Events': ['event_bus'],
      'Crash reporting': [],
      'Analytics': [],
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
      'a run in a terminal asks for the infrastructure after the features, '
      'and offers Firebase, which a run that skips external setup leaves for '
      'later', () async {
    final run = await _create(
      {
        'Features': [],
        'Infrastructure': ['firebase_core'],
        'Layout': ['None'],
        'Router': ['None'],
        'State management': ['None'],
        'Dependency injection': ['None'],
        'Events': ['None'],
        'Crash reporting': [],
        'Analytics': [],
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
      containsAllInOrder([
        equals(
          'Configuring Firebase with flutterfire is not done, because the run '
          'skips external setup. Run it in the app: dart pub global run '
          'flutterfire_cli:flutterfire configure --platforms=android,ios '
          '--overwrite-firebase-options --ios-bundle-id=com.example.my-app '
          '--android-package-name=com.example.my_app',
        ),
        startsWith(
          'Fixing the Crashlytics phase of flutterfire, if any, for flutter '
          'build ipa is not done, because it runs after "Configuring Firebase '
          'with flutterfire", which is not done. Run it in the app: ruby -e '
          "'f = ARGV[0]; ",
        ),
      ]),
    );
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
        'Router': ['None'],
        'State management': ['None'],
        'Dependency injection': ['get_it'],
        'Events': ['None'],
        'Crash reporting': ['firebase_crashlytics'],
        'Analytics': [],
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
        contains('createCrashlyticsCrashReporter()'),
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
    expect(
      run.lines,
      contains(startsWith('Configuring Firebase with flutterfire is not done')),
    );
  });

  test(
      'a run in a terminal asks last which modules provide the analytics, and '
      'offers Firebase Analytics, which brings Firebase and listens to the '
      'screen the user sees', () async {
    final run = await _create(
      {
        'Features': ['home'],
        'Infrastructure': [],
        'Layout': ['bottom_tabs'],
        'State management': ['None'],
        'Dependency injection': ['None'],
        'Events': ['None'],
        'Crash reporting': [],
        'Analytics': ['firebase_analytics'],
      },
      options: ['--skip-external-setup'],
    );

    expect(run.code, 0, reason: run.lines.join('\n'));
    // The roles come in the order of the list of modules, and
    // firebase_analytics is last. An app can record to more than one
    // service, so the question takes any number of answers, none included.
    expect(run.asked.last.message, 'Analytics: which module provides it?');
    expect(run.asked.last.shown, [
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
        contains('createFirebaseAnalyticsService()'),
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
        contains('..routerDelegate.addListener(_showScreen);'),
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
        'Router': ['None'],
        'State management': ['None'],
        'Dependency injection': ['get_it'],
        'Events': ['None'],
        'Crash reporting': [],
        'Analytics': ['firebase_analytics'],
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
}
