import 'dart:convert';

import 'package:file/memory.dart';
import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/resolver.dart';

// The tests reach the stages of the pipeline, which the public library
// keeps internal, through this file.
export 'package:smf_pipeline/src/choices.dart';
export 'package:smf_pipeline/src/collector.dart';
export 'package:smf_pipeline/src/environment.dart';
export 'package:smf_pipeline/src/errors.dart';
export 'package:smf_pipeline/src/explain.dart';
export 'package:smf_pipeline/src/identity.dart';
export 'package:smf_pipeline/src/order.dart';
export 'package:smf_pipeline/src/pipeline.dart';
export 'package:smf_pipeline/src/postgen.dart';
export 'package:smf_pipeline/src/preflight.dart';
export 'package:smf_pipeline/src/pubspec.dart';
export 'package:smf_pipeline/src/resolver.dart';
export 'package:smf_pipeline/src/selection.dart';
export 'package:smf_pipeline/src/validation.dart';

/// A role for tests, configured through its constructor.
final class TestRole<D extends Object> extends Role<D> {
  TestRole(
    this.id, {
    this.cardinality = RoleCardinality.atMostOne,
    Set<Role> requires = const {},
    Set<Role> uses = const {},
    this.sockets = const [],
    this.socketFamilies = const [],
    this.options = const [],
    this.template,
    this.moduleRules = const [],
    this.openToAllModules = false,
  })  : _requires = requires,
        _uses = uses;

  @override
  final String id;

  @override
  String get description => 'Test role $id';

  @override
  final RoleCardinality cardinality;

  @override
  final bool openToAllModules;

  final Set<Role> _requires;
  final Set<Role> _uses;

  @override
  Set<Role> get requires => _requires;

  @override
  Set<Role> get uses => _uses;

  @override
  final List<SocketRef> sockets;

  @override
  final List<SocketFamily<Object?, SocketKind>> socketFamilies;

  @override
  final List<RoleOption> options;

  @override
  final RoleTemplate<D>? template;

  @override
  final List<ModuleRule<D>> moduleRules;
}

/// A template for tests that returns what it is given and records its
/// calls.
final class TestTemplate<D extends Object> extends RoleTemplate<D> {
  TestTemplate({
    this.contributions = const [],
    this.issues = const [],
    this.choice,
  });

  final List<Contribution> contributions;
  final List<SmfIssue> issues;
  final Object? choice;

  /// The inputs of [validate], in order.
  final List<RoleHookInput<D>> validated = [];

  /// The contexts of [choose], in order.
  final List<RoleChoiceContext<D>> chosen = [];

  @override
  List<Contribution> contribute(ModuleContext context) => contributions;

  @override
  List<SmfIssue> validate(RoleHookInput<D> input) {
    validated.add(input);
    return issues;
  }

  @override
  Future<Object?> choose(RoleChoiceContext<D> context) async {
    chosen.add(context);
    return choice;
  }
}

/// A provider for tests that returns [issues] from [validate].
final class TestProvider<D extends Object> extends RoleProvider<D> {
  TestProvider(this.role, {this.issues = const []});

  @override
  final Role<D> role;

  final List<SmfIssue> issues;

  /// The inputs of [validate], in order.
  final List<RoleHookInput<D>> validated = [];

  @override
  List<SmfIssue> validate(RoleHookInput<D> input) {
    validated.add(input);
    return issues;
  }
}

/// A module for tests with a fixed descriptor and contributions.
final class TestModule extends SmfModule {
  TestModule(
    String id, {
    ModuleKind kind = plainKind,
    Set<String> dependsOn = const {},
    Set<Role> requires = const {},
    Set<Role> uses = const {},
    List<RoleProvider> providers = const [],
    Variants? variants,
    List<SocketRef> sockets = const [],
    List<SocketFamily<Object?, SocketKind>> socketFamilies = const [],
    this.contributions = const [],
    String? description,
  }) : descriptor = ModuleDescriptor(
          id: ModuleId(id),
          description: description ?? 'The module $id',
          kind: kind,
          dependsOn: {for (final id in dependsOn) ModuleId(id)},
          requires: requires,
          uses: uses,
          providers: providers,
          variants: variants,
          sockets: sockets,
          socketFamilies: socketFamilies,
        );

