import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fake_broken/fake_broken.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_router/fake_router.dart';
import 'package:fake_state/fake_state.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'host.dart';

void main() {
  test('the fixtures form a valid registry', () {
    expect(ModuleRegistry.problemsOf(fixtureModules()), isEmpty);
  });

  test(
      'has every module of the CLI that provides the router role or the '
      'layout role, so that the tests of the apps of the fixtures check the '
      'listeners of the screen with each', () {
    final fixtures = {
      for (final module in fixtureModules()) module.descriptor.id,
    };
    final providers = [
      for (final module in smfModules)
        if (module.descriptor.provides.any({routerRole, layoutRole}.contains))
          module.descriptor.id,
    ];

    expect(providers, isNotEmpty);
    for (final id in providers) {
      expect(
        fixtures,
        contains(id),
        reason: '$id provides the router role or the layout role: add it to '
            'fixtureModules().',
      );
    }
  });

  test(
      'the fixture of the registrations registers a service in each form '
      'that the DI role allows and a DI container renders, and with each '
      'capability of the role', () {
    final data = [
      for (final contribution in const FakeRegistrationsModule().contribute(
        ContractHarness.defaultContext,
      ))
        if (contribution case final RoleData<DiRegistration> data) data,
    ];
    final graph = DiGraph(data);
    final registrations = [for (final RoleData(:value) in data) value];

    expect(
      _allowedForms().difference({
        for (final registration in registrations)
          ..._formsOf(registration, graph),
      }),
      isEmpty,
      reason: 'fake_registrations renders every form of a registration: '
          'register a service of each form it misses.',
    );
    expect(
      registrations.expand(graph.capabilitiesOf).toSet(),
      containsAll(DiCapability.values),
    );
  });

  group('the registry of several providers', () {
    test('is a valid registry', () {
      expect(ModuleRegistry.problemsOf(severalProvidersModules()), isEmpty);
    });

    test(
        'has every module of the CLI that provides a role that an app can '
        'have several providers of, and a fixture provider of each such role '
        'besides, so that the app tests of the modules run next to another '
        'provider of their roles', () {
      final modules = severalProvidersModules();
      final ids = {for (final module in modules) module.descriptor.id};
      final ofCli = {for (final module in smfModules) module.descriptor.id};
      final roles = <Role>{};
      for (final module in smfModules) {
        for (final role in module.descriptor.provides) {
          if (!role.cardinality.allowsMany) continue;
          roles.add(role);
          expect(
            ids,
            contains(module.descriptor.id),
            reason: '${module.descriptor.id} provides the $role, which an app '
                'can have several providers of: add it to '
                'severalProvidersModules(); the app of several providers runs '
                'its app tests as smfAppTests() registers them.',
          );
        }
      }

      expect(roles, isNotEmpty);
      for (final role in roles) {
        expect(
          [
            for (final module in modules)
              if (module.descriptor.provides.contains(role) &&
                  !ofCli.contains(module.descriptor.id))
                module.descriptor.id,
          ],
          isNotEmpty,
          reason: 'No fixture provides the $role next to the modules of the '
              'CLI that do.',
        );
      }
    });

    test(
        'has the service log of the fixtures, which the tests of the '
        'analytics role and of the crash reporting role look at, and a '
        'fixture provider of each of those roles that starts later', () {
      final modules = {
        for (final module in severalProvidersModules())
          module.descriptor.id: module,
      };
      for (final (role, later) in [
        (analyticsRole, FakeAnalyticsModule.id),
        (crashReportingRole, FakeCrashModule.id),
      ]) {
        // The implementations created with the app come first among those
        // of the role, and those that start asynchronously after them, so a
        // call that the service log throws on must still reach the fixture
        // that starts later, which the tests look at too.
        expect(
          _implementationOf(modules[FakeServiceLogModule.id], role)?.isAsync,
          isFalse,
          reason: 'The tests of the $role look at what reaches '
              'fake_service_log: add it to severalProvidersModules(), with an '
              'implementation of the role created with the app.',
        );
        expect(
          _implementationOf(modules[later], role)?.isAsync,
          isTrue,
          reason: 'The tests of the $role look at what reaches $later after '
              'fake_service_log: add it to severalProvidersModules(), with an '
              'implementation of the role that starts asynchronously.',
        );
      }
    });

    test('builds one app with every module, whose cases have no errors',
        () async {
      final (:apps, :failed) = await everyModuleAppsOf(
        severalProvidersModules(),
      );

      expect(failed, isEmpty);
      expect(apps.map((app) => app.modules), [
        unorderedEquals([
          for (final module in severalProvidersModules()) module.descriptor.id,
        ]),
      ]);
    });

    test(
        'has contributors of settings entries next to the settings module of '
        'the CLI, two of them with a widget of one name, so that the tests of '
        'the settings screen role check a screen with entries on a provider '
        'that must work', () async {
      final (:apps, :failed) = await everyModuleAppsOf(
        severalProvidersModules(),
      );

      expect(failed, isEmpty);
      final hook = apps.single.hook!;
      expect(hook.presentRoles, contains(settingsScreenRole));
      final entries = settingsScreenRole.entriesIn(
        settingsScreenRole.hookInput(hook),
      );
      expect(
        entries.length,
        greaterThan(1),
        reason: 'With fewer than two entries, the tests of the settings '
            'screen role show neither their order nor that the list scrolls '
            'to the last one: add modules with a setting to '
            'severalProvidersModules().',
      );
      final files = <String, Set<String?>>{};
      for (final entry in entries) {
        files.putIfAbsent(entry.widget.name, () => {}).add(entry.file);
      }
      expect(
        files.values.where((paths) => paths.length > 1),
        isNotEmpty,
        reason: 'With two widgets of one name in different files, the app '
            'analyzes only if the screen imports the file of each entry with '
            'a prefix of its own.',
      );
    });
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
        'checks each fixture with every provider of each role it requires or '
        'uses', () async {
      expect(
        await ContractHarness(
          ModuleRegistry(fixtureModules()),
        ).uncheckedProviders(),
        isEmpty,
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
      expect(pubspec.usesMaterialDesign, isTrue);
      expect(result.collection!.applyingOf<CodegenRequest>(), hasLength(1));
      // The analytics of the fixtures watches the navigators of the router
      // and listens to the screen the user sees, and so does the screen log
      // of the fixtures, so the router has two listeners.
      for (final (socket, contributors) in [
        (RouterRole.observers, ['fake_analytics']),
        (RouterRole.screenListeners, ['fake_analytics', 'fake_screen_log']),
      ]) {
        expect(
          result.validation!.socketOrders[socket]!.contributions
              .map((collected) => '${collected.origin}'),
          contributors,
          reason: '$socket',
        );
      }
    });

    test('with Riverpod', () async {
      final result = await checked(
        everyFixture(stateManager: FakeRiverpodModule.id),
      );

      expect(
        result
            .validation!.socketOrders[AppEntryRole.rootWrappers]!.contributions
            .map((collected) => '${collected.origin}'),
        // The fixture of the theme puts the colour of its themes around the
        // root, the template of the localization role the language that the
        // user chose, and that of the theme role the theme mode that the
        // user selected.
        [
          'fake_riverpod',
          'fake_sockets',
          'fake_theme',
          'role:localization',
          'role:theme',
        ],
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
      // The two modules and the template of the localization role each
      // give the root the delegate of the texts of the Material widgets.
      expect(
        'GlobalMaterialLocalizations.delegate'.allMatches(
          rendered(result, AppEntryRole.appArgs).values.single,
        ),
        hasLength(1),
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
      // The notes for coding agents of both modules make one section of the
      // guide, with the note that both have once.
      final guide = rendered(result, AppEntryRole.agentSections).values.single;
      expect('## Fixture'.allMatches(guide), hasLength(1));
      expect(
        'The modules of the fixture fill the sockets'.allMatches(guide),
        hasLength(1),
      );
      expect(
        guide,
        contains('the sockets got.\n\nThe assets of the fixture are in '),
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

    test('gives go_router the observer and the screen listener of analytics',
        () async {
      final result = await harness.check(
        ContractCase('tabs', requested: modules),
      );
      final router = result.app!.files[RouterRole.appRouterFactoryFile]!.text;

      expect(result.errors.map((issue) => '$issue'), isEmpty);
      expect(router, contains('() => FixtureObserver(),'));
      expect(router, contains('noteFixtureScreen,'));
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
          if (app.everyModuleWith != null) app,
      ];
      // Each combination of a router, a DI container and a state manager,
      // named after the providers other than the first of their roles:
      // fake_router, fake_di and fake_bloc.
      expect(every.map((app) => app.name), [
        for (final router in ['fake_router', 'go_router'])
          for (final container in ['fake_di', 'get_it'])
            for (final stateManager in ['fake_bloc', 'fake_riverpod'])
              'every module ($router, $container, $stateManager)',
      ]);
      expect(every.map((app) => app.packageName('app')), [
        'app',
        'app_fake_riverpod',
        'app_get_it',
        'app_get_it_fake_riverpod',
        'app_go_router',
        'app_go_router_fake_riverpod',
        'app_go_router_get_it',
        'app_go_router_get_it_fake_riverpod',
      ]);
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

  group('the fixture router', () {
    final harness = ContractHarness(ModuleRegistry(fixtureModules()));

    /// The top-level declarations of the router of the app of [modules],
    /// by name.
    Future<Map<String, Declaration>> routerOf(List<ModuleId> modules) async {
      final result = await harness.check(
        ContractCase('fixture router', requested: modules),
      );
      expect(result.errors.map((issue) => '$issue'), isEmpty);
      final unit = parseString(
        content: result.app!.files[RouterRole.appRouterFactoryFile]!.text,
      ).unit;
      return {
        for (final declaration in unit.declarations)
          if (declaration case FunctionDeclaration(:final name))
            name.lexeme: declaration
          else if (declaration
              case TopLevelVariableDeclaration(:final variables))
            for (final variable in variables.variables)
              variable.name.lexeme: declaration,
      };
    }

    /// The locations that the branches of the main navigation of [router]
    /// start on, and the code of its layout around the navigator of the
    /// selected branch.
    (List<String>, String) mainNavigationOf(Map<String, Declaration> router) {
      final destinations =
          router['_destinations']! as TopLevelVariableDeclaration;
      final shell = router['_shell']! as FunctionDeclaration;
      return (
        [
          for (final element in (destinations
                  .variables.variables.single.initializer! as ListLiteral)
              .elements)
            element.toSource(),
        ],
        (shell.functionExpression.body as ExpressionFunctionBody)
            .expression
            .toSource(),
      );
    }

    test(
        'with bottom tabs, builds the main navigation of the layout, with the '
        'destinations of the features in their order', () async {
      final router = await routerOf([
        ...everyFixture(),
        const ModuleId('bottom_tabs'),
      ]);

      final (locations, shell) = mainNavigationOf(router);
      expect(locations, [
        'FakeFeatureHomeLocation()',
        'FakeSecondSecondLocation()',
      ]);
      expect(
        shell,
        [
          'AppShell(destinations: const [',
          "Destination(label: 'Fixture', icon: Icons.star), ",
          "Destination(label: 'Second', icon: Icons.looks_two)], ",
          'currentIndex: index, onSelect: onSelect, body: body)',
        ].join(),
      );
    });

    test('without a layout or without destinations, has no main navigation',
        () async {
      for (final modules in [
        everyFixture(),
        const [FakeRouterModule.id, ModuleId('bottom_tabs')],
      ]) {
        final (locations, shell) = mainNavigationOf(await routerOf(modules));
        expect(locations, isEmpty, reason: '$modules');
        expect(shell, 'body', reason: '$modules');
      }
    });

    test(
        'asks the guards of the routes in an app whose modules declare '
        'some, and names nothing of them in an app without guards, which '
        'does not have what the role generates for them', () async {
      /// The names that the code of the router of the app of [modules]
      /// uses.
      Future<Set<String>> namesIn(List<ModuleId> modules) async {
        final result = await harness.check(
          ContractCase('fixture router', requested: modules),
        );
        expect(result.errors.map((issue) => '$issue'), isEmpty);
        final names = _Names();
        parseString(
          content: result.app!.files[RouterRole.appRouterFactoryFile]!.text,
        ).unit.accept(names);
        return names.names;
      }

      const ofGuards = {
        RouterRole.guardedNavigation,
        RouterRole.guardChanges,
      };

      // The fixture gates are among the fixtures, and have two guards.
      expect(await namesIn(everyFixture()), containsAll(ofGuards));
      expect(
        (await namesIn(const [FakeRouterModule.id, ModuleId('fake_second')]))
            .intersection(ofGuards),
        isEmpty,
      );
    });

    test(
        'has the guards of the routes in the guide for coding agents of an '
        'app with guards, in a note of the router role after its other '
        'note, and nothing of them in the guide of an app without guards',
        () async {
      /// Whether each note of the router role in the guide of the app of
      /// [modules] tells of the guards, in the order the guide has the
      /// notes.
      Future<List<bool>> tellsOfGuards(List<ModuleId> modules) async {
        final result = await harness.check(
          ContractCase('fixture router', requested: modules),
        );
        // No rule fails, such as the one of the paths that the guide names.
        expect(result.errors.map((issue) => '$issue'), isEmpty);
        final notes = [
          for (final (origin, heading, note)
              in result.app!.entriesOf(AppEntryRole.agentSections))
            if (origin == const RoleTemplateOrigin(routerRole)) (heading, note),
        ];
        for (final (heading, note) in notes) {
          expect(heading, routerRole.description);
          expect(note.isOfRole, isTrue);
        }
        return [
          for (final (_, note) in notes)
            note.text.contains('`${RouterRole.routeGuards}`'),
        ];
      }

      // The fixture gates depend on one of the two fixture state managers.
      expect(await tellsOfGuards(everyFixture()), [false, true]);
      expect(
        await tellsOfGuards(everyFixture(stateManager: FakeRiverpodModule.id)),
        [false],
      );
    });
  });

  group('the fixtures with a setting', () {
    const second = 'lib/features/fake_second/fixture_second_setting.dart';
    const screenLog =
        'lib/core/fixture_screen_log/fixture_screen_log_setting.dart';

    test(
        'give the settings screen role an entry each, in the order of the '
        'modules, and generate its widget, of the same name in a file of '
        'its own, in an app with a settings screen', () async {
      // No fixture provides the settings screen role in an app that must
      // work, so the app has the provider with a known bug.
      final result = await ContractHarness(
        ModuleRegistry([...fixtureModules(), const BrokenSettingsModule()]),
      ).check(
        const ContractCase(
          'fixtures with a setting',
          requested: [
            FakeSecondModule.id,
            FakeScreenLogModule.id,
            BrokenSettingsModule.id,
            FakeRouterModule.id,
          ],
        ),
      );

      expect(result.errors.map((issue) => '$issue'), isEmpty);
      // The two widgets have one name, so that an app with both analyzes
      // only if the screen imports the file of each with a prefix of its
      // own, whichever module provides the screen.
      expect(
        [
          for (final entry in settingsScreenRole
              .entriesIn(settingsScreenRole.hookInput(result.hook!)))
            '${entry.widget.name} of ${entry.file}',
        ],
        ['FixtureSetting of $second', 'FixtureSetting of $screenLog'],
      );
      expect(
        {
          for (final path in [second, screenLog])
            path: result.app!.files[path]?.owner,
        },
        {
          second: const ModuleOrigin(FakeSecondModule.id),
          screenLog: const ModuleOrigin(FakeScreenLogModule.id),
        },
      );
    });

    test('generate no widget of a setting in an app without a settings screen',
        () async {
      final result = await ContractHarness(
        ModuleRegistry(fixtureModules()),
      ).check(ContractCase('every fixture', requested: everyFixture()));

      expect(result.errors.map((issue) => '$issue'), isEmpty);
      expect(
        result.resolution!.modules.map((module) => module.id),
        containsAll([FakeSecondModule.id, FakeScreenLogModule.id]),
      );
      expect(result.app!.files.keys, isNot(contains(second)));
      expect(result.app!.files.keys, isNot(contains(screenLog)));
    });
  });

  group('the texts of the fixtures', () {
    final harness = ContractHarness(ModuleRegistry(fixtureModules()));
    const withRole = [
      FakeSecondModule.id,
      FakeRouterModule.id,
      FakeL10nModule.id,
    ];
    const screen = 'lib/features/fake_second/fixture_second_screen.dart';
    const outside = 'lib/features/fake_second/fixture_outside_screen.dart';

    Future<ContractResult> checked(
      List<ModuleId> modules, {
      Map<String, String> options = const {},
    }) async {
      final result = await harness.check(
        ContractCase('texts', requested: modules, roleOptions: options),
      );
      expect(result.errors.map((issue) => '$issue'), isEmpty);
      return result;
    }

    /// The file at [path] of the app of [result], parsed.
    CompilationUnit unitOf(ContractResult result, String path) =>
        parseString(content: result.app!.files[path]!.text).unit;

    /// What the getter [name] of the texts of the app of [result] returns
    /// in each of [languages], as the code of the provider says: a text, or
    /// a switch over the language of the texts.
    Map<String, String> textsOf(
      ContractResult result,
      String name,
      List<String> languages,
    ) {
      final texts = unitOf(result, LocalizationRole.textsFile)
          .declarations
          .whereType<ClassDeclaration>()
          .singleWhere(
            (declaration) =>
                declaration.namePart.typeName.lexeme == 'FixtureTexts',
          );
      final getter =
          texts.body.members.whereType<MethodDeclaration>().singleWhere(
                (member) => member.isGetter && member.name.lexeme == name,
              );
      final returned = (getter.body as ExpressionFunctionBody).expression;
      if (returned is StringLiteral) {
        final text = returned.stringValue!;
        return {for (final language in languages) language: text};
      }
      final cases = (returned as SwitchExpression).cases;
      expect(cases.first.guardedPattern.pattern, isA<ConstantPattern>());
      expect(cases.last.guardedPattern.pattern, isA<WildcardPattern>());
      final byLanguage = {
        for (final switchCase in cases)
          if (switchCase.guardedPattern.pattern
              case ConstantPattern(:final StringLiteral expression))
            expression.stringValue!:
                (switchCase.expression as StringLiteral).stringValue!,
      };
      final english = (cases.last.expression as StringLiteral).stringValue!;
      return {
        for (final language in languages)
          language: byLanguage[language] ?? english,
      };
    }

    /// The code of the text that the screen at [path] of the app of
    /// [result] shows, and whether the file imports the texts of the app.
    (String, {bool importsTexts}) shownBy(ContractResult result, String path) {
      final unit = unitOf(result, path);
      final finder = _TextArguments();
      unit.accept(finder);
      final texts = LocalizationRole.appTexts.importRef
          .resolveUri(ContractHarness.defaultContext.appName);
      return (
        finder.arguments.single,
        importsTexts: unit.directives
            .whereType<ImportDirective>()
            .any((directive) => directive.uri.stringValue == texts),
      );
    }

    test('reach the localization role with the languages they are in',
        () async {
      final result = await checked(withRole);
      final input = localizationRole.hookInput(result.hook!);

      expect(
        [
          for (final text in localizationRole.textsIn(input))
            '${text.getter}: $text',
        ],
        [
          'fakeSecondTitle: text title of the module fake_second',
          'fakeSecondOutside: text outside of the module fake_second',
        ],
      );
      // The app is in no language in which Flutter has no texts for its
      // own widgets, such as the Maltese of the title.
      expect(
        localizationRole.textsIn(input).first.text.languages,
        ['en', 'uk', 'mt'],
      );
      expect(localizationRole.localesIn(input), ['en', 'uk']);
      expect(result.answers, isEmpty);
    });

    test(
        'are getters of the fixture provider, each with its translations '
        'into the languages of the app and its English text for the others',
        () async {
      final result = await checked(withRole);

      expect(textsOf(result, 'fakeSecondTitle', ['en', 'uk', 'de', 'mt']), {
        'en': 'Second screen',
        'uk': 'Другий екран',
        'de': 'Second screen',
        // The translation into a language that no app can be in is left
        // out.
        'mt': 'Second screen',
      });
      // A text without a translation reads in English in every language;
      // the code of its text escapes the quote.
      expect(textsOf(result, 'fakeSecondOutside', ['en', 'uk']), {
        'en': "Outside the app's main navigation",
        'uk': "Outside the app's main navigation",
      });
    });

    test('are in the languages of --locales only', () async {
      final result = await checked(withRole, options: const {'locales': 'en'});

      expect(
        localizationRole.localesIn(localizationRole.hookInput(result.hook!)),
        ['en'],
      );
      expect(textsOf(result, 'fakeSecondTitle', ['en', 'uk']), {
        'en': 'Second screen',
        'uk': 'Second screen',
      });
    });

    test('are read through the role by the screens of their feature', () async {
      final result = await checked(withRole);

      expect(
        shownBy(result, screen),
        ('context.l10n.fakeSecondTitle', importsTexts: true),
      );
      expect(
        shownBy(result, outside),
        ('context.l10n.fakeSecondOutside', importsTexts: true),
      );
    });

    test('are English literals of the screens in an app without the role',
        () async {
      final result = await checked(const [
        FakeSecondModule.id,
        FakeRouterModule.id,
      ]);

      expect(result.hook!.presentRoles, isNot(contains(localizationRole)));
      expect(
        shownBy(result, screen),
        ("'Second screen'", importsTexts: false),
      );
      expect(
        shownBy(result, outside),
        (r"'Outside the app\'s main navigation'", importsTexts: false),
      );
      expect(
        result.app!.files.keys,
        isNot(contains(LocalizationRole.appLocaleFile)),
      );
    });

    test(
        'are read through the role by the setting of the second feature too, '
        'whose text only an app with a settings screen has', () async {
      const setting = 'lib/features/fake_second/fixture_second_setting.dart';
      // No fixture provides the settings screen role in an app that must
      // work, so the apps have the provider with a known bug.
      final withSettings = ContractHarness(
        ModuleRegistry([...fixtureModules(), const BrokenSettingsModule()]),
      );
      Future<ContractResult> checkedWithSettings(List<ModuleId> modules) async {
        final result = await withSettings.check(
          ContractCase('a setting with a text', requested: modules),
        );
        expect(result.errors.map((issue) => '$issue'), isEmpty);
        return result;
      }

      List<String> gettersOf(ContractResult result) => [
            for (final text in localizationRole
                .textsIn(localizationRole.hookInput(result.hook!)))
              text.getter,
          ];

      final localized = await checkedWithSettings(
        [...withRole, BrokenSettingsModule.id],
      );
      expect(
        gettersOf(localized),
        ['fakeSecondTitle', 'fakeSecondOutside', 'fakeSecondSetting'],
      );
      expect(textsOf(localized, 'fakeSecondSetting', ['en', 'uk']), {
        'en': 'Second setting',
        'uk': 'Друге налаштування',
      });
      expect(
        shownBy(localized, setting),
        ('context.l10n.fakeSecondSetting', importsTexts: true),
      );

      // Without the localization role, the setting shows its English text.
      final english = await checkedWithSettings(const [
        FakeSecondModule.id,
        FakeRouterModule.id,
        BrokenSettingsModule.id,
      ]);
      expect(
        shownBy(english, setting),
        ("'Second setting'", importsTexts: false),
      );

      // Without a settings screen, the app has neither the widget of the
      // setting nor its text.
      final without = await checked(withRole);
      expect(without.app!.files.keys, isNot(contains(setting)));
      expect(gettersOf(without), ['fakeSecondTitle', 'fakeSecondOutside']);
    });

    test('give the root of the app its language and the delegate of the texts',
        () async {
      final result = await checked(withRole);
      String rendered(SocketRef socket) => socket
          .render([
            for (final collected
                in result.app!.socketOrders[socket]!.contributions)
              collected.contribution as SocketContribution,
          ])
          .values
          .join('|');

      expect(
        rendered(AppEntryRole.appArgs).split('\n'),
        [
          'locale: AppLocaleScope.of(context),',
          'localizationsDelegates: [${[
            'FixtureTexts.delegate',
            'GlobalMaterialLocalizations.delegate',
            'GlobalWidgetsLocalizations.delegate',
            'GlobalCupertinoLocalizations.delegate',
          ].join(', ')}],',
          'supportedLocales: [...appLocales],',
        ],
      );
      expect(
        rendered(AppEntryRole.rootWrappers),
        'AppLocaleScope(notifier: appLocale, child: |)',
      );
      final plist = rendered(AppEntryRole.infoPlist);
      expect(plist, contains('<key>CFBundleLocalizations</key>'));
      expect(plist, contains('<string>en</string>'));
      expect(plist, contains('<string>uk</string>'));
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
        'warns of a language of a text that no app can be in, and of a text '
        'without a translation into a language of the app', () async {
      final logger = RecordingLogger();
      final host = testHost(processRunner: RecordingRunner(), logger: logger);

      final code = await runSmf(
        [
          'create',
          'fixture_app',
          '-m',
          [FakeSecondModule.id, FakeRouterModule.id, FakeL10nModule.id]
              .join(','),
          '--no-input',
          '--skip-external-setup',
          '--strict',
        ],
        modules: fixtureModules(),
        hostFor: ({required verbose}) => host,
      );

      expect(code, SmfExitCodes.success, reason: logger.errors.join('\n'));
      expect(logger.warnings, hasLength(2));
      expect(
        logger.warnings.first,
        'The app is not in mt, which the text title of the module '
        'fake_second has a translation into: Flutter has no texts for its '
        'own widgets in that language.',
      );
      expect(
        logger.warnings.last,
        'No translation into uk of the text outside of the module '
        'fake_second: the app shows it in English there.',
      );
      expect(
        host.fileSystem
            .file('/work/fixture_app/${LocalizationRole.appLocaleFile}')
            .readAsStringSync(),
        contains("const appLocales = <Locale>[Locale('en'), Locale('uk')];"),
      );
    });

    test('refuses in --locales a language that no app can be in', () async {
      final logger = RecordingLogger();
      final host = testHost(processRunner: RecordingRunner(), logger: logger);

      final code = await runSmf(
        [
          'create',
          'fixture_app',
          '-m',
          [FakeSecondModule.id, FakeRouterModule.id, FakeL10nModule.id]
              .join(','),
          '--locales',
          'en,mt',
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
          'The app cannot be in mt, which --locales names: Flutter has no '
          'texts for its own widgets in such a language. The app can be in '
          'en, uk.',
        ),
      );
      expect(
        host.fileSystem.directory('/work/fixture_app').existsSync(),
        isFalse,
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

/// The implementation of [role] that [module] contributes, or `null` if
/// there is no [module] or it contributes none.
RoleImplementation? _implementationOf(SmfModule? module, Role role) {
  if (module == null) return null;
  for (final contribution
      in module.contribute(ContractHarness.defaultContext)) {
    if (contribution
        case RoleData<RoleImplementation>(role: final of, :final value)
        when identical(of, role)) {
      return value;
    }
  }
  return null;
}

/// The forms in which a DI container renders [registration] of [graph]: its
/// kind with or without a name, how it waits for other services, and
/// whether a function disposes of it. The kind is the lifetime, and for a
/// singleton also whether it is created asynchronously or waits for other
/// services.
Set<String> _formsOf(DiRegistration registration, DiGraph graph) {
  final lifetime = registration.lifetime.name;
  final waits = graph.dependsOnOf(registration);
  final kind = registration.isAsync
      ? 'asynchronous $lifetime'
      : waits.isEmpty
          ? lifetime
          : '$lifetime that waits';
  return {
    '$kind ${registration.instanceName == null ? 'without' : 'with'} a name',
    if (registration.dependsOn.isNotEmpty) '$lifetime that waits by saying so',
    if (waits.any(registration.create.deps.contains))
      '$lifetime that waits for a service it takes',
    if (registration.dispose != null) '$kind with a dispose function',
  };
}

/// The forms of [_formsOf] that the DI role allows: each kind that
/// [DiRegistration.problems] accepts, with and without a name, both ways
/// of waiting for a kind that waits, and a function that disposes of a
/// kind that accepts one.
Set<String> _allowedForms() {
  const file = ImportRef.app('probe.dart');
  bool allows(
    DiLifetime lifetime, {
    required bool isAsync,
    required bool waits,
    bool disposes = false,
  }) =>
      DiRegistration(
        type: const TypeRef('Probe', import: file),
        create: const FactoryRef('createProbe', import: file),
        lifetime: lifetime,
        isAsync: isAsync,
        dependsOn: [
          if (waits) const ServiceRef(TypeRef('Other', import: file)),
        ],
        dispose:
            disposes ? const FunctionRef('closeProbe', import: file) : null,
      ).problems().isEmpty;

  return {
    for (final lifetime in DiLifetime.values)
      for (final (kind, isAsync, waits) in [
        (lifetime.name, false, false),
        ('asynchronous ${lifetime.name}', true, false),
        ('${lifetime.name} that waits', false, true),
      ])
        if (allows(lifetime, isAsync: isAsync, waits: waits)) ...{
          '$kind with a name',
          '$kind without a name',
          if (waits) ...{'$kind by saying so', '$kind for a service it takes'},
          if (allows(lifetime, isAsync: isAsync, waits: waits, disposes: true))
            '$kind with a dispose function',
        },
  };
}

/// The codes of the diagnostics that the import cleanup fixes.
const _importCodes = 'duplicate_import,unnecessary_import,unused_import';

/// The cases of the harness over the fixtures, each building another app,
/// so that a case that stops being built fails the test.
const _cases = [
  'flutter_core (fake_router) with router',
  'flutter_core (go_router) with router',
  'flutter_core',
  'fake_router with layout',
  'go_router with layout',
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
  'fake_second (fake_router) with localization',
  'fake_second (go_router) with localization',
  'fake_second (fake_router)',
  'fake_second (go_router)',
  'fake_gate (fake_router)',
  'fake_gate (go_router)',
  'fake_sockets',
  'fake_overlap',
  'fake_l10n',
  'fake_analytics (fake_di, fake_router) with di, router',
  'fake_analytics (fake_di, go_router) with di, router',
  'fake_analytics (get_it, fake_router) with di, router',
  'fake_analytics (get_it, go_router) with di, router',
  'fake_analytics (fake_di) with di',
  'fake_analytics (get_it) with di',
  'fake_analytics (fake_router) with router',
  'fake_analytics (go_router) with router',
  'fake_analytics',
  'fake_screen_log (fake_router)',
  'fake_screen_log (go_router)',
  'fake_crash (fake_di) with di',
  'fake_crash (get_it) with di',
  'fake_crash',
  'fake_events (fake_di) with di',
  'fake_events (get_it) with di',
  'fake_events',
  'fake_preferences (fake_di) with di',
  'fake_preferences (get_it) with di',
  'fake_preferences',
  'fake_preferences_user with preferences',
  'fake_preferences_user',
  'fake_theme with localization',
  'fake_theme',
  'fake_registrations (fake_di)',
  'fake_registrations (get_it)',
  'fake_parent',
  'fake_child',
  'fake_codegen',
  'fake_clock_badge',
  'fake_clock_user with clock, badge',
  'fake_clock_user',
];

/// Collects the code of the first argument of each `Text(...)`.
final class _TextArguments extends RecursiveAstVisitor<void> {
  final List<String> arguments = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'Text') {
      arguments.add(node.argumentList.arguments.first.toSource());
    }
    super.visitMethodInvocation(node);
  }
}

/// Collects the names that a file uses: its simple identifiers.
final class _Names extends RecursiveAstVisitor<void> {
  final Set<String> names = {};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

/// Collects the values of the named arguments `initialLocation`, in the
/// order of the code: that of `GoRouter`, then those of the branches.
final class _NamedArguments extends RecursiveAstVisitor<void> {
  final List<String> initialLocations = [];

  @override
  void visitNamedArgument(NamedArgument node) {
    if (node.name.lexeme == 'initialLocation') {
      initialLocations
          .add((node.argumentExpression as StringLiteral).stringValue!);
    }
    super.visitNamedArgument(node);
  }
}
