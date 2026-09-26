import 'package:file/memory.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
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

/// Runs `smf create my_app` with the modules of the CLI in a terminal that
/// answers with [answers], on a machine with a Flutter SDK whose commands
/// all succeed; the app goes to `/work/my_app`.
Future<_Run> _create(Map<String, List<String>> answers) async {
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
    ['create', 'my_app', '--org', 'com.example'],
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
      'Layout': ['None'],
      'State management': ['bloc'],
      'Dependency injection': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Layout: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
    ]);
    expect(run.asked[0].shown, [
      'home — Start screen with the name of the app',
    ]);
    expect(run.asked[1].shown, [
      'bottom_tabs — Tabs in a bar at the bottom of the app',
      'None',
    ]);
    expect(run.asked[2].shown, [
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
      'Layout': ['bottom_tabs'],
      'State management': ['riverpod'],
      'Dependency injection': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Layout: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
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
      'Layout': ['bottom_tabs'],
      'State management': ['None'],
      'Dependency injection': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Layout: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
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
      'Layout': ['None'],
      'Router': ['go_router'],
      'State management': ['None'],
      'Dependency injection': ['None'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(run.asked.map((question) => question.message), [
      'Features: which do you want?',
      'Layout: which module provides it?',
      'Router: which module provides it?',
      'State management: which module provides it?',
      'Dependency injection: which module provides it?',
    ]);
    expect(run.asked[2].shown, [
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
      'a run in a terminal asks last which module provides dependency '
      'injection, and offers get_it', () async {
    final run = await _create({
      'Features': ['home'],
      'Layout': ['None'],
      'State management': ['None'],
      'Dependency injection': ['get_it'],
    });

    expect(run.code, 0, reason: run.lines.join('\n'));
    expect(
      run.asked.last.message,
      'Dependency injection: which module provides it?',
    );
    expect(run.asked.last.shown, [
      'get_it — Service locator with get_it',
      'None',
    ]);
    final app = run.files.directory('/work/my_app');
    // No module of the CLI registers a service yet.
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
}