  @override
  final ModuleDescriptor descriptor;

  final List<Contribution> contributions;

  @override
  List<Contribution> contribute(ModuleContext context) => contributions;
}

/// A kind without rules, for tests.
const plainKind = ModuleKind(id: 'plain', label: 'Plain modules');

/// The module that provides the app entry in tests, with the base value of
/// the minimum iOS version, the Dart SDK constraint and the dependency on
/// Flutter, as flutter_core contributes them.
TestModule scaffold({List<Contribution> contributions = const []}) =>
    TestModule(
      'scaffold',
      kind: ModuleKinds.scaffold,
      providers: [const RoleProvider.plain(appEntryRole)],
      contributions: [
        AppEntryRole.iosDeploymentTarget.value('13.0'),
        const PubspecContribution.environment(sdk: '^3.8.1'),
        const PubspecContribution.sdk('flutter'),
        ...contributions,
      ],
    );

/// The files of [entryBrick].
const Map<String, String> entryFiles = {
  'pubspec.yaml': '''
name: {{app_name}}
publish_to: none

{{{smf_pubspec_environment}}}

{{{smf_pubspec_dependencies}}}

{{{smf_pubspec_dev_dependencies}}}

{{{smf_pubspec_flutter}}}
''',
  'lib/main.dart': '''
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(
    {{{smf_app_entry__root_wrappers_open}}}const App(){{{smf_app_entry__root_wrappers_close}}},
  );
}
''',
  'lib/bootstrap.dart': '''
{{{smf_app_entry__top_level}}}

Future<void> bootstrap() async {
{{{smf_app_entry__bootstrap_early}}}
{{{smf_app_entry__bootstrap_platform}}}
{{{smf_app_entry__bootstrap_di}}}
{{{smf_app_entry__bootstrap_late}}}
}
''',
  'lib/app.dart': '''
import 'package:flutter/material.dart';

import 'core/app/fallback_start_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
{{{smf_app_entry__app_args}}}
        builder: (context, child) =>
            {{{smf_app_entry__app_builder_open}}}child!{{{smf_app_entry__app_builder_close}}},
        home: const FallbackStartScreen(),
      );
}
''',
  'lib/core/app/fallback_start_screen.dart': '''
import 'package:flutter/widgets.dart';

class FallbackStartScreen extends StatelessWidget {
  const FallbackStartScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
  'android/app/src/main/AndroidManifest.xml': '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
{{{smf_app_entry__android_manifest_permissions}}}
    <application>
        <activity android:name=".MainActivity">
{{{smf_app_entry__main_activity_intent_filters}}}
        </activity>
{{{smf_app_entry__android_manifest_application_meta}}}
    </application>
</manifest>
''',
  'android/settings.gradle.kts': '''
plugins {
{{{smf_app_entry__gradle_settings_plugins}}}
}
''',
  'android/app/build.gradle.kts': '''
plugins {
{{{smf_app_entry__gradle_app_plugins}}}
}

dependencies {
{{{smf_app_entry__gradle_app_dependencies}}}
}
''',
  'ios/Podfile':
      "platform :ios, '{{{smf_app_entry__ios_deployment_target}}}'\n",
  'ios/Runner/Info.plist': '''
<plist version="1.0">
<dict>
{{{smf_app_entry__info_plist}}}
</dict>
</plist>
''',
};

/// A brick of a small app with the tags of every socket of the app entry,
/// and of the pipeline in its pubspec; see [entryFiles].
BrickContribution entryBrick() =>
    BrickContribution(bundle('entry', files: entryFiles));

/// The context of a test app.
const testContext = ModuleContext(
  appName: 'my_app',
  orgName: 'com.example',
  appIdentity: AppIdentity(
    androidApplicationId: 'com.example.my_app',
    iosBundleId: 'com.example.my-app',
    androidNamespace: 'com.example.my_app',
  ),
);

/// A bundle named [name] with empty files at [paths] and the [files] with
/// their text.
MasonBundle bundle(
  String name, {
  List<String> paths = const [],
  Map<String, String> files = const {},
  bool hooks = false,
}) =>
    MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final path in paths) MasonBundledFile(path, '', 'text'),
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
      hooks: [
        if (hooks) const MasonBundledFile('hooks/pre_gen.dart', '', 'text'),
      ],
    );

