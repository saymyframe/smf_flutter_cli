import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The data [value] for [role], contributed by the module [module].
RoleData<Object> dataOf<D extends Object>(
  Role<D> role,
  D value, {
  String module = 'home',
}) =>
    role.data(value).withOrigin(ModuleOrigin(ModuleId(module)));

/// The input of the hooks of [role] in an app with [data], where the roles
/// in [present] and [role] itself are present.
RoleHookInput<D> inputOf<D extends Object>(
  Role<D> role, {
  List<RoleData<Object>> data = const [],
  Set<Role> present = const {},
  Object? choice,
}) =>
    role.hookInput(
      RoleHookRequest(
        data: data,
        presentRoles: {role, ...present},
        context: testContext,
        choices: {role: choice},
      ),
    );

/// Renders the files of [bundle] with [vars], in memory.
Future<Map<String, String>> renderBundle(
  MasonBundle bundle,
  Map<String, Object?> vars,
) async {
  final generator = MasonGenerator(
    bundle.name,
    bundle.description,
    files: [
      for (final file in bundle.files)
        TemplateFile.fromBytes(file.path, base64.decode(file.data)),
    ],
  );
  final target = _MemoryTarget();
  await generator.generate(target, vars: vars);
  return target.files;
}

final class _MemoryTarget extends GeneratorTarget {
  final files = <String, String>{};

  @override
  Future<GeneratedFile> createFile(
    String path,
    List<int> contents, {
    Logger? logger,
    OverwriteRule? overwriteRule,
  }) async {
    files[path] = utf8.decode(contents);
    return GeneratedFile.created(path: path);
  }
}

/// The text of every file of [bundle], by path.
Map<String, String> templatesOf(MasonBundle bundle) => {
      for (final file in bundle.files)
        file.path: utf8.decode(base64.decode(file.data)),
    };

final RegExp _tag = RegExp(r'\{\{\{(smf_[a-z0-9_]+)\}\}\}');

/// What rendering the template of a role produced.
final class RenderedTemplate {
  RenderedTemplate._(this.files, this.contributions, this.elsewhere);

  /// The generated files, by path relative to the project root.
  final Map<String, String> files;

  /// What the template's `contribute` hook returned.
  final List<Contribution> contributions;

  /// Fragments of `render` for sockets whose tags are not in the template,
  /// such as the phases of `bootstrap()`.
  final List<SocketContribution> elsewhere;
}

/// Renders the template of [role] as the pipeline will: its bricks with the
/// presence flags, the variables of its `render` hook, and the sockets of
/// its files filled with the fragments of `render`, whose imports are added
/// to the files that hold the sockets' tags.
Future<RenderedTemplate> renderTemplate<D extends Object>(
  Role<D> role, {
  List<RoleData<Object>> data = const [],
  Set<Role> present = const {},
  Object? choice,
}) async {
  final template = role.template!;
  final contributions = template.contribute(testContext);
  final input = inputOf(role, data: data, present: present, choice: choice);
  final output = template.render(input);

  final fragments = <SocketRef, List<SocketContribution>>{};
  for (final fragment in [
    ...contributions.whereType<SocketContribution>(),
    ...output.fragments,
  ]) {
    fragments.putIfAbsent(fragment.socket, () => []).add(fragment);
  }

  final files = <String, String>{};
  final placed = <SocketRef>{};
  for (final brick in contributions.whereType<BrickContribution>()) {
    final templates = templatesOf(brick.bundle);
    final vars = <String, Object?>{
      'app_name': testContext.appName,
      'org_name': testContext.orgName,
      role.presenceFlag: true,
      for (final other in role.visibleRoles)
        other.presenceFlag: present.contains(other),
      ...output.vars,
    };
    final importsByFile = <String, List<ImportRef>>{};
    for (final MapEntry(key: path, value: text) in templates.entries) {
      for (final match in _tag.allMatches(text)) {
        final tag = match.group(1)!;
        final socket = [...role.sockets, ...appEntryRole.sockets]
            .where((socket) => socket.tags.contains(tag))
            .firstOrNull;
        if (socket == null) fail('Unknown tag $tag in $path');
        final contributed = fragments[socket] ?? const [];
        placed.add(socket);
        vars.addAll(
          contributed.isEmpty
              ? {for (final name in socket.tags) name: ''}
              : socket.render(contributed),
        );
        importsByFile.putIfAbsent(path, () => []).addAll([
          for (final contribution in contributed)
            ...?contribution.fragment?.imports,
        ]);
      }
    }
    final rendered = await renderBundle(brick.bundle, vars);
    for (final MapEntry(key: path, value: text) in rendered.entries) {
      final imports = ImportRef.merge(
        importsByFile[path] ?? const [],
        appName: testContext.appName,
      );
      files[path] = _withImports(text, imports);
    }
  }
  return RenderedTemplate._(
    files,
    contributions,
    [
      for (final MapEntry(key: socket, value: contributed) in fragments.entries)
        if (!placed.contains(socket)) ...contributed,
    ],
  );
}

