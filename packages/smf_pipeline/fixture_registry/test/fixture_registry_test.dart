import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_state/fake_state.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_go_router/smf_go_router.dart';
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

    test(
        'builds an app of every fixture that fits for each router, DI '
        'container and state manager', () async {
      final harness = ContractHarness(ModuleRegistry(fixtureModules()));
      final cases = harness.casesOfAll();
      const routers = ['fake_router', 'go_router'];
      const containers = ['fake_di', 'get_it'];
      const stateManagers = ['fake_bloc', 'fake_riverpod'];
      final picks = [
        for (final router in routers)
          for (final container in containers)
            for (final stateManager in stateManagers)
              (router, container, stateManager),
      ];

      expect(cases.map((c) => '$c'), [
        for (final (router, container, stateManager) in picks)
          'every module ($router, $container, $stateManager)',
      ]);
      for (final (index, contractCase) in cases.indexed) {
        final (router, container, stateManager) = picks[index];
        final result = await harness.check(contractCase);
        expect(result.errors.map((issue) => '$issue'), isEmpty);
        expect(
          result.resolution!.modules.map((module) => module.id.value),
          allOf(
            containsAll([
              stateManager,
              router,
              container,
              'fake_sockets',
              'fake_feature',
              'fake_second',
              'fake_registrations',
              'bottom_tabs',
            ]),
            isNot(contains(_other(stateManagers, stateManager))),
            isNot(contains(_other(routers, router))),
            isNot(contains(_other(containers, container))),
          ),
        );
        // Both features can start the app, so the harness answers the
        // question of the router with the first, as the user who presses
        // Enter would.
        expect(result.answers, {'start': '/fake_feature'});
      }
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
      expect(result.answers, {'start': '/fake_feature'});
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

  group('an app of every fixture with bottom tabs and go_router', () {
    final harness = ContractHarness(ModuleRegistry(fixtureModules()));
    final modules = [
      ...everyFixture(router: GoRouterModule.id),
      const ModuleId('bottom_tabs'),
    ];

    /// The initial locations of the router of the app of [result] and then
    /// of the branches of its main navigation.
    List<String> initialLocationsOf(ContractResult result) {
      final unit = parseString(
        content: result.app!.files[RouterRole.appRouterFactoryFile]!.text,
      ).unit;
      final finder = _NamedArguments();
      unit.accept(finder);
      return finder.initialLocations;
    }

    test('starts on the first screen that can start it, which it answered',
        () async {
      final result = await harness.check(
        ContractCase('tabs', requested: modules),
      );

      expect(result.errors.map((issue) => '$issue'), isEmpty);
      expect(result.answers, {'start': '/fake_feature'});
      expect(
        initialLocationsOf(result),
        ['/fake_feature', '/fake_feature', '/fake_second'],
      );
    });

    test('starts on the second tab that --start names', () async {
      final result = await harness.check(
        ContractCase(
          'tabs',
          requested: modules,
          roleOptions: const {'start': '/fake_second'},
        ),
      );

      expect(result.errors.map((issue) => '$issue'), isEmpty);
      expect(result.answers, isEmpty);
      expect(
        initialLocationsOf(result),
        ['/fake_second', '/fake_feature', '/fake_second'],
      );
    });

    test('is an app of the matrix, with the start that the harness answered',
        () async {
      final (:apps, :failed) = await matrixOf(fixtureModules());

      expect(failed, isEmpty);
      final every = [
        for (final app in apps)
          if (app.name.startsWith('every module')) app,
      ];
      expect(every, hasLength(8));
      for (final app in every) {
        expect(app.roleOptions, {'start': '/fake_feature'}, reason: '$app');
        expect(
          app.createArguments('app_1', '/apps'),
          contains('--start=/fake_feature'),
          reason: '$app',
        );
      }
      // An app with one screen that can start it needs no answer.
      expect(
        apps
            .singleWhere((app) => app.name == 'fake_second (go_router)')
            .roleOptions,
        isEmpty,
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
          '--start',
          '/fake_feature',
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

    test(
        'stops an app with several screens that can start it without '
        '--start, since it cannot ask', () async {
      final logger = RecordingLogger();
      final host = testHost(processRunner: RecordingRunner(), logger: logger);

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
      );

      expect(code, SmfExitCodes.usage);
      expect(
        logger.errors,
        contains(
          'Several screens can start the app: /fake_feature, /fake_second. '
          'Choose one with --start.',
        ),
      );
      expect(
        host.fileSystem.directory('/work/fixture_app').existsSync(),
        isFalse,
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
              roleOptions: const {'start': '/fake_feature'},
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

/// The one of the two modules [both] that is not [one].
String _other(List<String> both, String one) =>
    both.singleWhere((module) => module != one);

/// The codes of the diagnostics that the import cleanup fixes.
const _importCodes = 'duplicate_import,unnecessary_import,unused_import';

/// The cases of the harness over the fixtures, each building another app,
/// so that a case that stops being built fails the test.
const _cases = [
  'flutter_core with router',
  'flutter_core',
  'fake_router with layout',
  'go_router with layout',
  'go_router',
  'fake_di',
  'get_it',
  'fake_bloc',
  'fake_riverpod',
  'fake_feature (fake_bloc, fake_di, fake_router)',
  'fake_feature (fake_bloc, fake_di, go_router)',
  'fake_feature (fake_bloc, get_it, fake_router)',
  'fake_feature (fake_bloc, get_it, go_router)',
  'fake_feature (fake_riverpod, fake_di, fake_router)',
  'fake_feature (fake_riverpod, fake_di, go_router)',
  'fake_feature (fake_riverpod, get_it, fake_router)',
  'fake_feature (fake_riverpod, get_it, go_router)',
  'fake_second (fake_router)',
  'fake_second (go_router)',
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
  'fake_registrations (fake_di)',
  'fake_registrations (get_it)',
  'fake_parent',
  'fake_child',
  'fake_codegen',
  'fake_clock_badge',
  'fake_clock_user with clock, badge',
  'fake_clock_user',
];

/// Collects the values of the named arguments `initialLocation`, in the
/// order of the code: that of `GoRouter`, then those of the branches.
final class _NamedArguments extends RecursiveAstVisitor<void> {
  final List<String> initialLocations = [];

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'initialLocation') {
      initialLocations.add((node.expression as StringLiteral).stringValue!);
    }
    super.visitNamedExpression(node);
  }
}