/// What the logger of a [FakeHost] received.
final class FakeLogger implements SmfLogger {
  final List<String> infos = [];
  final List<String> details = [];
  final List<String> warnings = [];
  final List<String> errors = [];
  final List<String> successes = [];

  @override
  void info(String message) => infos.add(message);

  @override
  void detail(String message) => details.add(message);

  @override
  void warn(String message) => warnings.add(message);

  @override
  void error(String message) => errors.add(message);

  @override
  void success(String message) => successes.add(message);

  @override
  SmfProgress progress(String message) => _Progress();
}

final class _Progress implements SmfProgress {
  @override
  void complete([String? message]) {}

  @override
  void fail([String? message]) {}

  @override
  void update(String message) {}
}

/// A question the [ScriptedPrompter] was asked.
final class Prompt {
  const Prompt(this.kind, this.message, this.shown);

  /// `confirm`, `input`, `select` or `multiSelect`.
  final String kind;

  final String message;

  /// The displayed choices of a selection.
  final List<String> shown;

  @override
  String toString() => '$kind: $message $shown';
}

/// A prompter that answers from a script and records the questions.
///
/// Each answer is, by kind of question:
/// - `confirm`: a bool;
/// - `input`: a string, or `null` for the default value;
/// - `select`: the start of the displayed choice to pick;
/// - `multiSelect`: the starts of the displayed choices to pick.
final class ScriptedPrompter implements SmfPrompter {
  ScriptedPrompter(List<Object?> answers) : _answers = [...answers];

  final List<Object?> _answers;

  /// The questions asked, in order.
  final List<Prompt> asked = [];

  Object? _next(Prompt prompt) {
    asked.add(prompt);
    if (_answers.isEmpty) throw StateError('Unexpected question: $prompt');
    return _answers.removeAt(0);
  }

  /// Whether every answer was used.
  bool get done => _answers.isEmpty;

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async =>
      _next(Prompt('confirm', message, const [])) as bool? ?? defaultValue;

  @override
  Future<String> input(String message, {String? defaultValue}) async =>
      _next(Prompt('input', message, const [])) as String? ??
      defaultValue ??
      '';

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) async {
    final shown = [for (final c in choices) display?.call(c) ?? '$c'];
    final answer = _next(Prompt('select', message, shown))! as String;
    final index = shown.indexWhere((text) => text.startsWith(answer));
    if (index < 0) throw StateError('No choice "$answer" in $shown');
    return choices[index];
  }

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) async {
    final shown = [for (final c in choices) display?.call(c) ?? '$c'];
    final answer = _next(Prompt('multiSelect', message, shown))! as List;
    return [
      for (var i = 0; i < choices.length; i++)
        if (answer.any((start) => shown[i].startsWith(start as String)))
          choices[i],
    ];
  }
}

/// A process runner that answers `run` from [results], by executable, and
/// records the calls.
final class ScriptedProcessRunner implements SmfProcessRunner {
  ScriptedProcessRunner(this.results);

  final Map<String, SmfProcessResult> results;

  /// The calls, as the executable followed by the arguments.
  final List<List<String>> calls = [];

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async {
    calls.add([executable, ...arguments]);
    return results[executable] ??
        (throw StateError('Unexpected command $executable'));
  }

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) =>
      throw UnimplementedError('runInteractive $executable');
}

/// A process runner that fails on every call; the stages 1 to 7 run no
/// commands themselves.
final class NoProcessRunner implements SmfProcessRunner {
  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) =>
      throw UnimplementedError('run $executable');

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) =>
      throw UnimplementedError('runInteractive $executable');
}

