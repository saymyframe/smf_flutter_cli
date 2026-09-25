import 'package:smf_contracts/lego.dart';
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

/// The issues of the module rule of [role] for a module that [provides] the
/// role or only uses it, and contributes [implementations].
List<SmfIssue> _moduleIssues(
  Role<RoleImplementation> role, {
  required bool provides,
  required List<RoleImplementation> implementations,
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
    for (final role in [eventsRole, analyticsRole, crashReportingRole]) {
      test('lets each provider of the ${role.id} contribute one implementation',
          () {
        expect(
          _moduleIssues(
            role,
            provides: true,
            implementations: [_implementation('A')],
          ),
          isEmpty,
        );
        expect(
          _moduleIssues(role, provides: false, implementations: const []),
          isEmpty,
        );
        expect(
          _moduleIssues(role, provides: true, implementations: const [])
              .single
              .message,
          contains('exactly one implementation, but the module contributes 0'),
        );
        final issue = _moduleIssues(
          role,
          provides: false,
          implementations: [_implementation('A')],
        ).single;
        expect(issue.message, contains('which only its providers do'));
        expect(issue.origin, const ModuleOrigin(ModuleId('vendor')));
      });
    }
  });

  group('the templates of the service roles', () {
    test('register the service in the DI container', () {
      for (final (role, service, factory) in [
        (eventsRole, 'CommunicationService', 'createCommunicationService'),
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
          'createFakeEvents();',
        ),
      );
      expect(
        code,
        contains("import 'package:my_app/fakes/fake_events.dart';"),
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
      expect(code, contains('_communicationService = await initFakeEvents();'));
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
      final rendered = await renderTemplate(
        analyticsRole,
        data: [
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
          '  createConsoleAnalytics(),\n'
          '  createOtherAnalytics(),\n'
          '];',
        ),
      );
      expect(code, contains('final class _AnalyticsServices'));
      expect(code, isNot(contains('initAnalytics')));
      expect(rendered.elsewhere, isEmpty);
    });

    test('adds the asynchronous implementations in bootstrap', () async {
      final rendered = await renderTemplate(
        analyticsRole,
        data: [
          _data(analyticsRole, 'ConsoleAnalytics'),
          _data(analyticsRole, 'DelayedAnalytics', async: true),
        ],
      );
      final code = rendered.files[AnalyticsRole.file]!;

      expectParses(code);
      expect(code, contains('Future<void> initAnalytics() async {'));
      expect(code, contains('initDelayedAnalytics(),'));
      expect(
        code,
        contains("import 'package:my_app/fakes/delayed_analytics.dart';"),
      );
      expect(
        rendered.elsewhere.single.fragment!.code,
        'await initAnalytics();',
      );
    });

    test('refers to prefixed factories by their prefix', () async {
      final rendered = await renderTemplate(
        analyticsRole,
        data: [
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
        ],
      );
      final code = rendered.files[AnalyticsRole.file]!;

      expectParses(code);
      expect(code, contains('vendor.createVendor(),'));
      expect(
        code,
        contains("import 'package:my_app/vendor.dart' as vendor;"),
      );
    });
  });

  group('the crash reporting template', () {
    test('installs the handlers in bootstrap', () async {
      final rendered = await renderTemplate(
        crashReportingRole,
        data: [_data(crashReportingRole, 'ConsoleCrashReporter')],
      );
      final code = rendered.files[CrashReportingRole.file]!;

      expectParses(code);
      expect(code, contains('void installCrashReporting() {'));
      expect(code, contains('FlutterError.onError = (details) {'));
      expect(code, contains('PlatformDispatcher.instance.onError ='));
      expect(code, contains('Isolate.current.addErrorListener('));
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
      expect(
        rendered.elsewhere.single.fragment!.code,
        'await initCrashReporting();\ninstallCrashReporting();',
      );
    });
  });
}
