import 'dart:convert';

import 'package:file/memory.dart';
import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/src/resolver.dart';

// The tests reach the stages of the pipeline, which the public library
// keeps internal, through this file.
export 'package:smf_pipeline/src/choices.dart';
export 'package:smf_pipeline/src/collector.dart';
export 'package:smf_pipeline/src/errors.dart';
export 'package:smf_pipeline/src/explain.dart';
export 'package:smf_pipeline/src/identity.dart';
export 'package:smf_pipeline/src/order.dart';
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

/// The module that provides the app entry in tests.
TestModule scaffold({List<Contribution> contributions = const []}) =>
    TestModule(
      'scaffold',
      kind: ModuleKinds.scaffold,
      providers: [const RoleProvider.plain(appEntryRole)],
      contributions: contributions,
    );

/// A brick with the tags of every socket of the app entry.
BrickContribution entryBrick() => BrickContribution(
      bundle(
        'entry',
        files: {
          'lib/entry.dart': [
            for (final socket in appEntryRole.sockets)
              for (final tag in socket.tags) '{{{$tag}}}',
          ].join('\n'),
        },
      ),
    );

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