/// A host for tests: an in-memory file system whose current directory is
/// `/work`, with a Flutter SDK in `/sdk/bin` on the `PATH` unless
/// `flutter` is `false`.
final class FakeHost {
  FakeHost({
    List<Object?> answers = const [],
    bool terminal = false,
    bool flutter = true,
    Map<String, String>? environment,
    this.operatingSystem = HostOperatingSystem.linux,
    SmfProcessRunner? processRunner,
  })  : prompter = ScriptedPrompter(answers),
        processRunner = processRunner ?? NoProcessRunner(),
        _terminal = terminal,
        fileSystem = MemoryFileSystem.test(
          style: operatingSystem == HostOperatingSystem.windows
              ? FileSystemStyle.windows
              : FileSystemStyle.posix,
        ) {
    final context = fileSystem.path;
    final root = operatingSystem == HostOperatingSystem.windows ? r'C:\' : '/';
    final work = fileSystem.directory(context.join(root, 'work'))
      ..createSync(recursive: true);
    fileSystem.currentDirectory = work;
    final bin = context.join(root, 'sdk', 'bin');
    if (flutter) {
      final windows = operatingSystem == HostOperatingSystem.windows;
      for (final name
          in windows ? ['flutter.bat', 'dart.bat'] : ['flutter', 'dart']) {
        fileSystem.file(context.join(bin, name)).createSync(recursive: true);
      }
      // What tells the bin directory of a Flutter SDK apart.
      fileSystem
          .directory(context.join(bin, 'cache', 'dart-sdk'))
          .createSync(recursive: true);
    }
    variables = environment ?? {'PATH': bin};
  }

  final ScriptedPrompter prompter;
  final SmfProcessRunner processRunner;
  final FakeLogger logger = FakeLogger();
  final MemoryFileSystem fileSystem;
  final HostOperatingSystem operatingSystem;
  final bool _terminal;
  late final Map<String, String> variables;

  SmfHost get host => SmfHost(
        prompter: prompter,
        processRunner: processRunner,
        logger: logger,
        fileSystem: fileSystem,
        environmentVariables: variables,
        operatingSystem: operatingSystem,
        hasTerminal: _terminal,
      );

  /// An environment of a run on this host.
  PipelineEnvironment environment({
    bool? interactive,
    bool skipExternalSetup = false,
  }) =>
      PipelineEnvironment(
        host,
        interactive: interactive ?? _terminal,
        skipExternalSetup: skipExternalSetup,
      );
}

/// A resolution of [modules], each requested, without variants.
Resolution resolutionOf(List<SmfModule> modules) => Resolution([
      for (final module in modules) ResolvedModule(module, const Requested()),
    ]);

/// A check for tests that reports [status], and after [install] reports
/// [afterInstall].
final class TestCheck extends PreflightCheck {
  TestCheck(
    this.id, {
    required this.status,
    this.afterInstall,
    this.required = false,
    this.binDirs = const [],
  });

  @override
  final String id;

  @override
  String get description => 'Tool $id';

  @override
  final bool required;

  PreflightStatus status;
  final PreflightStatus? afterInstall;
  final List<String> binDirs;

  int checks = 0;
  int installs = 0;

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    checks++;
    return status;
  }

  @override
  Future<ToolInstall> install(SmfEnvironment environment) async {
    installs++;
    if (afterInstall != null) status = afterInstall!;
    return ToolInstall(binDirs: binDirs);
  }
}

/// A command that a [RecordingRunner] was asked to run.
final class RecordedCall {
  const RecordedCall({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
    required this.runInShell,
    required this.interactive,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final bool runInShell;
  final bool interactive;

  /// The executable's name and the arguments, as a line.
  String get line => [executable.split('/').last, ...arguments].join(' ');

  @override
  String toString() => line;
}

/// A process runner that records every call and answers with [onRun] and
/// [onInteractive]; by default every command succeeds.
final class RecordingRunner implements SmfProcessRunner {
  RecordingRunner({this.onRun, this.onInteractive});

  /// Answers a call of [run].
  SmfProcessResult Function(RecordedCall call)? onRun;

  /// Answers a call of [runInteractive] with an exit code.
  int Function(RecordedCall call)? onInteractive;

  /// The calls, in order.
  final List<RecordedCall> calls = [];

  /// The lines of the calls, in order.
  List<String> get lines => [for (final call in calls) call.line];

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async {
    final call = RecordedCall(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
      interactive: false,
    );
    calls.add(call);
    return onRun?.call(call) ?? const SmfProcessResult(exitCode: 0);
  }

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async {
    final call = RecordedCall(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
      interactive: true,
    );
    calls.add(call);
    return onInteractive?.call(call) ?? 0;
  }
}
