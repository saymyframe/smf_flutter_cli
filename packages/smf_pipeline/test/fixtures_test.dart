import 'package:fake_di/fake_di.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_roles/fake_roles.dart';
import 'package:fake_router/fake_router.dart';
import 'package:fake_state/fake_state.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The fixture registry, with the test scaffold as the app entry until
/// flutter_core moves to the lego model.
List<SmfModule> _modules({Set<DiCapability>? capabilities}) => [
      scaffold(contributions: [entryBrick()]),
      const FakeRouterModule(),
      if (capabilities == null)
        const FakeDiModule()
      else
        FakeDiModule(capabilities: capabilities),
      const FakeBlocModule(),
      const FakeRiverpodModule(),
      const FakeFeatureModule(),
      const FakeSocketsModule(),
      const FakeAnalyticsModule(),
      const FakeCrashModule(),
      const FakeRegistrationsModule(),
      const FakeCodegenModule(),
      const FakeClockBadgeModule(),
      const FakeClockUserModule(),
    ];

const _everything = [
  ModuleId('fake_feature'),
  ModuleId('fake_bloc'),
  ModuleId('fake_sockets'),
  ModuleId('fake_registrations'),
  ModuleId('fake_codegen'),
  ModuleId('fake_crash'),
  ModuleId('fake_clock_user'),
  ModuleId('fake_clock_badge'),
];

void main() {
  test('the fixtures form a valid registry', () {
    expect(ModuleRegistry.problemsOf(_modules()), isEmpty);
  });

  test('every fixture passes the contract harness in every case', () async {
    final harness = ContractHarness(ModuleRegistry(_modules()));

    final results = await harness.checkAll();

    expect(results.length, greaterThan(20));
    for (final result in results) {
      expect(
        result.errors.map((issue) => '$issue'),
        isEmpty,
        reason: '${result.contractCase}',
      );
    }
  });

  group('the pipeline plans an app of every fixture', () {
    Future<GenerationPlan> planOf(
      List<ModuleId> modules, {
      Set<DiCapability>? capabilities,
      bool strict = false,
    }) async {
      final host = FakeHost();
      final plan = await CreatePipeline(
        registry: ModuleRegistry(_modules(capabilities: capabilities)),
        host: host.host,
      ).plan(
        CreateRequest(
          appName: 'fixture_app',
          modules: modules,
          strict: strict,
        ),
      );
      await plan!.environment.dispose();
      return plan;
    }

    test('with BLoC', () async {
      final plan = await planOf(_everything);

      expect(plan.leftOut, isEmpty);
      expect(
        plan.resolution.modules.map((m) => m.id.value),
        containsAll(['fake_router', 'fake_di', 'fake_analytics', 'scaffold']),
      );
      expect(
        plan.resolution.module(const ModuleId('fake_feature'))!.variant,
        const ModuleId('fake_bloc'),
      );
      expect(
        (plan.choices[routerRole]! as RouterChoice).startPath,
        '/fake_feature',
      );
      expect(
        plan.socketOrders[AppEntryRole.bootstrapPlatform]!.contributions
            .map((c) => '${c.origin}'),
        // The templates of the roles add their fragments when they render,
        // at stage 8.
        ['fake_sockets'],
      );
      expect(plan.pubspec.dependencies.keys, contains('flutter_bloc'));
      expect(plan.pubspec.devDependencies.keys, contains('json_serializable'));
      expect(plan.pubspec.generate, isTrue);
      expect(plan.collection.applyingOf<CodegenRequest>(), hasLength(1));
    });

    test('with Riverpod', () async {
      final plan = await planOf([
        ..._everything.where((id) => id.value != 'fake_bloc'),
        const ModuleId('fake_riverpod'),
      ]);

      expect(plan.leftOut, isEmpty);
      expect(
        plan.socketOrders[AppEntryRole.rootWrappers]!.contributions
            .map((c) => '${c.origin}'),
        ['fake_riverpod', 'fake_sockets'],
      );
    });

    test('a DI container without a capability leaves out what needs it',
        () async {
      final lenient = await planOf(
        _everything,
        capabilities: {DiCapability.instanceName},
      );
      expect(
        lenient.leftOut.map((l) => '${l.module}'),
        ['fake_registrations'],
      );

      await expectLater(
        planOf(_everything, capabilities: const {}, strict: true),
        throwsA(
          isA<GenerationFailedException>().having(
            (e) => e.issues.map((issue) => issue.message),
            'issues',
            contains(contains('which the selected DI container does not')),
          ),
        ),
      );
    });
  });
}
