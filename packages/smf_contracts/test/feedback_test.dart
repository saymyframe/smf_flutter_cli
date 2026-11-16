@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/bundles/feedback_role_bundle.dart';
import 'package:smf_contracts/bundles/feedback_role_setting_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake provider of feedback in the test app.
const _fakeFile = ImportRef.app('fakes/fake_feedback.dart');

/// The template of the role, as the origin of what it contributes.
const _template = RoleTemplateOrigin(feedbackRole);

/// The implementation of the service of the test app: one created with the
/// app, or one that is created asynchronously, which the role refuses.
RoleImplementation _implementation({bool async = false}) => async
    ? const RoleImplementation.async(
        type: TypeRef('FakeFeedback', import: _fakeFile),
        init: FactoryRef('openFakeFeedback', import: _fakeFile),
      )
    : const RoleImplementation(
        type: TypeRef('FakeFeedback', import: _fakeFile),
        create: FactoryRef('createFakeFeedback', import: _fakeFile),
      );

/// What the template of the role contributes.
List<Contribution> _contributions() =>
    feedbackRole.template.contribute(testContext);

/// The data that the template of the role gives [role], as the pipeline
/// hands it to the hooks of that role: with the template as its origin.
List<RoleData<Object>> _dataFor(Role role) => [
      for (final contribution in _contributions())
        if (contribution case final RoleData<Object> data
            when data.role == role)
          data.withOrigin(_template),
    ];

/// The files of the role in an app with the roles in [present], rendered
/// with the implementation of the test app and with [data] of other roles,
/// and what the template puts into other sockets.
Future<RenderedTemplate> _rendered({
  Set<Role> present = const {},
  List<RoleData<Object>> data = const [],
}) =>
    renderTemplate(
      feedbackRole,
      data: [
        dataOf(feedbackRole, _implementation(), module: 'fake_feedback'),
        ...data,
      ],
      present: present,
    );

/// A stand-in for the part of Flutter's foundation library that the
/// controller of the role uses, with the signatures of Flutter 3.44: the app
/// runs in debug mode, what it prints goes to `debugPrinted`, and what it
/// reports with `FlutterError.reportError` goes to `reported`.
const _foundation = r'''
const bool kDebugMode = true;

/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('$message');

class ErrorDescription {
  ErrorDescription(this.message);

  final String message;
}

class FlutterErrorDetails {
  const FlutterErrorDetails({
    required this.exception,
    this.stack,
    this.library = 'Flutter framework',
    this.context,
  });

  final Object exception;
  final StackTrace? stack;
  final String? library;
  final ErrorDescription? context;
}

/// What the app reported with [FlutterError.reportError], in order.
final List<FlutterErrorDetails> reported = [];

class FlutterError {
  static void reportError(FlutterErrorDetails details) => reported.add(details);
}
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the role use: the context, which tells whether it is still mounted.
const _widgets = '''
abstract class BuildContext {
  bool get mounted;
}
''';

/// A provider of feedback for the test app, which keeps to the contract of
/// `FeedbackService` unless a test says otherwise, and contexts of a test.
///
/// The services note each open with the name of the service and of the
/// context, and a test holds an open until it lets it go, makes it fail or
/// throw at once, or makes `available` throw.
const _fakeFeedback = r'''
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/feedback/feedback_service.dart';

/// The opens that reached a service, in order.
final List<String> calls = [];

/// Returns the opens that reached a service since the last call, and
/// forgets them.
List<String> takeCalls() {
  final taken = [...calls];
  calls.clear();
  return taken;
}

FeedbackService createFakeFeedback() => FakeFeedback('provider');

Future<FeedbackService> openFakeFeedback() async => FakeFeedback('provider');

final class FakeFeedback implements FeedbackService {
  FakeFeedback(this.name);

  final String name;

  /// Whether the service has what it needs.
  bool canWrite = true;

  /// What [available] throws, if anything.
  Object? availableError;

  /// What an open completes with.
  bool answer = true;

  /// What an open fails with, if anything.
  Object? failure;

  /// What an open throws at once, before it returns a future, if anything.
  Object? thrown;

  /// What an open waits for, if anything.
  Completer<bool>? held;

  @override
  bool get available {
    if (availableError case final error?) throw error;
    return canWrite;
  }

  @override
  Future<bool> open(BuildContext context) {
    calls.add('$name: open $context');
    if (thrown case final error?) throw error;
    if (failure case final error?) return Future.error(error);
    if (held case final completer?) return completer.future;
    return Future.value(answer);
  }
}

/// A context of a test, mounted until the test says otherwise.
final class TestContext implements BuildContext {
  TestContext(this.name);

  final String name;

  @override
  bool mounted = true;

