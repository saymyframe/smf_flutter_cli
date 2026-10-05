import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
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
  RenderedTemplate._(
    this.files,
    this.contributions,
    this.elsewhere,
    this.notes,
  );

  /// The generated files, by path relative to the project root.
  final Map<String, String> files;

  /// What the template's `contribute` hook returned that applies in the
  /// app.
  final List<Contribution> contributions;

  /// Fragments of `render` for sockets whose tags are not in the template,
  /// such as the phases of `bootstrap()`.
  final List<SocketContribution> elsewhere;

  /// The notes of the template for the guide for coding agents, whose tag
  /// the template of the app entry role has.
  final List<SocketContribution> notes;
}

/// Renders the template of [role] as the pipeline will, in an app with
/// [role] and the roles in [present]: its bricks with the presence flags,
/// the variables of its `render` hook, and the sockets of its files filled
/// with the fragments of `render` and with [fromModules], what the modules
/// of the app put into the sockets of the role, whose imports are added to
/// the files that hold the sockets' tags, as are the imports of the
/// fragment variables to the files that read them. A contribution of the
/// template applies only when the roles of its [Contribution.when] are in
/// the app.
Future<RenderedTemplate> renderTemplate<D extends Object>(
  Role<D> role, {
  List<RoleData<Object>> data = const [],
  Set<Role> present = const {},
  Object? choice,
  List<SocketContribution> fromModules = const [],
}) async {
  final template = role.template!;
  final contributions = [
    for (final contribution in template.contribute(testContext))
      if (contribution.when.every({role, ...present}.contains)) contribution,
  ];
  final input = inputOf(role, data: data, present: present, choice: choice);
  final output = template.render(input);

  final fragments = <SocketRef, List<SocketContribution>>{};
  for (final fragment in [
    ...contributions.whereType<SocketContribution>(),
    ...output.fragments,
    ...fromModules,
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
      // A fragment variable renders as its code.
      for (final MapEntry(:key, :value) in output.vars.entries)
        key: value is Fragment ? value.code : value,
    };
    final importsByFile = <String, List<ImportRef>>{};
    for (final MapEntry(key: path, value: text) in templates.entries) {
      for (final MapEntry(:key, :value) in output.vars.entries) {
        if (value is Fragment && text.contains('{{{$key}}}')) {
          importsByFile.putIfAbsent(path, () => []).addAll(value.imports);
        }
      }
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
  final unplaced = [
    for (final MapEntry(key: socket, value: contributed) in fragments.entries)
      if (!placed.contains(socket)) ...contributed,
  ];
  bool isNote(SocketContribution contribution) =>
      contribution.socket == AppEntryRole.agentSections;
  return RenderedTemplate._(
    files,
    contributions,
    [
      for (final contribution in unplaced)
        if (!isNote(contribution)) contribution,
    ],
    [...unplaced.where(isNote)],
  );
}

/// The note of [role] in the guide for coding agents: what its template
/// contributes to the section of the role in every app with the role, or,
/// with [when], in an app with those roles too.
AgentNote agentNoteOf(Role role, {Set<Role> when = const {}}) => role.template!
    .contribute(testContext)
    .whereType<SocketContribution>()
    .singleWhere(
      (contribution) =>
          contribution.socket == AppEntryRole.agentSections &&
          contribution.when.length == when.length &&
          contribution.when.containsAll(when),
    )
    .entryValue! as AgentNote;

/// Fails unless [note] gives each of the [names] inside a span of inline
/// code, and the file that the name is listed under, a Dart file of [files]
/// by its path, declares it: a name as it is at the top level of the file,
/// and `Type.member` as a member of that class, mixin, enum or extension.
///
/// These are the names of the code of an app that a note for coding agents
/// relies on. The note gives a member by its own name, as it is or as a
/// part of the span, such as `push` in `push<T>()`.
void expectNamesOfCode(
  AgentNote note,
  Map<String, List<String>> names, {
  required Map<String, String> files,
}) {
  final spans = codeSpansOf(note.text);
  for (final MapEntry(key: file, value: ofFile) in names.entries) {
    final declared = declarationsOf(files[file]!);
    for (final name in ofFile) {
      expect(declared, contains(name), reason: '$file does not declare $name.');
      final given = name.split('.').last;
      final word = RegExp('(?<![A-Za-z0-9_])${RegExp.escape(given)}'
          '(?![A-Za-z0-9_])');
      expect(
        spans.any(word.hasMatch),
        isTrue,
        reason: 'The note does not give $given in inline code.',
      );
    }
  }
}

/// The spans of inline code of the Markdown [text], outside its fenced code
/// blocks: what stands between two backticks, in the order of the text.
List<String> codeSpansOf(String text) => [
      for (final span in RegExp('`([^`\n]+)`')
          .allMatches(text.replaceAll(RegExp(r'```[\s\S]*?```'), '')))
        span[1]!,
    ];

/// Whether the Dart [code] declares the class [name] as sealed.
bool declaresSealedClass(String code, String name) => parseString(content: code)
    .unit
    .declarations
    .whereType<ClassDeclaration>()
    .any(
      (declaration) =>
          declaration.namePart.typeName.lexeme == name &&
          declaration.sealedKeyword != null,
    );

/// What the Dart [code] declares: the names of its top-level declarations,
/// and the members of its classes, mixins, enums and extensions as
/// `Type.member`.
Set<String> declarationsOf(String code) {
  final declarations = _Declarations();
  parseString(content: code).unit.accept(declarations);
  return declarations.names;
}

final class _Declarations extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  /// The type whose members the visitor is in, if any.
  String? _type;

  void _add(String name) => names.add(_type == null ? name : '$_type.$name');

  void _members(String type, void Function() visit) {
    names.add(type);
    _type = type;
    visit();
    _type = null;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) => _members(
        node.namePart.typeName.lexeme,
        () => super.visitClassDeclaration(node),
      );

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _members(node.name.lexeme, () => super.visitMixinDeclaration(node));

  @override
  void visitEnumDeclaration(EnumDeclaration node) => _members(
        node.namePart.typeName.lexeme,
        () => super.visitEnumDeclaration(node),
      );

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) => _members(
        node.name!.lexeme,
        () => super.visitExtensionDeclaration(node),
      );

  // The bodies of functions and methods declare nothing of the file.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) =>
      _add(node.name.lexeme);

  @override
  void visitMethodDeclaration(MethodDeclaration node) => _add(node.name.lexeme);

  @override
  void visitVariableDeclaration(VariableDeclaration node) =>
      _add(node.name.lexeme);
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
  String? environmentVariable(String name) => null;

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
