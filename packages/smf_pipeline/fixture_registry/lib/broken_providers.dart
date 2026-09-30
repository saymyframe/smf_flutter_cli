/// The providers of roles with one known bug each, in the fixture package
/// `fake_broken`, and the apps that show that the tests of their roles fail
/// on each bug, and on nothing else; `tool/broken_providers_matrix.dart`
/// generates the apps and runs their tests.
///
/// A test of a role that passes whatever the provider of the role does
/// checks nothing. So each role whose contract the app tests of a matrix
/// check (`MatrixAppTests.testedRoles`) has a broken provider here, or an
/// exemption with its reason; the tests of this package check it. The
/// broken providers are in no registry of apps that must work
/// ([fixtureModules] and [severalProvidersModules]), so the matrices do not
/// grow with them.
library;

import 'package:fake_broken/fake_broken.dart';
import 'package:fake_di/fake_di.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_router/fake_router.dart';
import 'package:fake_state/fake_state.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// A provider of a role with one known bug, and the tests of the role that
/// must fail on it in its app.
final class BrokenProvider {
  /// Describes [module], which provides [role] with [bug]: in the app with
  /// [module] and the modules [app], the tests of [failures] must fail.
  const BrokenProvider(
    this.module, {
    required this.role,
    required this.bug,
    required this.app,
    required this.failures,
  });

  /// The module with the bug.
  final SmfModule module;

  /// The role that [module] provides with the bug.
  final Role role;

  /// What the bug is.
  final String bug;

  /// The other modules of the app but its app entry, in order: the fixture
  /// modules that its tests need, and no more, so that the app is small.
  /// Those are the modules that the tests of [failures] need, and those
  /// whose files the other tests that apply to the app import, such as the
  /// fixture providers of the analytics role and of the crash reporting
  /// role, which the tests of these roles look at in an app with either.
  final List<ModuleId> app;

  /// The tests of the role that must fail on the bug in the app, each with
  /// the reason of its first failure. Every other test of the app must
  /// pass.
  final List<MatrixExpectedFailure> failures;

  /// The fixture modules, with [module] in place of the other providers of
  /// [role]: the registry in which the contract harness checks [module]
  /// with every provider of each role that it requires or uses.
  List<SmfModule> get registry => [
        for (final other in fixtureModules())
          if (!other.descriptor.provides.contains(role)) other,
        module,
      ];

  /// The registry of the app: its app entry, [module] and the modules of
  /// [app], and then the other providers that these have variants for,
  /// which a registry must have, all from the registries of the fixtures
  /// ([fixtureModules]) and of several providers ([severalProvidersModules]),
  /// which has the service log of the fixtures.
  List<SmfModule> get modules {
    final fixtures = {
      for (final other in [...fixtureModules(), ...severalProvidersModules()])
        other.descriptor.id: other,
    };
    final ofApp = [
      for (final other in fixtureModules())
        if (other.descriptor.provides.contains(appEntryRole)) other,
      module,
      for (final id in app) fixtures[id]!,
    ];
    final ids = {for (final other in ofApp) other.descriptor.id};
    return [
      ...ofApp,
      for (final id in {
        for (final other in ofApp)
          ...?other.descriptor.variants?.byProvider.keys,
      })
        if (!ids.contains(id)) fixtures[id]!,
    ];
  }

  /// The app, named after [module]: of the apps with every module of
  /// [modules], the one with the modules of [app].
  MatrixFailingApp get failingApp => MatrixFailingApp(
        '${module.descriptor.id}',
        modules: modules,
        providers: app,
        failures: failures,
      );
}

/// The broken providers: for each role whose contract the app tests check,
/// providers that break it, each with one bug.
List<BrokenProvider> brokenProviders() => const [
      BrokenProvider(
        BrokenModule.routerRepeatingScreens,
        role: routerRole,
        bug: 'It tells the listeners of the screen of the page on top each '
            'time it builds its navigator, though the page on top did not '
            'change.',
        app: [
          FakeFeatureModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/router_screens_test.dart',
            'each screen the user sees is heard of once',
            'go() to the location on top is heard of at most once.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerStoppingAtThrowingListener,
        role: routerRole,
        bug: 'It calls the listeners of the screen one after another, so a '
            'listener that throws keeps the ones after it from hearing the '
            'screen.',
        app: [
          FakeFeatureModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
          FakeScreenLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/router_listeners_test.dart',
            'a listener of the screen that throws keeps no other from hearing '
                'it',
            'A listener of the screen that throws keeps no other from hearing '
                'it.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerPushingOverMainNavigation,
        role: routerRole,
        bug: 'It pushes a location in the main navigation over a page shown '
            'over the main navigation, rather than refusing it with a '
            'StateError.',
        app: [
          BottomTabsModule.id,
          FakeFeatureModule.id,
          FakeSecondModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
          FakeScreenLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/main_navigation_test.dart',
            'push() and replace() refuse a location in the main navigation '
                'over it',
            'push() of a location in the main navigation from a page over it '
                'throws a StateError.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerCreatingConfigAgain,
        role: routerRole,
        bug: 'It creates a new configuration each time appRouter.config is '
            'read.',
        app: [
          FakeFeatureModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/router_config_test.dart',
            'the router creates its configuration once',
            'The router creates its config once.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerShowingAnotherScreen,
        role: routerRole,
        bug: 'It shows the screen of the first destination of the main '
            'navigation in the page of each top-level route outside the main '
            'navigation, which it names after the route of the page.',
        app: [
          BottomTabsModule.id,
          FakeFeatureModule.id,
          FakeSecondModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/router_walk_test.dart',
            'each location that needs no values shows the page and the screen '
                'of its route',
            'Each location shows the screen of its route.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenLayoutModule(),
        role: layoutRole,
        bug: 'Its AppShell shows a tab for each destination, but gives only '
            'the first one to the code that reads its destinations.',
        app: [
          FakeRouterModule.id,
          FakeFeatureModule.id,
          FakeSecondModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
          FakeScreenLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/layout_screens_test.dart',
            'each switch to another destination is heard of once',
            'The AppShell has the destination of each feature.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.eventsOfEveryType,
        role: eventsRole,
        bug: 'Its on<T>() gives a listener the events of every type, cast to '
            'its type, rather than only the events of its type.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            'test/events_role_test.dart',
            'a listener of another type gets none of the events, and no error',
            'An event of another type does not reach the listener, not even '
                'as an error.',
          ),
        ],
      ),
    ];

/// The app tests that the apps of the broken providers get: those of the
/// apps of the fixture modules ([fixtureAppTests]) and those of the app of
/// several providers ([severalProvidersAppTests]), such as the tests of the
/// analytics role and of the crash reporting role, the tests of each
/// directory once. Both have some, such as the mocks of the fixture
/// providers and the tests of the DI role and of the events role, and those
/// of the apps of the fixtures come first.
Future<List<MatrixAppTest>> brokenProviderAppTests() async {
  final tests = <String, MatrixAppTest>{};
  for (final appTests in [
    await fixtureAppTests(),
    await severalProvidersAppTests(),
  ]) {
    for (final test in appTests.tests) {
      tests.putIfAbsent(test.directory, () => test);
    }
  }
  return [...tests.values];
}

/// The roles whose contract the app tests check but no broken provider
/// breaks, each with the reason.
const Map<Role, String> brokenProviderExemptions = {
  analyticsRole: 'Its broken provider comes in a following change.',
  crashReportingRole: 'Its broken provider comes in a following change.',
  diRole: 'Its broken provider comes in a following change.',
};
