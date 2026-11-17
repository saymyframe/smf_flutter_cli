import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

RoleImplementation _implementation(String name, {bool async = false}) {
  final import = ImportRef.app('fakes/${SmfNames.snakeCaseOf(name)}.dart');
  final type = TypeRef(name, import: import);
  return async
      ? RoleImplementation.async(
          type: type,
          init: FactoryRef('init$name', import: import),
        )
      : RoleImplementation(
          type: type,
          create: FactoryRef('create$name', import: import),
        );
}

RoleData<Object> _data(
  Role<RoleImplementation> role,
  String name, {
  bool async = false,
}) =>
    dataOf(
      role,
      _implementation(name, async: async),
      module: SmfNames.snakeCaseOf(name),
    );

/// The choice of [role] in an app generated without its options: whether the
/// app collects from its first start, for the [analyticsRole], whose mode
/// option has `on` as its first value, and none for the other service roles,
/// which choose nothing.
Object? _choiceOf(Role role) =>
    identical(role, analyticsRole) ? AnalyticsCollection.on : null;

/// The issues of the module rule of [role] for a module that [provides] the
/// role or only uses it, and contributes [implementations], the data of the
/// role.
List<SmfIssue> _moduleIssues<D extends Object>(
  Role<D> role, {
  required bool provides,
  required List<D> implementations,
}) =>
    role.checkModule(
      ModuleRuleRequest(
        hook: RoleHookRequest(
          data: [
            for (final implementation in implementations)
              role
                  .data(implementation)
                  .withOrigin(const ModuleOrigin(ModuleId('vendor'))),
          ],
          presentRoles: {role},
          context: testContext,
        ),
        module: ModuleDescriptor(
          id: const ModuleId('vendor'),
          description: 'Vendor',
          kind: ModuleKinds.infrastructure,
          providers: [if (provides) RoleProvider.plain(role)],
          uses: {if (!provides) role},
        ),
        contributions: const [],
      ),
    );