/// [text] with the [imports] after its last import directive, or at the top.
String _withImports(String text, List<ImportRef> imports) {
  if (imports.isEmpty) return text;
  final directives = imports
      .map((import) => import.toDirective(testContext.appName))
      .join('\n');
  final last =
      RegExp(r'^import .*;$', multiLine: true).allMatches(text).lastOrNull;
  if (last == null) return '$directives\n\n$text';
  final head = text.substring(0, last.end);
  return '$head\n$directives${text.substring(last.end)}';
}

/// Fails unless [code] parses as Dart without errors.
void expectParses(String code, {String? reason}) {
  final result = parseString(content: code, throwIfDiagnostics: false);
  expect(
    result.errors.map((error) => '${error.message} at ${error.offset}'),
    isEmpty,
    reason: reason ?? code,
  );
}

/// An interactive environment whose user picks the choice at [pick] of every
/// selection.
final class PromptingEnvironment implements SmfEnvironment {
  PromptingEnvironment({this.pick = 0});

  /// The index of the choice the user picks.
  final int pick;

  /// The messages of the selections the user was asked, in order.
  final List<String> asked = [];

  /// The displayed choices of the last selection.
  List<String> shown = const [];

  /// The warnings reported to the user, in order.
  final List<String> warnings = [];

  @override
  bool get interactive => true;

  @override
  bool get skipExternalSetup => false;

  @override
  HostOperatingSystem get operatingSystem => HostOperatingSystem.linux;

  @override
  SmfProcessRunner get processRunner => throw UnimplementedError();

  @override
  SmfPrompter get prompter => _Prompter(this);

  @override
  SmfLogger get logger => _Logger(warnings);

  @override
  Future<String?> findExecutable(String name) async => null;

  @override
  Future<String> writeTempFile(String name, String contents) async =>
      throw UnimplementedError();
}

final class _Logger implements SmfLogger {
  _Logger(this._warnings);

  final List<String> _warnings;

  @override
  void warn(String message) => _warnings.add(message);

  @override
  void detail(String message) {}

  @override
  void error(String message) {}

  @override
  void info(String message) {}

  @override
  SmfProgress progress(String message) => throw UnimplementedError();

  @override
  void success(String message) {}
}

final class _Prompter implements SmfPrompter {
  _Prompter(this._environment);

  final PromptingEnvironment _environment;

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) =>
      throw UnimplementedError();

  @override
  Future<String> input(String message, {String? defaultValue}) =>
      throw UnimplementedError();

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) =>
      throw UnimplementedError();

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) async {
    _environment.asked.add(message);
    _environment.shown = [
      for (final choice in choices) display?.call(choice) ?? '$choice',
    ];
    return choices[_environment.pick];
  }
}
