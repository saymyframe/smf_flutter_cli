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

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });
  });

  group('an app of every fixture', () {
    final harness = ContractHarness(ModuleRegistry(fixtureModules()));

    Future<ContractResult> checked(List<ModuleId> modules) async {
      final result = await harness.check(
        ContractCase('every fixture', requested: modules),
      );
      expect(result.errors.map((issue) => '$issue'), isEmpty);
      return result;
    }

    /// What the contributions of the modules and role templates to [socket]
    /// render to, before the render hooks add their fragments.
    Map<String, String> rendered(ContractResult result, SocketRef socket) =>
        socket.render([
          for (final collected
              in result.validation!.socketOrders[socket]!.contributions)
            collected.contribution as SocketContribution,
        ]);

    test('with BLoC', () async {
      final result = await checked(everyFixture());
      final resolution = result.resolution!;
      final pubspec = result.validation!.pubspec;

      expect(
        resolution.modules.map((module) => module.id.value),
        containsAll([
          'flutter_core',
          'fake_router',
          'fake_di',
          'fake_analytics',
          'fake_parent',
        ]),
      );
      expect(
        resolution.module(const ModuleId('fake_feature'))!.variant,
        FakeBlocModule.id,
      );
      expect(
        (result.choices![routerRole]! as RouterChoice).startPath,
        '/fake_feature',
      );
      expect(
        result.validation!.socketOrders[AppEntryRole.bootstrapPlatform]!
            .contributions
            .map((collected) => '${collected.origin}'),
        // The templates of the roles add their fragments when they render.
        ['fake_sockets'],
      );
      // The variant takes any version of flutter_bloc; its provider owns the
      // constraint.
      expect(
        pubspec.dependencies['flutter_bloc']!.constraintText,
        '^9.1.1',
      );
      expect(pubspec.devDependencies.keys, contains('json_serializable'));
      expect(pubspec.generate, isTrue);
      expect(pubspec.usesMaterialDesign, isTrue);
      expect(result.collection!.applyingOf<CodegenRequest>(), hasLength(1));
    });

    test('with Riverpod', () async {
      final result = await checked(
        everyFixture(stateManager: FakeRiverpodModule.id),
      );

      expect(
        result
            .validation!.socketOrders[AppEntryRole.rootWrappers]!.contributions
            .map((collected) => '${collected.origin}'),
        ['fake_riverpod', 'fake_sockets'],
      );
      expect(
        result.validation!.pubspec.dependencies['flutter_riverpod']!
            .constraintText,
        '^3.0.0',
      );
    });

    test('merges what two modules put into the same keys', () async {
      final result = await checked(everyFixture());

      expect(
        rendered(result, AppEntryRole.iosDeploymentTarget).values.single,
        '16.0',
      );
      expect(
        rendered(result, AppEntryRole.appArgs).values.single,
        contains("supportedLocales: [Locale('en')],"),
      );
      expect(
        rendered(result, AppEntryRole.androidManifestPermissions).values.single,
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.VIBRATE"/>',
      );
      expect(
        'com.example.fixture.KEY'.allMatches(
          rendered(
            result,
            AppEntryRole.androidManifestApplicationMeta,
          ).values.single,
        ),
        hasLength(1),
      );
      final plist = rendered(result, AppEntryRole.infoPlist).values.single;
      expect(plist, contains('<string>fetch</string>'));
      expect(plist, contains('<string>remote-notification</string>'));
      expect('<key>FixtureName</key>'.allMatches(plist), hasLength(1));
      expect(
        rendered(result, AppEntryRole.gradleSettingsPlugins).values.single,
        '    id("io.github.ben-manes.versions") version("0.64.0") apply false',
      );
      expect(
        rendered(result, AppEntryRole.gradleAppPlugins).values.single,
        '    id("io.github.ben-manes.versions")',
      );
      expect(
        rendered(result, AppEntryRole.gradleAppDependencies).values.single,
        '    implementation("androidx.annotation:annotation:1.9.1")',
      );
    });

    test('a module that depends on another fills its sockets', () async {
      final result = await checked(everyFixture());
      final orders = result.validation!.socketOrders;

      expect(
        orders[FakeParentModule.setup]!.contributions.map(
              (collected) => '${collected.origin}',
            ),
        ['fake_child'],
      );
      expect(
        orders[FakeParentModule.channels('alerts')]!.contributions.map(
              (collected) => '${collected.origin}',
            ),
        ['fake_child'],
      );
    });
  });

  group('smf create', () {
    test('generates an app of every fixture', () async {
      final runner = RecordingRunner();
      final host = testHost(processRunner: runner);

      GeneratedApp? created;
      final code = await runSmf(
        [
          'create',
          'fixture_app',
          '-m',
          everyFixture().join(','),
          '--no-input',
          '--skip-external-setup',
          '--strict',
        ],
        modules: fixtureModules(),
        hostFor: ({required verbose}) => host,
        onCreated: (app) => created = app,
      );

      expect(code, SmfExitCodes.success);
      expect(created?.path, '/work/fixture_app');
      expect(created?.skippedSteps, isEmpty);
      expect(runner.lines, [
        'flutter pub get',
        'dart run build_runner build --force-jit',
        'dart fix --apply --code=$_importCodes',
        'dart fix --apply',
        'dart format .',
        'flutter pub get',
      ]);
      final files = host.fileSystem;
      expect(
        files
            .file('/work/fixture_app/lib/core/di/dependencies.dart')
            .existsSync(),
        isTrue,
      );
      expect(
        files.file('/work/fixture_app/pubspec.yaml').readAsStringSync(),
        contains('build_runner: "^2.10.0"'),
      );
    });

    test('a DI container without a capability leaves out what needs it',
        () async {
      Future<GeneratedApp?> create(
        Set<DiCapability> capabilities, {
        bool strict = false,
      }) =>
          CreatePipeline(
            registry: ModuleRegistry(
              fixtureModules(diCapabilities: capabilities),
            ),
            host: testHost(processRunner: RecordingRunner()),
          ).run(
            CreateRequest(
              appName: 'fixture_app',
              modules: everyFixture(),
              strict: strict,
            ),
          );

      final lenient = await create({DiCapability.instanceName});
      expect(
        lenient!.leftOut.map((leftOut) => '${leftOut.module}'),
        ['fake_registrations'],
      );

      await expectLater(
        create(const {}, strict: true),
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

/// The codes of the diagnostics that the import cleanup fixes.
const _importCodes = 'duplicate_import,unnecessary_import,unused_import';

/// The cases of the harness over the fixtures, each building another app,
/// so that a case that stops being built fails the test.
const _cases = [
  'flutter_core with router',
  'flutter_core',
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