  @override
  String toString() => name;
}
''';

/// What the scripts for the test app share.
const _notes = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:my_app/core/feedback/app_feedback.dart';
import 'package:my_app/fakes/fake_feedback.dart';

final result = <String, Object?>{};

/// The service of the provider of the app, which appFeedback uses.
FakeFeedback get provider => createFeedbackService() as FakeFeedback;

/// What the app reported, each as a line.
List<String> reports() => [
      for (final details in reported)
        '${details.library}: ${details.exception} '
            '(${details.context?.message}), with a stack trace: '
            '${details.stack != null}',
    ];
''';

/// What `appFeedback` answers, and when it asks the provider: while the
/// provider has not what it needs, while it has, and with a context that is
/// no longer mounted.
const _answers = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final screen = TestContext('screen');
  provider.canWrite = false;
  result['available while the provider has not what it needs'] =
      appFeedback.available;
  result['open while not available'] = await appFeedback.open(screen);
  result['asked while not available'] = takeCalls();

  provider.canWrite = true;
  result['available'] = appFeedback.available;
  result['open'] = await appFeedback.open(screen);
  provider.answer = false;
  result['open that did not open'] = await appFeedback.open(screen);
  result['asked'] = takeCalls();

  final gone = TestContext('gone')..mounted = false;
  result['open with a context that is gone'] = await appFeedback.open(gone);
  result['asked with a context that is gone'] = takeCalls();
  result['reported'] = reports();
  result['printed'] = debugPrinted;
  port.send(result);
}
''';

/// Two calls at once, and the calls after the first completed.
const _oneAtATime = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final screen = TestContext('screen');
  final held = provider.held = Completer<bool>();
  final first = appFeedback.open(screen);
  var firstDone = false;
  unawaited(first.then((_) => firstDone = true));
  result['the second call while the first is on its way'] =
      await appFeedback.open(TestContext('another screen'));
  result['the first call is done when the second completes'] = firstDone;
  result['asked while the first is on its way'] = takeCalls();
  held.complete(true);
  provider.held = null;
  result['the first call'] = await first;
  result['a call after it'] = await appFeedback.open(screen);
  result['asked after it'] = takeCalls();
  port.send(result);
}
''';

/// Errors of the provider: an open that fails, one that throws before it
/// returns a future, and an `available` that throws.
const _errors = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final uncaught = <String>[];
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      final screen = TestContext('screen');
      provider.failure = StateError('The provider broke.');
      result['an open that fails'] = await appFeedback.open(screen);
      provider
        ..failure = null
        ..thrown = StateError('The provider broke at once.');
      result['an open that throws at once'] = await appFeedback.open(screen);
      provider.thrown = null;
      result['reported'] = reports();
      result['a call after them'] = await appFeedback.open(screen);
      result['asked'] = takeCalls();

      provider.availableError = StateError('The provider cannot tell.');
      result['available that throws'] = appFeedback.available;
      result['open while available throws'] = await appFeedback.open(screen);
      result['asked while available throws'] = takeCalls();
      result['printed'] = debugPrinted;
      result['reported after available threw'] = reported.length;
      done.complete();
    },
    (error, stackTrace) => uncaught.add('$error'),
  );
  await done.future;
  result['uncaught'] = uncaught;
  port.send(result);
}
''';

/// A service of a test that `use()` gives the controller, and the service of
/// the provider again.
const _use = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final screen = TestContext('screen');
  final scripted = FakeFeedback('scripted')
    ..canWrite = false
    ..answer = false;
  appFeedback.use(scripted);
  result['available with the service of the test'] = appFeedback.available;
  scripted.canWrite = true;
  result['open with the service of the test'] = await appFeedback.open(screen);
  appFeedback.use(createFeedbackService());
  result['open with the service of the provider again'] =
      await appFeedback.open(screen);
  result['asked'] = takeCalls();
  port.send(result);
}
''';

/// The files of the test app: the files of the role, as its template
/// generates them in an app without a settings screen, and the fake.
Future<DartFiles> _app() async {
  final feedback = await _rendered();
  return DartFiles.write(
    {
      ...feedback.files,
      'lib/fakes/fake_feedback.dart': _fakeFeedback,
    },
    flutter: const {'foundation.dart': _foundation, 'widgets.dart': _widgets},
  );
}

/// The top-level functions of [unit], by name.
Map<String, FunctionDeclaration> _functionsOf(CompilationUnit unit) => {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// The members of the class [name] of [unit] that are methods or getters,
/// each as its signature.
List<String> _methodsOf(CompilationUnit unit, String name) => [
      for (final member in unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((type) => type.namePart.typeName.lexeme == name)
          .body
          .members)
        if (member is MethodDeclaration)
          [
            '${member.returnType} ',
            if (member.isGetter) 'get ',
            member.name.lexeme,
            '${member.parameters ?? ''}',
          ].join(),
    ];

/// The top-level variables of [unit], each as its declaration.
List<String> _variablesOf(CompilationUnit unit) => [
      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>())
        declaration.toSource(),
    ];

