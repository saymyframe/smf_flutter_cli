import 'package:fake_infra/fake_infra.dart';
import 'package:fake_state/fake_state.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'host.dart';

void main() {
  test('the fixtures form a valid registry', () {
    expect(ModuleRegistry.problemsOf(fixtureModules()), isEmpty);
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(
        ModuleRegistry(fixtureModules()),
      ).checkAll();
    });

    test('builds an app for every combination of the fixtures', () {
      expect(
        results.map((result) => result.contractCase.name),
        _cases,
      );
    });

    test('finds no errors in any app', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
      }
    });
  });

  group('the pipeline plans an app of every fixture', () {
    Future<GenerationPlan> planOf(
      List<ModuleId> modules, {
      Set<DiCapability>? capabilities,
      bool strict = false,
    }) async {
      final plan = await CreatePipeline(
        registry: ModuleRegistry(
          fixtureModules(diCapabilities: capabilities),
        ),
        host: testHost(),
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

    /// What the contributions to [socket] render to, before stage 8 adds the
    /// fragments of the render hooks.
    Map<String, String> rendered(GenerationPlan plan, SocketRef socket) =>
        socket.render([
          for (final collected in plan.socketOrders[socket]!.contributions)
            collected.contribution as SocketContribution,
        ]);

    test('with BLoC', () async {
      final plan = await planOf(everyFixture());

      expect(plan.leftOut, isEmpty);
      expect(
        plan.resolution.modules.map((module) => module.id.value),
        containsAll([
          'fake_scaffold',
          'fake_router',
          'fake_di',
          'fake_analytics',
          'fake_parent',
        ]),
      );
      expect(
        plan.resolution.module(const ModuleId('fake_feature'))!.variant,
        FakeBlocModule.id,
      );
      expect(
        (plan.choices[routerRole]! as RouterChoice).startPath,
        '/fake_feature',
      );
      expect(
        plan.socketOrders[AppEntryRole.bootstrapPlatform]!.contributions.map(
          (collected) => '${collected.origin}',
        ),
        // The templates of the roles add their fragments when they render,
        // at stage 8.
        ['fake_sockets'],
      );
      // The variant takes any version of flutter_bloc; its provider owns the
      // constraint.
      expect(
        plan.pubspec.dependencies['flutter_bloc']!.constraintText,
        '^9.1.1',
      );
      expect(plan.pubspec.devDependencies.keys, contains('json_serializable'));
      expect(plan.pubspec.generate, isTrue);
      expect(plan.pubspec.usesMaterialDesign, isTrue);
      expect(plan.collection.applyingOf<CodegenRequest>(), hasLength(1));
    });

    test('with Riverpod', () async {
      final plan = await planOf(
        everyFixture(stateManager: FakeRiverpodModule.id),
      );

      expect(plan.leftOut, isEmpty);
      expect(
        plan.socketOrders[AppEntryRole.rootWrappers]!.contributions.map(
          (collected) => '${collected.origin}',
        ),
        ['fake_riverpod', 'fake_sockets'],
      );
      expect(
        plan.pubspec.dependencies['flutter_riverpod']!.constraintText,
        '^3.0.0',
      );
    });

    test('merges what two modules put into the same keys', () async {
      final plan = await planOf(everyFixture());

      expect(
        rendered(plan, AppEntryRole.iosDeploymentTarget).values.single,
        '14.0',
      );
      expect(
        rendered(plan, AppEntryRole.appArgs).values.single,
        contains("supportedLocales: [Locale('en')],"),
      );
      expect(
        rendered(plan, AppEntryRole.androidManifestPermissions).values.single,
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.VIBRATE"/>',
      );
      expect(
        'com.example.fixture.KEY'.allMatches(
          rendered(
            plan,
            AppEntryRole.androidManifestApplicationMeta,
          ).values.single,
        ),
        hasLength(1),
      );
      final plist = rendered(plan, AppEntryRole.infoPlist).values.single;
      expect(plist, contains('<string>fetch</string>'));
      expect(plist, contains('<string>remote-notification</string>'));
      expect('<key>FixtureName</key>'.allMatches(plist), hasLength(1));
      expect(
        rendered(plan, AppEntryRole.gradleSettingsPlugins).values.single,
        '    id("io.github.ben-manes.versions") version("0.64.0") apply false',
      );
      expect(
        rendered(plan, AppEntryRole.gradleAppPlugins).values.single,
        '    id("io.github.ben-manes.versions")',
      );
      expect(
        rendered(plan, AppEntryRole.gradleAppDependencies).values.single,
        '    implementation("androidx.annotation:annotation:1.9.1")',
      );
    });

    test('a module that depends on another fills its sockets', () async {
      final plan = await planOf(everyFixture());

      expect(
        plan.socketOrders[FakeParentModule.setup]!.contributions.map(
          (collected) => '${collected.origin}',
        ),
        ['fake_child'],
      );
      expect(
        plan.socketOrders[FakeParentModule.channels('alerts')]!.contributions
            .map((collected) => '${collected.origin}'),
        ['fake_child'],
      );
    });

    test(
      'a DI container without a capability leaves out what needs it',
      () async {
        final lenient = await planOf(
          everyFixture(),
          capabilities: {DiCapability.instanceName},
        );
        expect(
          lenient.leftOut.map((leftOut) => '${leftOut.module}'),
          ['fake_registrations'],
        );

        await expectLater(
          planOf(everyFixture(), capabilities: const {}, strict: true),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => e.issues.map((issue) => issue.message),
              'issues',
              contains(contains('which the selected DI container does not')),
            ),
          ),
        );
      },
    );
  });
}

/// The cases of the harness over the fixtures, each building another app,
/// so that a case that stops being built fails the test.
const _cases = [
  'fake_scaffold with router',
  'fake_scaffold',
  'fake_di',
  'fake_bloc',
  'fake_riverpod',
  'fake_feature (fake_bloc)',
  'fake_feature (fake_riverpod)',
  'fake_sockets',
  'fake_overlap',
  'fake_analytics with di, router',
  'fake_analytics with di',
  'fake_analytics with router',
  'fake_analytics',
  'fake_crash with di',
  'fake_crash',
  'fake_events with di',
  'fake_events',
  'fake_registrations',
  'fake_parent',
  'fake_child',
  'fake_codegen',
  'fake_clock_badge',
  'fake_clock_user with clock, badge',
  'fake_clock_user',
];