/// The top-level functions of the Dart [code], by name.
Map<String, FunctionDeclaration> _functionsOf(String code) => {
      for (final function in parseString(content: code)
          .unit
          .declarations
          .whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// Renders the template of the analytics role in an app with the
/// implementations of [data], where the roles in [present] are present too,
/// and that collects from its first start as [collection] says.
Future<RenderedTemplate> _renderAnalytics(
  List<RoleData<Object>> data, {
  Set<Role> present = const {},
  AnalyticsCollection collection = AnalyticsCollection.on,
}) =>
    renderTemplate(
      analyticsRole,
      data: data,
      present: present,
      choice: collection,
    );

/// The fragments that [rendered], the template of the analytics role, gives
/// the phases of `bootstrap()`, in the order of the hook.
List<SocketContribution> _startUpOf(RenderedTemplate rendered) => [
      for (final fragment in rendered.elsewhere)
        if (const [
          AppEntryRole.bootstrapEarly,
          AppEntryRole.bootstrapPlatform,
          AppEntryRole.bootstrapDi,
          AppEntryRole.bootstrapLate,
        ].contains(fragment.socket))
          fragment,
    ];

/// The section of the analytics role in the README of the app that
/// [rendered], the template of the role, writes.
String _analyticsSectionOf(RenderedTemplate rendered) => rendered.elsewhere
    .singleWhere(
      (fragment) =>
          fragment.socket == AppEntryRole.readmeSections &&
          fragment.entryKey == AnalyticsRole.readmeHeading,
    )
    .entryValue! as String;

/// The declaration of `analyticsCollectedFromFirstStart` in [code], the file
/// of the analytics role, as the analyzer parses it.
TopLevelVariableDeclaration _collectedFromFirstStartIn(String code) =>
    parseString(content: code)
        .unit
        .declarations
        .whereType<TopLevelVariableDeclaration>()
        .singleWhere(
          (declaration) => declaration.variables.variables.any(
            (variable) =>
                variable.name.lexeme == 'analyticsCollectedFromFirstStart',
          ),
        );

final class _Container extends DiProvider {
  const _Container();

  @override
  Set<DiCapability> get capabilities => const {};
}

void main() {
  group('RoleImplementation', () {
    test('is created by a factory or asynchronously by an init function', () {
      final sync = _implementation('ConsoleAnalytics');
      final async = _implementation('DelayedAnalytics', async: true);

      expect(sync.isAsync, isFalse);
      expect(sync.factory.name, 'createConsoleAnalytics');
      expect(sync.init, isNull);
      expect(async.isAsync, isTrue);
      expect(async.factory.name, 'initDelayedAnalytics');
      expect(async.create, isNull);
      expect('$sync', 'implementation ConsoleAnalytics');
      expect(sync.problems(), isEmpty);
    });

    test('takes no services, because it works without a container', () {
      const implementation = RoleImplementation(
        type: TypeRef('A'),
        create: FactoryRef(
          'createA',
          import: ImportRef.app('a.dart'),
          deps: [ServiceRef(TypeRef('B'))],
        ),
      );

      expect(
        implementation.problems().single,
        contains('must take no services'),
      );
    });
  });

  group('the module rule of the service roles', () {
    /// Checks that the module rule of [role] lets each provider contribute
    /// one implementation, [one] or [other], and no other module: no
    /// implementation, or two, is an issue.
    void expectOneImplementation<D extends Object>(
      Role<D> role,
      D one,
      D other,
    ) {
      expect(
        _moduleIssues(role, provides: true, implementations: [one]),
        isEmpty,
      );
      expect(
        _moduleIssues(role, provides: false, implementations: <D>[]),
        isEmpty,
      );
      expect(
        _moduleIssues(role, provides: true, implementations: <D>[])
            .single
            .message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        _moduleIssues(role, provides: true, implementations: [one, other])
            .single
            .message,
        contains('exactly one implementation, but the module contributes 2'),
      );
      final issue = _moduleIssues(
        role,
        provides: false,
        implementations: [one],
      ).single;
      expect(issue.message, contains('which only its providers do'));
      expect(issue.origin, const ModuleOrigin(ModuleId('vendor')));
    }

    for (final role in [
      eventsRole,
      preferencesRole,
      analyticsRole,
      crashReportingRole,
      notificationsRole,
      pushRole,
      purchasesRole,
      restRole,
      reviewRole,
    ]) {
      test('lets each provider of the ${role.id} contribute one implementation',
          () {
        expectOneImplementation(
          role,
          _implementation('A'),
          _implementation('B'),
        );
      });
    }

    test(
        'lets each provider of the auth role contribute one implementation, '
        'whatever ways to sign in it gives the role too', () {
      AuthImplementation implementation(String name) => AuthImplementation(
            type: TypeRef(name, import: const ImportRef.app('fakes/a.dart')),
            create: FactoryRef(
              'create$name',
              import: const ImportRef.app('fakes/a.dart'),
            ),
          );
      const method = SignInMethod(
        label: LocalizedText('label', en: 'Continue with Example'),
        icon: TypeRef(
          'ExampleIcon',
          import: ImportRef.app('core/example/example.dart'),
        ),
        platforms: {AppPlatform.android},
        credential: FunctionRef(
          'exampleCredential',
          import: ImportRef.app('core/example/example.dart'),
        ),
        issuer: 'https://id.example.com',
        appStore: AppStoreLogin.thirdParty,
      );

      expectOneImplementation<AuthData>(
        authRole,
        implementation('A'),
        implementation('B'),
      );
      // A way to sign in is no implementation.
      expect(
        _moduleIssues<AuthData>(
          authRole,
          provides: true,
          implementations: [implementation('A'), method],
        ).map((issue) => issue.message),
        isNot(contains(contains('implementation'))),
      );
      expect(
        _moduleIssues<AuthData>(
          authRole,
          provides: false,
          implementations: [method],
        ).map((issue) => issue.message),
        isNot(contains(contains('implementation'))),
      );
    });

    test(
        'lets each provider of the remote config role contribute one '
        'implementation, whatever parameters it gives the role too', () {
      RemoteConfigImplementation implementation(String name) =>
          RemoteConfigImplementation(
            type: TypeRef(name, import: const ImportRef.app('fakes/a.dart')),
            create: FactoryRef(
              'create$name',
              import: const ImportRef.app('fakes/a.dart'),
            ),
          );
      const parameter = RemoteConfigKey.boolean(
        'vendor_verbose',
        defaultValue: false,
        description: 'Whether the vendor prints more',
      );

      expectOneImplementation<RemoteConfigData>(
        remoteConfigRole,
        implementation('A'),
        implementation('B'),
      );
      // A parameter is no implementation.
      for (final provides in [true, false]) {
        expect(
          _moduleIssues<RemoteConfigData>(
            remoteConfigRole,
            provides: provides,
            implementations: [if (provides) implementation('A'), parameter],
          ).map((issue) => issue.message),
          isNot(contains(contains('implementation'))),
        );
      }
    });
  });

  group('the templates of the service roles', () {
    test(
        'register the service in the DI container, but for the auth role, '
        'the notifications role, the push role, the purchases role, the REST '
        'role, the remote config role and the review role, whose services are '
        'not for the code of the app', () {
      expect(
        authRole.template
            .contribute(testContext)
            .whereType<RoleData<DiRegistration>>(),
        isEmpty,
      );
      for (final role in <Role>[
        notificationsRole,
        pushRole,
        purchasesRole,
        restRole,
        remoteConfigRole,
        reviewRole,
      ]) {
        expect(
          role.template!
              .contribute(testContext)
              .whereType<RoleData<DiRegistration>>(),
          isEmpty,
          reason: role.id,
        );
      }
      for (final (role, service, factory) in [
        (eventsRole, 'CommunicationService', 'createCommunicationService'),
        (preferencesRole, 'AppPreferences', 'createAppPreferences'),
        (analyticsRole, 'AnalyticsService', 'createAnalyticsService'),
        (crashReportingRole, 'CrashReporter', 'createCrashReporter'),
      ]) {
        final contributions = role.template!.contribute(testContext);
        final registration =
            contributions.whereType<RoleData<DiRegistration>>().single;

        expect(contributions.whereType<BrickContribution>(), hasLength(1));
        expect(registration.role, same(diRole));
        expect(registration.value.type.name, service);
        expect(registration.value.create.name, factory);
        expect(registration.value.lifetime, DiLifetime.lazySingleton);
        expect(
          registration.value.type.import,
          ImportRef.app(
            [...role.interface.files].single.substring('lib/'.length),
          ),
        );
      }
    });

    test('name in their notes for coding agents what their files declare',
        () async {
      for (final (role, names) in [
        (
          eventsRole,
          [
            'AppEvent',
            'CommunicationService',
            'createCommunicationService',
            'CommunicationService.fire',
            'CommunicationService.on',
          ],
        ),
        (
          analyticsRole,
          [
            'AnalyticsService',
            'createAnalyticsService',
            '_analyticsServices',
            // How an entry of the list of the providers looks.
            '_createAlone',
            // The one switch of collection, and what the app does before its
            // code chose.
            'AnalyticsService.setAnalyticsCollectionEnabled',
            'analyticsCollectedFromFirstStart',
          ],
        ),
        (
          crashReportingRole,
          [
            'CrashReporter',
            'createCrashReporter',
            '_crashReporters',
            '_createAlone',
            'installCrashReporting',
            'CrashReporter.recordError',
          ],
        ),
      ]) {
        final rendered = await renderTemplate(
          role,
          data: [_data(role, 'Console')],
          choice: _choiceOf(role),
        );
        final note = agentNoteOf(role);
        final file = role.interface.files.single;

        expect(rendered.notes.single.entryKey, role.description);
        expect(rendered.notes.single.entryValue, note, reason: role.id);
        expectNamesOfCode(note, {file: names}, files: rendered.files);
        // A provider that starts asynchronously goes into the function of
        // the role that bootstrap() awaits, which the file has with one.
        if (role != eventsRole) {
          final init =
              role == analyticsRole ? 'initAnalytics' : 'initCrashReporting';
          expect(declarationsOf(rendered.files[file]!), isNot(contains(init)));
          final withAsync = await renderTemplate(
            role,
            data: [
              _data(role, 'Console'),
              _data(role, 'Delayed', async: true),
            ],
            choice: _choiceOf(role),
          );
          expectNamesOfCode(
            note,
            {
              file: [init],
            },
            files: withAsync.files,
          );
          expect(
            declarationsOf(withAsync.files[file]!),
            contains('_startAlone'),
          );
        }
        // The file of the service, as the role names it.
        expect(
          note.text,
          contains('`${role.interface.files.single}`'),
          reason: role.id,
        );
      }
    });

    test('report the problems of the implementations', () {
      final issues = analyticsRole.template.validate(
        inputOf(
          analyticsRole,
          data: [
            dataOf(
              analyticsRole,
              const RoleImplementation(
                type: TypeRef('_Private'),
                create: FactoryRef('create', import: ImportRef.app('a.dart')),
              ),
            ),
          ],
        ),
      );

      expect(issues.single.origin, const ModuleOrigin(ModuleId('home')));
    });
  });

  group('the events template', () {
    test('creates the only implementation on first use', () async {
      final rendered = await renderTemplate(
        eventsRole,
        data: [_data(eventsRole, 'FakeEvents')],
      );
      final code = rendered.files[EventsRole.file]!;

      expectParses(code);
      expect(
        code,
        contains(
          'final CommunicationService _communicationService = '
          'impl0.createFakeEvents();',
        ),
      );
      expect(
        code,
        contains("import 'package:my_app/fakes/fake_events.dart' as impl0;"),
      );
      expect(rendered.elsewhere, isEmpty);
    });

    test('creates an asynchronous implementation in bootstrap', () async {
      final rendered = await renderTemplate(
        eventsRole,
        data: [_data(eventsRole, 'FakeEvents', async: true)],
      );
      final code = rendered.files[EventsRole.file]!;

      expectParses(code);
      expect(
        code,
        contains('late final CommunicationService _communicationService;'),
      );
      expect(
        code,
        contains('_communicationService = await impl0.initFakeEvents();'),
      );
      final start = rendered.elsewhere.single;
      expect(start.socket, AppEntryRole.bootstrapPlatform);
      expect(start.fragment!.code, 'await initEvents();');
      expect(start.fragment!.imports, [
        const ImportRef.app('core/events/communication_service.dart'),
      ]);
    });
  });

  group('the analytics template', () {
    test('forwards to all implementations', () async {
      final rendered = await _renderAnalytics(
        [
          _data(analyticsRole, 'ConsoleAnalytics'),
          _data(analyticsRole, 'OtherAnalytics'),
        ],
        present: {diRole, routerRole},
      );
      final code = rendered.files[AnalyticsRole.file]!;

      expectParses(code);
      expect(
        code,
        contains(
          'final List<AnalyticsService> _analyticsServices = [\n'
          "  ?_createAlone('createConsoleAnalytics', "
          'impl0.createConsoleAnalytics),\n'
          "  ?_createAlone('createOtherAnalytics', "
          'impl1.createOtherAnalytics),\n'
          '];',
        ),
      );
      expect(code, contains('final class _AnalyticsServices'));
      expect(code, isNot(contains('initAnalytics')));
      expect(_functionsOf(code), isNot(contains('_startAlone')));
      expect(_startUpOf(rendered), isEmpty);
    });

    test(
        'creates each implementation on its own, and leaves out one whose '
        'factory throws or whose start fails, printing its error in debug '
        'mode', () async {
      final rendered = await _renderAnalytics([
        _data(analyticsRole, 'ConsoleAnalytics'),
        _data(analyticsRole, 'DelayedAnalytics', async: true),
      ]);
      final code = rendered.files[AnalyticsRole.file]!;

      expectParses(code);
      final functions = _functionsOf(code);
      for (final (name, signature, call) in [
        (
          '_createAlone',
          'AnalyticsService? _createAlone(String name, '
              'AnalyticsService Function() create)',
          'return create();',
        ),
        (
          '_startAlone',
          'Future<AnalyticsService?> _startAlone(String name, '
              'Future<AnalyticsService> Function() start) async',
          'return await start();',
        ),
      ]) {
        final function = functions[name]!;
        final body = function.functionExpression.body as BlockFunctionBody;
        final attempt = body.block.statements.single as TryStatement;
        final expression = function.functionExpression;
        final head = '${function.returnType} ${function.name.lexeme}';
        expect(
          [
            '$head${expression.parameters}',
            if (expression.body.keyword case final keyword?) '$keyword',
          ].join(' '),
          signature,
        );
        expect('${attempt.body.statements.single}', call, reason: name);
        final handler = attempt.catchClauses.single;
        expect('${handler.exceptionType}', 'Object', reason: name);
        const printed = r"if (kDebugMode) {debugPrint('$name() failed, so "
            r"the app works without it: $error');}";
        expect(
          handler.body.statements.map((statement) => '$statement'),
          [printed, 'return null;'],
          reason: name,
        );
      }
      expect(
        code,
        contains("import 'package:flutter/foundation.dart';"),
      );
    });

    test('adds the asynchronous implementations in bootstrap', () async {
      final rendered = await _renderAnalytics([
        _data(analyticsRole, 'ConsoleAnalytics'),
        _data(analyticsRole, 'DelayedAnalytics', async: true),
      ]);
      final code = rendered.files[AnalyticsRole.file]!;

      expectParses(code);
      expect(
        code,
        contains(
          'Future<void> initAnalytics() async {\n'
          '  final started = await Future.wait([\n'
          "    _startAlone('initDelayedAnalytics', "
          'impl1.initDelayedAnalytics),\n'
          '  ]);\n'
          '  _analyticsServices.addAll(started.nonNulls);\n'
          '}',
        ),
      );
      expect(
        code,
        contains(
          "import 'package:my_app/fakes/delayed_analytics.dart' as impl1;",
        ),
      );
      expect(
        _startUpOf(rendered).single.fragment!.code,
        'await initAnalytics();',
      );
    });

    test('imports each implementation with its own prefix', () async {
      final rendered = await _renderAnalytics([
        dataOf(
          analyticsRole,
          const RoleImplementation(
            type: TypeRef('Vendor'),
            create: FactoryRef(
              'createVendor',
              import: ImportRef.app('vendor.dart', prefix: 'vendor'),
            ),
          ),
        ),
      ]);
      final code = rendered.files[AnalyticsRole.file]!;

      expectParses(code);
      expect(
        code,
        contains("?_createAlone('createVendor', impl0.createVendor),"),
      );
      expect(code, contains("import 'package:my_app/vendor.dart' as impl0;"));
      expect(code, isNot(contains('vendor.createVendor')));
    });
  });

  group('the collection of the analytics role', () {
    const option = AnalyticsRole.collectionOption;

    /// The choice of the role with [value] for its option, in [environment],
    /// or without a terminal.
    Future<Object?> choose(String? value, {SmfEnvironment? environment}) =>
        analyticsRole.template.choose(
          analyticsRole.choiceContext(
            RoleChoiceRequest(
              data: const [],
              presentRoles: {analyticsRole},
              optionValues: {option.name: value},
              environment: environment ?? FakeEnvironment(),
              context: testContext,
            ),
          ),
        );

    test(
        'is the mode option --analytics-collection, whose values are on, the '
        'first, and off', () {
      expect(analyticsRole.options, const [option]);
      expect(option.name, 'analytics-collection');
      expect(option.isMode, isTrue);
      expect(option.allowed, ['on', 'off']);
      expect(
        option.allowed,
        [for (final collection in AnalyticsCollection.values) collection.name],
      );
      expect(
        option.help,
        allOf(contains('(on, the default)'), contains('(off)')),
      );
    });

    test('is the value of the option, which nothing asks for then', () async {
      for (final collection in AnalyticsCollection.values) {
        // The environment without a terminal fails when it is asked.
        expect(await choose(collection.name), collection);
        final terminal = PromptingEnvironment(pick: 1);
        expect(
          await choose(collection.name, environment: terminal),
          collection,
        );
        expect(terminal.asked, isEmpty);
      }
    });

    test(
        'is on in a run without a terminal and without the option, which '
        'neither fails nor asks', () async {
      expect(await choose(null), AnalyticsCollection.on);
    });

    test(
        'is asked for in a terminal without the option, with on as the first '
        'item and as the one that Enter takes', () async {
      for (final (pick, collection) in AnalyticsCollection.values.indexed) {
        final terminal = PromptingEnvironment(pick: pick);

        expect(await choose(null, environment: terminal), collection);
        expect(
          terminal.asked,
          ['Does the app collect analytics before the user agrees?'],
        );
        expect(terminal.shown, [
          'Yes, from its first start',
          'No: only once your code turns it on, as after the user agrees',
        ]);
        expect(terminal.shownDefault, terminal.shown.first);
      }
    });

    test(
        'has the option for every choice, with which a run without a '
        'terminal makes the same choice', () async {
      for (final collection in AnalyticsCollection.values) {
        final options = analyticsRole.template.optionsOf(collection);

        expect(options, {'analytics-collection': collection.name});
        expect(await choose(options[option.name]), collection);
      }
    });

    test('reaches the render hooks of the role and of its providers', () {
      for (final collection in AnalyticsCollection.values) {
        expect(
          analyticsRole.collectionIn(
            inputOf(analyticsRole, choice: collection),
          ),
          collection,
        );
      }
    });

    test(
        'is the constant analyticsCollectedFromFirstStart of the file of the '
        'role, which the setter of the service names', () async {
      for (final collection in AnalyticsCollection.values) {
        final code = (await _renderAnalytics(
          [_data(analyticsRole, 'ConsoleAnalytics')],
          collection: collection,
        ))
            .files[AnalyticsRole.file]!;

        expectParses(code);
        final declaration = _collectedFromFirstStartIn(code);
        final variable = declaration.variables.variables.single;
        expect(declaration.variables.isConst, isTrue);
        expect('${declaration.variables.type}', 'bool');
        expect(
          (variable.initializer! as BooleanLiteral).value,
          collection == AnalyticsCollection.on,
          reason: collection.name,
        );
        expect(
          '${declaration.documentationComment?.tokens.join('\n')}',
          allOf(
            contains('[AnalyticsService.setAnalyticsCollectionEnabled]'),
            contains('`--analytics-collection` of `smf create`'),
            contains('A provider whose SDK starts'),
          ),
        );
        // The setter tells what the constant is for.
        final setter = parseString(content: code)
            .unit
            .declarations
            .whereType<ClassDeclaration>()
            .singleWhere(
              (type) => type.namePart.typeName.lexeme == 'AnalyticsService',
            )
            .body
            .members
            .whereType<MethodDeclaration>()
            .singleWhere(
              (method) => method.name.lexeme == 'setAnalyticsCollectionEnabled',
            );
        expect(
          '${setter.documentationComment?.tokens.join('\n')}',
          allOf(
            contains('no provider sends anything to its'),
            contains('Every provider keeps the setting on the device'),
            contains('[analyticsCollectedFromFirstStart]'),
          ),
        );
      }
    });

    test(
        'makes bootstrap() of a debug build print, in an app that collects '
        'nothing before its code chose, that collection waits for the code',
        () async {
      final off = await _renderAnalytics(
        [_data(analyticsRole, 'ConsoleAnalytics')],
        collection: AnalyticsCollection.off,
      );
      final on = await _renderAnalytics(
        [_data(analyticsRole, 'ConsoleAnalytics')],
      );

      expect(_startUpOf(on), isEmpty);
      final print = _startUpOf(off).single;
      expect(print.socket, AppEntryRole.bootstrapEarly);
      expect(print.when, isEmpty);
      final statement = parseString(
        content: 'void main() {${print.fragment!.code}}',
      ).unit.declarations.whereType<FunctionDeclaration>().single;
      final body = statement.functionExpression.body as BlockFunctionBody;
      final check = body.block.statements.single as IfStatement;
      expect(
        '${check.expression}',
        'kDebugMode && !analyticsCollectedFromFirstStart',
      );
      final call = ((check.thenStatement as Block).statements.single
              as ExpressionStatement)
          .expression as MethodInvocation;
      expect(call.methodName.name, 'debugPrint');
      final message =
          (call.argumentList.arguments.single as StringLiteral).stringValue!;
      expect(message, isNot(contains('\n')));
      expect(
        message,
        allOf(
          startsWith('Analytics: this app collects nothing on a device until '
              'its code turns collection on there with '
              'setAnalyticsCollectionEnabled(true)'),
          contains('See the section Analytics of README.md.'),
        ),
      );
      expect(print.fragment!.imports, const [
        ImportRef('package:flutter/foundation.dart'),
        ImportRef.app('core/analytics/analytics_service.dart'),
      ]);
    });

    test(
        'writes the section of the role in the README of the app, which tells '
        'what the app does before its code chose, the switch, consent and '
        'what the setting does not cover, and names no provider', () async {
      for (final collection in AnalyticsCollection.values) {
        final rendered = await _renderAnalytics(
          [_data(analyticsRole, 'ConsoleAnalytics')],
          collection: collection,
        );
        final section = _analyticsSectionOf(rendered);
        final other = AnalyticsCollection.values.singleWhere(
          (value) => value != collection,
        );

        expect(
          section,
          startsWith(
            'This app was generated with '
            '`--analytics-collection=${collection.name}`: ',
          ),
          reason: collection.name,
        );
        expect(
          section,
          contains(
            '`analyticsCollectedFromFirstStart` in '
            '`${AnalyticsRole.file}` is '
            '`${collection == AnalyticsCollection.on}`',
          ),
        );
        expect(
          section,
          isNot(contains('`--analytics-collection=${other.name}`: ')),
        );
        expect(
          section,
          allOf([
            contains('`setAnalyticsCollectionEnabled()` of the analytics '
                'service is the one switch'),
            contains('Every provider keeps the setting on the device'),
            contains('Off means that nothing is sent. It does not mean that '
                'no SDK writes to the device'),
            contains('the native lines of each provider whose SDK starts '
                'before Dart, which its section of this README names'),
            contains('In the European Economic Area, the ePrivacy rules'),
            contains('In the UK, the Privacy and Electronic Communications '
                'Regulations, as the Data (Use and Access) Act 2025 amended '
                'them'),
            contains('The guidance of the ICO tells what qualifies.'),
            contains('SMF shows no consent dialog.'),
            contains('5.1.1(ii)'),
            contains('give the settings screen a switch that calls '
                '`setAnalyticsCollectionEnabled()`'),
            contains('a link to a privacy policy'),
            contains('Crash reports are another role'),
            endsWith('This is not legal advice.\n'),
          ]),
          reason: collection.name,
        );
        // A debug build says so only in an app that collects nothing before
        // its code chose.
        expect(
          section.contains('a debug build prints a line at each start'),
          collection == AnalyticsCollection.off,
        );
        expectNamesOfCodeIn(
          section,
          {
            AnalyticsRole.file: [
              'analyticsCollectedFromFirstStart',
              'AnalyticsService.setAnalyticsCollectionEnabled',
            ],
          },
          files: rendered.files,
        );
        // It holds whichever modules provide the role.
        expect(
          section.toLowerCase(),
          allOf(isNot(contains('firebase')), isNot(contains('console'))),
        );
      }
    });
  });

  group('the crash reporting template', () {
    test(
        'installs in bootstrap a handler for the errors that Flutter '
        'catches, which it still presents in every mode, and one for the '
        'other errors of the main isolate', () async {
      final rendered = await renderTemplate(
        crashReportingRole,
        data: [_data(crashReportingRole, 'ConsoleCrashReporter')],
      );
      final code = rendered.files[CrashReportingRole.file]!;

      expectParses(code);
      final unit = parseString(content: code).unit;
      final install = unit.declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((f) => f.name.lexeme == 'installCrashReporting');
      final body = install.functionExpression.body as BlockFunctionBody;
      // No listener on the isolate: it would take the errors of timers and
      // ports from the platform dispatcher, without their type, and the
      // engine would not print them.
      expect(body.block.statements.map((statement) => '$statement'), [
        'final reporter = createCrashReporter();',
        'final presentError = FlutterError.onError;',
        equals(
          'FlutterError.onError = (details) {presentError?.call(details); '
          'unawaited(reporter.recordFlutterError(details, fatal: true));};',
        ),
        equals(
          'PlatformDispatcher.instance.onError = (error, stackTrace) '
          '{unawaited(reporter.recordError(error, stackTrace, fatal: '
          'true)); return !kDebugMode;};',
        ),
      ]);
      expect(
        [
          for (final directive in unit.directives)
            if (directive is ImportDirective) directive.uri.stringValue,
        ],
        isNot(contains('dart:isolate')),
      );
      expect(
        rendered.elsewhere.single.fragment!.code,
        'installCrashReporting();',
      );
    });

    test('waits for asynchronous reporters before installing them', () async {
      final rendered = await renderTemplate(
        crashReportingRole,
        data: [_data(crashReportingRole, 'SlowReporter', async: true)],
      );
      final code = rendered.files[CrashReportingRole.file]!;

      expectParses(code);
      expect(
        code,
        contains('final List<CrashReporter> _crashReporters = [\n];'),
      );
      // Without an implementation created with the app, the file has no
      // function that creates one on its own, which would be unused.
      expect(_functionsOf(code), isNot(contains('_createAlone')));
      expect(_functionsOf(code), contains('_startAlone'));
      expect(
        rendered.elsewhere.single.fragment!.code,
        'await initCrashReporting();\ninstallCrashReporting();',
      );
    });
  });

  group('the closed sockets of the service roles', () {
    test('reject code from modules, even from providers', () {
      final issue = analyticsRole
          .checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  analyticsRole
                      .data(_implementation('A'))
                      .withOrigin(const ModuleOrigin(ModuleId('vendor'))),
                ],
                presentRoles: {analyticsRole},
                context: testContext,
              ),
              module: const ModuleDescriptor(
                id: ModuleId('vendor'),
                description: 'Vendor',
                kind: ModuleKinds.infrastructure,
                providers: [RoleProvider.plain(analyticsRole)],
              ),
              contributions: const [
                SocketContribution.code(
                  AnalyticsRole.implementations,
                  Fragment('createVendor(),'),
                ),
              ],
            ),
          )
          .single;

      expect(issue.message, contains('socket analytics.implementations'));
      expect(issue.hint, contains('RoleImplementation'));
    });
  });

  group('the factories of the service roles', () {
    const di = ModuleDescriptor(
      id: ModuleId('get_it'),
      description: 'DI',
      kind: ModuleKinds.infrastructure,
      providers: [_Container()],
    );
    const feature = ModuleDescriptor(
      id: ModuleId('home'),
      description: 'Home',
      kind: ModuleKinds.feature,
      uses: {analyticsRole},
    );

    List<SmfIssue> check(Role<RoleImplementation> role, String factory) =>
        role.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: const [],
              presentRoles: {role},
              context: testContext,
            ),
            files: {
              for (final path in [
                'lib/core/di/dependencies.dart',
                'lib/features/home/home_screen.dart',
                'lib/core/analytics/analytics_service.dart',
              ])
                path: DartFileIndex(
                  path: path,
                  imports: [
                    IndexedImport(
                      'package:my_app/'
                      '${role.interface.files.single.substring(4)}',
                    ),
                  ],
                  invocations: [IndexedInvocation(factory)],
                ),
            },
            owners: const {
              'lib/core/di/dependencies.dart': ModuleOrigin(ModuleId('get_it')),
              'lib/features/home/home_screen.dart':
                  ModuleOrigin(ModuleId('home')),
              'lib/core/analytics/analytics_service.dart':
                  RoleTemplateOrigin(analyticsRole),
            },
            modules: const [di, feature],
          ),
        );

    test(
        'are called only by the DI container, and by the template of a role '
        'but for the factory of the preferences', () {
      for (final (role, factory) in [
        (eventsRole, 'createCommunicationService'),
        (preferencesRole, 'createAppPreferences'),
        (analyticsRole, 'createAnalyticsService'),
        (crashReportingRole, 'createCrashReporter'),
      ]) {
        final issues = check(role, factory);
        final issue = issues.first;

        expect(issue.message, contains('calls $factory()'));
        expect(issue.path, 'lib/features/home/home_screen.dart');
        expect(issue.origin, const ModuleOrigin(ModuleId('home')));
        // A module gets its settings through the restorers of the
        // preferences, and any other service through the container.
        expect(
          issue.hint,
          identical(role, preferencesRole)
              ? startsWith('Put a function into PreferencesRole.restorers')
              : startsWith('Resolve the service in the composition file'),
        );
        // The file of the analytics role calls the factory too. The
        // template of a role gets the preferences through the restorers,
        // as a module does, and any other service from its factory.
        expect(
          [for (final other in issues.skip(1)) other.origin],
          identical(role, preferencesRole)
              ? [const RoleTemplateOrigin(analyticsRole)]
              : isEmpty,
          reason: '$role',
        );
      }
    });

    test('are not torn off or read through a prefix elsewhere', () {
      List<SmfIssue> issuesOf(DartFileIndex file) =>
          analyticsRole.checkStructure(
            StructuralRuleRequest(
              hook: const RoleHookRequest(
                data: [],
                presentRoles: {analyticsRole},
                context: testContext,
              ),
              files: {file.path: file},
              owners: {file.path: const ModuleOrigin(ModuleId('home'))},
              modules: const [feature],
            ),
          );

      expect(
        issuesOf(
          const DartFileIndex(
            path: 'lib/a.dart',
            imports: [IndexedImport('core/analytics/analytics_service.dart')],
            references: [IndexedReference('createAnalyticsService')],
          ),
        ),
        hasLength(1),
      );
      expect(
        issuesOf(
          const DartFileIndex(
            path: 'lib/b.dart',
            imports: [
              IndexedImport(
                'package:my_app/core/analytics/analytics_service.dart',
                prefix: 'analytics',
              ),
            ],
            memberAccesses: [
              IndexedMemberAccess('analytics', 'createAnalyticsService'),
            ],
          ),
        ),
        hasLength(1),
      );
    });

    test('are the functions of the role file, not same-named others', () {
      expect(
        analyticsRole.checkStructure(
          const StructuralRuleRequest(
            hook: RoleHookRequest(
              data: [],
              presentRoles: {analyticsRole},
              context: testContext,
            ),
            files: {
              'lib/a.dart': DartFileIndex(
                path: 'lib/a.dart',
                imports: [
                  IndexedImport(
                    'package:my_app/core/analytics/analytics_service.dart',
                    prefix: 'analytics',
                  ),
                ],
                invocations: [
                  IndexedInvocation('createAnalyticsService'),
                  IndexedInvocation('createAnalyticsService', target: 'x'),
                ],
                references: [IndexedReference('createAnalyticsService')],
              ),
            },
            owners: {'lib/a.dart': ModuleOrigin(ModuleId('home'))},
            modules: [feature],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('the functions of the implementations', () {
    const file = ImportRef.app('core/fixture/fixture.dart');
    const path = 'lib/core/fixture/fixture.dart';

    List<SmfIssue> check(DartFileIndex index) => analyticsRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: [
                dataOf(
                  analyticsRole,
                  const RoleImplementation(
                    type: TypeRef('FixtureAnalytics'),
                    create: FactoryRef('createFixture', import: file),
                  ),
                  module: 'fixture',
                ),
                dataOf(
                  analyticsRole,
                  const RoleImplementation.async(
                    type: TypeRef('OtherAnalytics'),
                    init: FactoryRef(
                      'initOther',
                      import: ImportRef('package:other/other.dart'),
                    ),
                  ),
                  module: 'other',
                ),
              ],
              presentRoles: {analyticsRole},
              context: testContext,
            ),
            files: {path: index},
          ),
        );

    test('exist in their file and take no arguments', () {
      expect(
        check(
          const DartFileIndex(
            path: path,
            declarations: [
              IndexedDeclaration(
                name: 'createFixture',
                kind: DeclarationKind.function,
              ),
            ],
          ),
        ),
        isEmpty,
      );

      final issues = check(
        const DartFileIndex(
          path: path,
          declarations: [
            IndexedDeclaration(
              name: 'createFixture',
              kind: DeclarationKind.function,
              parameters: [
                IndexedParameter(
                  'name',
                  kind: ParameterKind.requiredPositional,
                ),
              ],
            ),
          ],
        ),
      );
      expect(issues.single.message, contains('must not require more than 0'));
      expect(issues.single.origin, const ModuleOrigin(ModuleId('fixture')));
      expect(
        check(const DartFileIndex(path: path)).single.message,
        contains('does not declare function createFixture()'),
      );
    });
  });

  test('the crash reporter lets the user id be cleared', () {
    final brick = crashReportingRole.template
        .contribute(testContext)
        .whereType<BrickContribution>()
        .single;
    final code = templatesOf(brick.bundle)[CrashReportingRole.file]!;

    expect(code, contains('Future<void> setUserId(String? userId);'));
    expect(code, contains('return !kDebugMode;'));
  });
}