/// The URIs of the imports of [unit], in order.
List<String?> _importsOf(CompilationUnit unit) => [
      for (final directive in unit.directives.whereType<ImportDirective>())
        directive.uri.stringValue,
    ];

/// The named arguments of each creation of a class, by the name of the
/// class.
final class _NamedArgumentsOf extends RecursiveAstVisitor<void> {
  _NamedArgumentsOf(this.className);

  final String className;

  final found = <Map<String, String>>[];

  void _note(String name, ArgumentList arguments) {
    if (name != className) return;
    found.add({
      for (final argument in arguments.arguments.whereType<NamedArgument>())
        argument.name.lexeme: argument.argumentExpression.toSource(),
    });
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _note(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  // Unresolved code has the creation of a class without `new` or `const`
  // as the call of a method.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) _note(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }
}

/// What the app reports of an [error] of the provider, as the scripts note
/// it.
String _reportOf(String error) =>
    'feedback: Bad state: $error (while opening the way to write to the '
    'developer of the app), with a stack trace: true';

/// The provider of the role and a feature that uses the role.
const _provider = ModuleDescriptor(
  id: ModuleId('fake_feedback'),
  description: 'Feedback',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(feedbackRole)],
);
const _feature = ModuleDescriptor(
  id: ModuleId('help'),
  description: 'Help',
  kind: ModuleKinds.feature,
  uses: {feedbackRole},
);

/// The template of another role whose code could reach the service.
final _otherRole = TestRole<NoDsl>('help_center', requires: {feedbackRole});

/// The implementation of the provider of the apps of the rules: its class
/// in one file and its function in another.
const _providerImplementation = RoleImplementation(
  type: TypeRef(
    'MailFeedbackService',
    import: ImportRef.app('core/feedback/mail_feedback_service.dart'),
  ),
  create: FactoryRef(
    'createMailFeedbackService',
    import: ImportRef.app('core/feedback/mail_feedback.dart'),
  ),
);

/// The file of the function of [_providerImplementation], which imports the
/// file of `FeedbackService`, as the file of an implementation may.
const _factoryFile = DartFileIndex(
  path: 'lib/core/feedback/mail_feedback.dart',
  imports: [IndexedImport('feedback_service.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createMailFeedbackService',
      kind: DeclarationKind.function,
    ),
  ],
);

/// The issues of the structural rules of the role in an app of the provider
/// with [_providerImplementation] and with [files], each with its owner; a
/// file without an owner has `null`.
List<SmfIssue> _structureIssues(
  Map<DartFileIndex, ContributionOrigin?> files,
) =>
    feedbackRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: [
            dataOf(
              feedbackRole,
              _providerImplementation,
              module: 'fake_feedback',
            ),
          ],
          presentRoles: {feedbackRole},
          context: testContext,
        ),
        files: {
          _factoryFile.path: _factoryFile,
          for (final file in files.keys) file.path: file,
        },
        owners: {
          _factoryFile.path: ModuleOrigin(_provider.id),
          for (final MapEntry(key: file, value: owner) in files.entries)
            if (owner != null) file.path: owner,
        },
        modules: const [_provider, _feature],
      ),
    );

/// The index of the file at [path] that imports the file of `appFeedback`
/// and calls [function] of it, or the method [function] of [target].
DartFileIndex _calling(String path, String function, {String? target}) =>
    DartFileIndex(
      path: path,
      imports: const [
        IndexedImport('package:my_app/core/feedback/app_feedback.dart'),
      ],
      invocations: [IndexedInvocation(function, target: target)],
    );

