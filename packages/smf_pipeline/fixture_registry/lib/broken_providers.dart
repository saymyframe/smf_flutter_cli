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

  /// The other modules of the app, in order: the fixture modules that the
  /// tests of [failures] need, and no more, so that the app is small.
  final List<ModuleId> app;

  /// The tests of the role that must fail on the bug in the app, each with
  /// the reason of its first failure. Every other test of the app must
  /// pass.
  final List<MatrixExpectedFailure> failures;

  /// The registry of the app: the fixture modules, with [module] in place
  /// of the other providers of [role].
  List<SmfModule> get modules => [
        for (final other in fixtureModules())
          if (!other.descriptor.provides.contains(role)) other,
        module,
      ];

  /// The app, named after [module], whose tests of [failures] must fail.
  MatrixFailingApp get failingApp => MatrixFailingApp(
        '${module.descriptor.id}',
        modules: modules,
        requested: [module.descriptor.id, ...app],
        failures: failures,
      );
}

/// The broken providers: for each role whose contract the app tests check,
/// providers that break it, each with one bug.
List<BrokenProvider> brokenProviders() => const [
      BrokenProvider(
        BrokenRouterModule.repeatsScreens,
        role: routerRole,
        bug: 'It tells the listeners of the screen of the page on top each '
            'time it builds its navigator, though the page on top did not '
            'change.',
        app: [
          FakeFeatureModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
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
        BrokenRouterModule.pushesOverMainNavigation,
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
        BrokenRouterModule.createsConfigAgain,
        role: routerRole,
        bug: 'It creates a new configuration each time appRouter.config is '
            'read.',
        app: [
          FakeFeatureModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
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
    ];

/// The roles whose contract the app tests check but no broken provider
/// breaks, each with the reason.
const Map<Role, String> brokenProviderExemptions = {
  analyticsRole: 'Its broken provider comes in a following change.',
  crashReportingRole: 'Its broken provider comes in a following change.',
  diRole: 'Its broken provider comes in a following change.',
};