void main() {
  group('the feedback role', () {
    test(
        'takes one provider, and works with a settings screen and the '
        'languages of the app, and with no router', () {
      expect(feedbackRole.id, 'feedback');
      expect(feedbackRole.description, 'Feedback');
      expect(feedbackRole.presenceFlag, 'has_feedback');
      expect('$feedbackRole', 'feedback role');
      expect(feedbackRole.cardinality, RoleCardinality.atMostOne);
      expect(feedbackRole.requires, isEmpty);
      expect(feedbackRole.uses, {settingsScreenRole, localizationRole});
      // Its provider uses what the role uses, so the contract harness
      // builds the apps of a provider with each of those roles and without.
      expect(_provider.effectiveUses, {settingsScreenRole, localizationRole});
      expect(_provider.effectiveRequires, isEmpty);
      expect(feedbackRole.sockets, const [FeedbackRole.implementations]);
      expect(
        FeedbackRole.implementations.tag,
        'smf_feedback__implementations',
      );
      expect(feedbackRole.options, isEmpty);
      expect(
        [for (final rule in feedbackRole.moduleRules) rule.id],
        ['services.implementations'],
      );
      expect(
        [for (final rule in feedbackRole.structuralRules) rule.id],
        [
          'feedback.factory_calls',
          'feedback.use_calls',
          'feedback.implementation_factories',
        ],
      );
    });

    test(
        'guarantees the files of the service and of the controller, but not '
        'the file of the entry of the settings screen', () {
      expect(feedbackRole.interface.files, [
        'lib/core/feedback/feedback_service.dart',
        'lib/core/feedback/app_feedback.dart',
      ]);
      expect(feedbackRole.interface.files, [
        FeedbackRole.serviceFile,
        FeedbackRole.controllerFile,
      ]);
      expect(feedbackRole.interface.symbols, isEmpty);
      expect(
        FeedbackRole.settingFile,
        'lib/core/feedback/feedback_setting.dart',
      );
      expect(FeedbackRole.readmeHeading, 'Feedback');
    });

    test(
        'has the title of the entry of the settings screen in English and in '
        'Ukrainian, with no problems', () {
      const title = FeedbackRole.settingTitle;
      expect(title.problems(), isEmpty);
      expect(title.languages, ['en', 'uk']);
      expect(title.en, 'Write to us');
      expect(title.textIn('uk'), 'Написати нам');
    });
  });

  group('the feedback template', () {
    test(
        'generates the files of the role in every app, and the entry only in '
        'an app with a settings screen', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [feedbackRoleBundle.name, feedbackRoleSettingBundle.name],
      );
      expect(
        [for (final brick in bricks) brick.when],
        [
          isEmpty,
          {settingsScreenRole},
        ],
      );
      expect(
        templatesOf(feedbackRoleSettingBundle).keys,
        [FeedbackRole.settingFile],
      );

      for (final settings in [false, true]) {
        final rendered = await _rendered(
          present: {if (settings) settingsScreenRole},
        );
        expect(
          rendered.files.keys.toSet(),
          {
            ...feedbackRole.interface.files,
            if (settings) FeedbackRole.settingFile,
          },
          reason: 'settings: $settings',
        );
        for (final MapEntry(key: path, value: text) in rendered.files.entries) {
          expectParses(text, reason: path);
        }
      }
    });

    test(
        'registers nothing in a DI container, adds nothing to bootstrap(), '
        'and gives the settings screen its entry, with the function that '
        'says whether the screen shows it', () async {
      expect(_dataFor(diRole), isEmpty);
      final entry = _dataFor(settingsScreenRole).single;
      // The data needs no condition: it applies only with the role.
      expect(entry.when, isEmpty);
      final value = entry.value as SettingsEntry;
      expect(value.widget.name, 'FeedbackSetting');
      expect(value.file, FeedbackRole.settingFile);
      expect(value.showIf!.name, 'feedbackSettingShows');
      expect(
        'lib/${value.showIf!.import.uri}',
        FeedbackRole.settingFile,
      );
      expect(value.problems(), isEmpty);
      final input = inputOf(
        settingsScreenRole,
        data: _dataFor(settingsScreenRole),
        present: {routerRole},
      );
      expect(settingsScreenRole.template.validate(input), isEmpty);
      expect(settingsScreenRole.entriesIn(input).single, same(value));

      // In an app with a settings screen too, nothing goes into a socket of
      // the start-up of the app.
      final rendered = await _rendered(present: {settingsScreenRole});
      expect(
        [
          for (final fragment in rendered.elsewhere)
            if (fragment.socket != AppEntryRole.readmeSections) fragment.socket,
        ],
        isEmpty,
      );
      expect(
        _contributions().whereType<SocketContribution>().where(
              (contribution) =>
                  contribution.socket != AppEntryRole.agentSections,
            ),
        isEmpty,
      );
    });

    test(
        'generates the interface that a provider implements, which says what '
        'a provider keeps to, with the import of the context alone', () async {
      final rendered = await _rendered();
      final code = rendered.files[FeedbackRole.serviceFile]!;
      final unit = parseString(content: code).unit;

      expect(_methodsOf(unit, 'FeedbackService'), [
        'bool get available',
        'Future<bool> open(BuildContext context)',
      ]);
      expect(_importsOf(unit), ['package:flutter/widgets.dart']);
      final words = code.replaceAll(RegExp(r'\s*\n\s*(///)?\s*'), ' ');
      expect(
        words,
        allOf(
          contains('Reads at once, never throws, and does not change while '
              'the app runs.'),
          contains('Completes with true once that way opened, without '
              'waiting for the user to send anything.'),
          contains('after the provider showed a way of its own to reach the '
              'developer when it has one'),
          contains('It asks the platform nothing before it opens'),
          contains('What reaches the developer has the name, the version, the '
              'build number and the flavor of the app, and its platform: '
              'that is the duty of each provider, which the test of its '
              'module checks.'),
          contains('Never throws.'),
        ),
      );
    });

    test(
        'creates the implementation with the app in the file of the '
        'controller, which has appFeedback and createFeedbackService()',
        () async {
      final rendered = await _rendered();
      final code = rendered.files[FeedbackRole.controllerFile]!;
      final unit = parseString(content: code).unit;

      const controller = 'final AppFeedbackController appFeedback = '
          'AppFeedbackController._(createFeedbackService());';
      const service = 'final FeedbackService _feedbackService = '
          'impl0.createFakeFeedback();';
      expect(_variablesOf(unit), [controller, service]);
      expect(
        '${_functionsOf(unit)['createFeedbackService']!.returnType}',
        'FeedbackService',
      );
      expect(_methodsOf(unit, 'AppFeedbackController'), [
        'bool get available',
        'Future<bool> open(BuildContext context)',
        'void use(FeedbackService service)',
      ]);
      // The controller imports no file of another role.
      expect(_importsOf(unit), [
        'package:flutter/foundation.dart',
        'package:flutter/widgets.dart',
        'feedback_service.dart',
        'package:my_app/fakes/fake_feedback.dart',
      ]);
      expect(
        code,
        contains("import 'package:my_app/fakes/fake_feedback.dart' as impl0;"),
      );
    });

    test(
        'refuses an implementation that is created asynchronously, since the '
        'role has no start-up phase', () {
      final issues = feedbackRole.template.validate(
        inputOf(
          feedbackRole,
          data: [
            dataOf(
              feedbackRole,
              _implementation(async: true),
              module: 'fake_feedback',
            ),
          ],
        ),
      );

      expect(
        [for (final issue in issues) (issue.message, issue.hint, issue.origin)],
        [
          (
            'The openFakeFeedback of the feedback role starts '
                'asynchronously, but the role has no start-up phase.',
            'Create the service with the app, and let it open what it needs '
                'at its first open.',
            const ModuleOrigin(ModuleId('fake_feedback')),
          ),
        ],
      );
      expect(
        feedbackRole.template.validate(
          inputOf(
            feedbackRole,
            data: [
              dataOf(feedbackRole, _implementation(), module: 'fake_feedback'),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('reports the problems of the implementation', () {
      final issues = feedbackRole.template.validate(
        inputOf(
          feedbackRole,
          data: [
            dataOf(
              feedbackRole,
              const RoleImplementation(
                type: TypeRef('_Private'),
                create: FactoryRef('create', import: _fakeFile),
              ),
              module: 'fake_feedback',
            ),
          ],
        ),
      );
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('fake_feedback')),
      );
    });
  });

  group('the generated controller', () {
    const printedOnce = 'The provider of feedback failed to tell whether a '
        'user can write, so the app takes it as no: Bad state: The provider '
        'cannot tell.';
    late DartFiles app;

    setUpAll(() async => app = await _app());

    tearDownAll(() => app.delete());

    test('is code that type-checks', () async {
      expect(await app.analysisProblems(), isEmpty);
    });

    test(
        'asks the provider only while it has what it needs and the context is '
        'mounted, gives it the context, and completes with its answer',
        () async {
      expect(await app.run('$_notes$_answers'), {
        'available while the provider has not what it needs': false,
        'open while not available': false,
        'asked while not available': <Object?>[],
        'available': true,
        'open': true,
        'open that did not open': false,
        'asked': ['provider: open screen', 'provider: open screen'],
        'open with a context that is gone': false,
        'asked with a context that is gone': <Object?>[],
        'reported': <Object?>[],
        'printed': <Object?>[],
      });
    });

    test(
        'runs one call at a time: a call while another is on its way '
        'completes with false at once, without asking the provider', () async {
      expect(await app.run('$_notes$_oneAtATime'), {
        'the second call while the first is on its way': false,
        'the first call is done when the second completes': false,
        'asked while the first is on its way': ['provider: open screen'],
        'the first call': true,
        'a call after it': true,
        'asked after it': ['provider: open screen'],
      });
    });

    test(
        'never throws: an error of the provider is reported once and counts '
        'as false, and an available that throws counts as false and prints '
        'once', () async {
      expect(await app.run('$_notes$_errors'), {
        'an open that fails': false,
        'an open that throws at once': false,
        'reported': [
          for (final error in const [
            'The provider broke.',
            'The provider broke at once.',
          ])
            _reportOf(error),
        ],
        // The calls that failed are over, so the next one asks again.
        'a call after them': true,
        'asked': [
          'provider: open screen',
          'provider: open screen',
          'provider: open screen',
        ],
        'available that throws': false,
        'open while available throws': false,
        'asked while available throws': <Object?>[],
        'printed': [printedOnce],
        'reported after available threw': 2,
        'uncaught': <Object?>[],
      });
    });

    test(
        'takes the service of a test from use(), and the service of the '
        'provider again', () async {
      expect(await app.run('$_notes$_use'), {
        'available with the service of the test': false,
        'open with the service of the test': false,
        'open with the service of the provider again': true,
        'asked': ['scripted: open screen', 'provider: open screen'],
      });
    });
  });

  group('the entry of the settings screen', () {
    late String code;
    late CompilationUnit unit;

    setUpAll(() async {
      final rendered = await _rendered(
        present: {settingsScreenRole, localizationRole},
        data: _dataFor(localizationRole),
      );
      code = rendered.files[FeedbackRole.settingFile]!;
      unit = parseString(content: code).unit;
    });

    /// The named arguments of each creation of [className] in the file.
    List<Map<String, String>> created(String className) {
      final found = _NamedArgumentsOf(className);
      unit.accept(found);
      return found.found;
    }

    test(
        'has a constant constructor that requires no arguments, and a '
        'function that says whether the screen shows it, which reads only '
        'whether the provider has what it needs', () {
      final constructor = unit.declarations
          .whereType<ClassDeclaration>()
          .firstWhere(
            (type) => type.namePart.typeName.lexeme == 'FeedbackSetting',
          )
          .body
          .members
          .whereType<ConstructorDeclaration>()
          .single;
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.name, isNull);
      expect('${constructor.parameters}', '({super.key})');

      final shows = _functionsOf(unit)['feedbackSettingShows']!;
      expect('${shows.returnType}', 'bool');
      expect(shows.functionExpression.parameters!.parameters, isEmpty);
      expect(
        '${shows.functionExpression.body}',
        '=> appFeedback.available;',
      );
    });

    test(
        'gives the localization role its title only in an app with a '
        'settings screen, and reads it from the texts of the app', () {
      final texts = _dataFor(localizationRole);
      expect(texts.single.when, {settingsScreenRole});
      final input = inputOf(
        localizationRole,
        data: texts,
        present: {settingsScreenRole},
      );
      expect(localizationRole.template.validate(input), isEmpty);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        ['feedbackSettingTitle'],
      );
      expect(localizationRole.textsIn(input).single.owner, _template);

      expect(
        created('ListTile').single['title'],
        '_WholeWords(context.l10n.feedbackSettingTitle)',
      );
    });

    test('writes its title in English in an app without the localization role',
        () async {
      final rendered = await _rendered(present: {settingsScreenRole});
      final english = rendered.files[FeedbackRole.settingFile]!;

      expect(english, contains("title: _WholeWords('Write to us'),"));
      expectParses(english);
    });

    test(
        'is a row with an icon of a message and nothing at its end, whose tap '
        'opens the way of the provider without waiting for it, and which '
        'reads nothing of another role', () {
      final row = created('ListTile').single;
      expect(row.keys.toSet(), {'leading', 'title', 'onTap'});
      expect(row['leading'], 'const Icon(Icons.chat_bubble_outline_rounded)');
      expect(row['onTap'], '() => unawaited(appFeedback.open(context))');
      expect(
        _importsOf(unit),
        unorderedEquals([
          'dart:async',
          'package:flutter/material.dart',
          'app_feedback.dart',
          'package:my_app/core/l10n/l10n.dart',
        ]),
      );
    });

    test(
        'keeps the words of its title whole, with a copy of its own that '
        'breaks a line only at white space but a no-break space', () {
      final wholeWords =
          unit.declarations.whereType<ClassDeclaration>().singleWhere(
                (type) => type.namePart.typeName.lexeme == '_WholeWords',
              );
      expect(
        wholeWords.extendsClause!.superclass.name.lexeme,
        'StatelessWidget',
      );
      expect(
        code,
        contains(r"text.split(RegExp(r'[^\S\u00A0\u2007\u202F]+'))"),
      );
      // Where the longest word does not fit, the text is as large as it
      // allows.
      expect(code, contains('size *= room / widest * 0.98;'));
      expect(code, contains('MediaQuery.boldTextOf(context)'));
    });
  });

  group('the notes of the feedback role for coding agents', () {
    late Map<String, String> files;

    setUpAll(() async {
      files = (await _rendered(present: {settingsScreenRole})).files;
    });

    test(
        'name what the files of the role declare, in every app and in the '
        'apps with a settings screen', () {
      expectNamesOfCode(
        agentNoteOf(feedbackRole),
        {
          FeedbackRole.controllerFile: [
            'appFeedback',
            'AppFeedbackController.open',
            'AppFeedbackController.available',
            'AppFeedbackController.use',
            'createFeedbackService',
          ],
          FeedbackRole.serviceFile: ['FeedbackService'],
        },
        files: files,
      );
      expect(
        agentNoteOf(feedbackRole).text,
        allOf(
          contains('`${FeedbackRole.controllerFile}`'),
          contains('`${FeedbackRole.serviceFile}`'),
          contains('Never ask anything before or around the review dialog of '
              'a store'),
        ),
      );
      final setting = agentNoteOf(feedbackRole, when: {settingsScreenRole});
      expectNamesOfCode(
        setting,
        {
          FeedbackRole.settingFile: [
            'FeedbackSetting',
            'feedbackSettingShows',
          ],
          FeedbackRole.controllerFile: ['AppFeedbackController.available'],
        },
        files: files,
      );
      expect(setting.text, contains('`${FeedbackRole.settingFile}`'));
    });

    test('name no provider, and no tool of one', () {
      for (final when in <Set<Role>>[
        const {},
        {settingsScreenRole},
      ]) {
        final text = agentNoteOf(feedbackRole, when: when).text.toLowerCase();
        for (final word in [
          'url_launcher',
          'mailto',
          'email_feedback',
          'sentry',
          '.env',
        ]) {
          expect(text, isNot(contains(word)), reason: '$when: $word');
        }
      }
    });
  });

  group('the section of the feedback role in the README of the app', () {
    /// The section in an app with the roles in [present], and the files of
    /// the role there.
    Future<(String, Map<String, String>)> sectionWith(
      Set<Role> present,
    ) async {
      final rendered = await _rendered(present: present);
      final section = rendered.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.readmeSections,
      );
      expect(section.entryKey, FeedbackRole.readmeHeading);
      expect(section.when, isEmpty);
      return (section.entryValue! as String, rendered.files);
    }

    test(
        'tells how the app lets a user write and what the answers mean, what '
        'each provider adds, and names no provider', () async {
      final (section, files) = await sectionWith({settingsScreenRole});

      expectNamesOfCodeIn(
        section,
        {
          FeedbackRole.controllerFile: [
            'appFeedback',
            'AppFeedbackController.open',
            'AppFeedbackController.available',
          ],
          FeedbackRole.settingFile: ['FeedbackSetting'],
        },
        files: files,
      );
      expect(
        section,
        allOf(
          contains('`${FeedbackRole.controllerFile}`'),
          contains('onPressed: () => appFeedback.open(context),'),
          contains('completes with `true` once that way opened, without '
              'waiting for the user to send anything'),
          contains('It completes with `false` when the way could not open'),
          contains('It never throws'),
        ),
      );
      expect(
        section,
        allOf(
          contains('A call while another is on its way does nothing and '
              'completes with `false`.'),
          contains('does not change while the app runs'),
          contains('Each provider adds to what reaches you the name, the '
              'version, the build number and the flavor of the app and its '
              'platform'),
        ),
      );
      for (final word in ['url_launcher', 'mailto', 'EMAIL_FEEDBACK']) {
        expect(section, isNot(contains(word)));
      }
    });

    test(
        'tells that the way to write does not depend on a review, that the '
        'Support URL of App Store Connect is still needed, and what to '
        'declare of privacy', () async {
      final (section, _) = await sectionWith(const {});

      expect(
        section,
        allOf(
          contains('The way to write is there whatever the user did with the '
              'review dialog of a store. Google Play forbids any question '
              'before or around that dialog'),
          contains('does not replace the Support URL that App Store Connect '
              'asks of every app'),
          contains('(App Store Review Guideline 1.5)'),
          // Only a provider that sends through a service of its own collects
          // data; the section of the provider says what it sends.
          contains('A provider that sends it through a service of its own, '
              'such as a form, collects data: declare it in App Privacy and '
              'in Data safety, as the section of the provider says what it '
              'sends.'),
          contains('Both stores also require a link to a privacy policy in '
              'the listing of the app and inside the app.'),
        ),
      );
    });

    test(
        'tells where the app lets the user write, with a settings screen or '
        'without it', () async {
      const row = 'The row "Write to us" of the settings screen, '
          '`FeedbackSetting` in `${FeedbackRole.settingFile}`, calls it, and '
          'the screen shows the row only while `appFeedback.available` holds.';
      const noSettings = 'This app has no settings screen, so call it from a '
          'button of your own';

      final (settings, _) = await sectionWith({settingsScreenRole});
      expect(settings, contains(row));
      expect(settings, isNot(contains(noSettings)));
      final (without, _) = await sectionWith(const {});
      expect(without, contains(noSettings));
      expect(without, isNot(contains(FeedbackRole.settingFile)));
    });
  });

  group('the rules of the feedback role', () {
    const providerFile = 'lib/core/feedback/mail_feedback_service.dart';
    const screen = 'lib/features/help/help_screen.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_feedback'));
    const ofFeature = ModuleOrigin(ModuleId('help'));
    const hint = 'Let the user write through appFeedback of '
        'lib/core/feedback/app_feedback.dart.';

    test(
        'let each provider contribute one implementation, and no module put '
        'code into the socket of the implementation', () {
      List<SmfIssue> issuesOf(
        ModuleDescriptor module, {
        List<RoleImplementation> implementations = const [],
        List<Contribution> contributions = const [],
      }) =>
          feedbackRole.checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  for (final implementation in implementations)
                    feedbackRole
                        .data(implementation)
                        .withOrigin(ModuleOrigin(module.id)),
                ],
                presentRoles: {feedbackRole},
                context: testContext,
              ),
              module: module,
              contributions: contributions,
            ),
          );
      final implementation = _implementation();

      expect(issuesOf(_provider, implementations: [implementation]), isEmpty);
      expect(issuesOf(_feature), isEmpty);
      expect(
        issuesOf(_provider).single.message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        issuesOf(_feature, implementations: [implementation]).single.message,
        contains('which only its providers do'),
      );
      final issue = issuesOf(
        _provider,
        implementations: [implementation],
        contributions: const [
          SocketContribution.code(
            FeedbackRole.implementations,
            Fragment('final FeedbackService _feedbackService = create();'),
          ),
        ],
      ).single;
      expect(issue.message, contains('socket feedback.implementations'));
    });

    test(
        'feedback.factory_calls: a file of a module, or of the template of '
        'another role, that calls createFeedbackService() is reported, with '
        'appFeedback as what to use', () {
      final issues = _structureIssues({
        _calling(providerFile, 'createFeedbackService'): ofProvider,
        _calling(screen, 'createFeedbackService'): ofFeature,
        _calling('lib/core/help/help.dart', 'createFeedbackService'):
            RoleTemplateOrigin(_otherRole),
        // Another file of the template of the role itself, and files that
        // neither a module nor the template of a role owns.
        _calling('lib/core/feedback/more.dart', 'createFeedbackService'):
            _template,
        _calling('lib/generated.dart', 'createFeedbackService'):
            const PipelineOrigin(),
        _calling('lib/mine.dart', 'createFeedbackService'): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          ('lib/core/help/help.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls createFeedbackService(), which no module may '
          'call.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'feedback.factory_calls: only the files of the implementation of the '
        'provider import the file of FeedbackService; any other file of a '
        'module, a widget of the provider too, is reported', () {
      const widget = DartFileIndex(
        path: 'lib/core/feedback/mail_sheet.dart',
        imports: [IndexedImport('feedback_service.dart')],
      );
      const prefixed = DartFileIndex(
        path: screen,
        imports: [
          IndexedImport(
            'package:my_app/core/feedback/feedback_service.dart',
            prefix: 'feedback',
          ),
        ],
      );
      const exporting = DartFileIndex(
        path: 'lib/core/help/help.dart',
        exports: [IndexedImport('../feedback/feedback_service.dart')],
      );
      const ofClass = DartFileIndex(
        path: providerFile,
        imports: [IndexedImport('feedback_service.dart')],
      );

      final issues = _structureIssues({
        widget: ofProvider,
        prefixed: ofFeature,
        exporting: RoleTemplateOrigin(_otherRole),
        // The file of the class of the implementation, and that of its
        // function, which the helper adds, may.
        ofClass: ofProvider,
      });

      expect(
        [for (final issue in issues) issue.path],
        [widget.path, screen, 'lib/core/help/help.dart'],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} imports ${FeedbackRole.serviceFile}, the file of '
          'FeedbackService, which only the files of the implementation of the '
          'provider of the feedback role import.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'feedback.use_calls: a file of a module, or of the template of '
        'another role, that calls appFeedback.use() is reported', () {
      final issues = _structureIssues({
        _calling(screen, 'use', target: 'appFeedback'): ofFeature,
        _calling('lib/core/help/help.dart', 'use', target: 'appFeedback'):
            RoleTemplateOrigin(_otherRole),
        // The template of the role itself, and code of the developer.
        _calling('lib/core/feedback/more.dart', 'use', target: 'appFeedback'):
            _template,
        _calling('lib/mine.dart', 'use', target: 'appFeedback'): null,
        // Another object, and another method.
        _calling('lib/features/help/a.dart', 'use', target: 'other'): ofFeature,
        _calling('lib/features/help/b.dart', 'open', target: 'appFeedback'):
            ofFeature,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (screen, ofFeature),
          ('lib/core/help/help.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls appFeedback.use(), which only a test calls.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'feedback.implementation_factories: the function of the '
        'implementation is in its file and takes no arguments', () {
      final missing = feedbackRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [
              dataOf(feedbackRole, _implementation(), module: 'fake_feedback'),
            ],
            presentRoles: {feedbackRole},
            context: testContext,
          ),
          files: const {
            'lib/fakes/fake_feedback.dart':
                DartFileIndex(path: 'lib/fakes/fake_feedback.dart'),
          },
        ),
      );
      expect(
        missing.single.message,
        contains('does not declare function createFakeFeedback()'),
      );
    });
  });
}
