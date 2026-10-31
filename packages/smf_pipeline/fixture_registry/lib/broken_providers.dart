/// The providers of roles with one known bug each, those of the fixture
/// package `fake_broken` and the app entry that this library makes of
/// flutter_core, and the apps that show that the tests of their roles fail
/// on each bug, and on nothing else; `tool/broken_providers_matrix.dart`
/// generates the apps and runs their tests.
///
/// A test of a role that passes whatever the provider of the role does
/// checks nothing. So each role whose contract the app tests of a matrix
/// check (`MatrixAppTests.testedRoles`) has a broken provider here, or an
/// exemption with its reason; the tests of this package check it. The
/// broken providers are in no registry of apps that must work
/// ([fixtureModules] and [severalProvidersModules]), so the matrices do not
/// grow with them. An expectation that the app tests have of every module,
/// rather than of a role, has an app that must fail it in
/// [brokenModuleApps].
library;

import 'package:fake_broken/fake_broken.dart';
import 'package:fake_di/fake_di.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_roles/fake_roles.dart';
import 'package:fake_router/fake_router.dart';
import 'package:fake_state/fake_state.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_launcher_icons/smf_launcher_icons.dart';
import 'package:smf_native_splash/smf_native_splash.dart';
import 'package:smf_settings/smf_settings.dart';

/// The app entry that builds its root once: flutter_core, the app entry of
/// the fixtures, whose `App` keeps the `MaterialApp` that its `build`
/// created first and returns it each time it builds again. So the arguments
/// of the root are read once, and the root does not follow an inherited
/// widget that they read from its context, such as the theme mode that the
/// user selects.
///
/// The root is still created in a `build` with the context of `App`, as
/// the rule `app_entry.root_in_build` of the role wants, and the app
/// analyzes: only a running app shows the bug.
///
/// No fixture provides the app entry, so the broken one changes the module
/// of the CLI. It is made here, in the package that depends on that module,
/// and not in `fake_broken`, whose fixtures depend on no module of the CLI.
/// Each of its two changes takes a text of one line of the template of the
/// root, so that a line of the template that is wrapped anew still has it.
const _appEntryBuildingRootOnce = BrokenModule(
  FlutterCoreModule(),
  id: ModuleId('broken_app_entry_builds_root_once'),
  description: 'Flutter app whose root is built once (fixture)',
  file: 'lib/app.dart',
  changes: [
    (
      '  const App({super.key});',
      '  const App({super.key});\n'
          '\n'
          '  /// The root that it built first.\n'
          '  static Widget? _root;',
    ),
    (
      'Widget build(BuildContext context) =>',
      'Widget build(BuildContext context) => _root ??=',
    ),
  ],
);

/// The app icon whose image for the App Store has alpha: launcher_icons, the
/// provider of the app icon role of the CLI, with the foreground as the image
/// of the icon and without what takes the alpha away. So the tool only warns,
/// and the step of the module succeeds.
///
/// No fixture provides the role, since a fixture would have to write every
/// density and icon set by hand, and only its test would read them. So the
/// broken one changes the module of the CLI, here for the reason that the app
/// entry above is.
const _appIconWithAlpha = BrokenModule(
  LauncherIconsModule(),
  id: ModuleId('broken_app_icon_with_alpha'),
  description: 'App icon with alpha on iOS (fixture)',
  file: 'flutter_launcher_icons.yaml',
  changes: [
    (
      'image_path: "${AppIconRole.imageFile}"',
      'image_path: "${AppIconRole.foregroundFile}"',
    ),
    ('remove_alpha_ios: true', 'remove_alpha_ios: false'),
  ],
);

/// The app entry whose line `default-flavor` of the pubspec names the flavor
/// for a release: flutter_core, the app entry of the fixtures, with
/// [_releaseAsDefaultFlavor]. So a command without `--flavor`, such as
/// `flutter run` on the phone of a developer, builds the app of the users,
/// under its id.
///
/// The line names a flavor of the role, and the app builds and has every
/// flavor in its native projects: only a run of the `flutter` tool shows what
/// such a command builds. It is made here for the reason that the app entry
/// above is.
const _appEntryDefaultingToRelease = BrokenModule.contributing(
  FlutterCoreModule(),
  id: ModuleId('broken_app_entry_defaults_to_release'),
  description: 'Flutter app whose default flavor is that of a release '
      '(fixture)',
  contributions: _releaseAsDefaultFlavor,
);

/// [contributions] with [AppEntryRole.releaseFlavor] as the default flavor of
/// the `flutter:` section of the pubspec.
List<Contribution> _releaseAsDefaultFlavor(List<Contribution> contributions) =>
    [
      for (final contribution in contributions)
        if (contribution
            case PubspecFlutter(
              :final assets,
              :final fonts,
              :final generate,
              :final usesMaterialDesign,
              when: final roles,
            ))
          PubspecContribution.flutter(
            assets: assets,
            fonts: fonts,
            generate: generate,
            usesMaterialDesign: usesMaterialDesign,
            defaultFlavor: AppEntryRole.releaseFlavor.name,
            when: roles,
          )
        else
          contribution,
    ];

/// The router of go_router whose redirect asks the guards of the routes
/// within the calls of the router too: it reads the counter of those calls
/// the wrong way round. The router of a fixture has no redirect that runs
/// for its own navigation, so this broken router changes the module of the
/// CLI, and is made here as the broken app entry is.
const _goRouterAskingWithinItsCalls = BrokenModule(
  GoRouterModule(),
  id: ModuleId('broken_go_router_asks_within_its_calls'),
  description: 'go_router whose redirect asks about its own calls (fixture)',
  file: RouterRole.appRouterFactoryFile,
  changes: [
    ('    if (_asking > 0) return null;', '    if (_asking < 0) return null;'),
  ],
);

/// The splash screen whose configuration sets `android_min_sdk` to the lowest
/// version of Android that the apps run on: native_splash with that one line.
/// flutter_native_splash then writes `drawable/launch_background.xml` alone,
/// and leaves `drawable-v21/launch_background.xml` as the app entry has it,
/// without an image. That file wins on Android below 12, so the screen there
/// has no image, though the app builds and every other file of the screen is
/// made: only the files that the step leaves show the bug.
///
/// No fixture provides the splash role, since its files come from a tool that
/// only the module knows, so the broken one changes the module of the CLI. It
/// is made here for the reason that the app entry above is.
const _splashWithAndroidMinSdk = BrokenModule(
  NativeSplashModule(),
  id: ModuleId('broken_splash_sets_android_min_sdk'),
  description: 'A splash screen that Android below 12 shows blank (fixture)',
  file: 'flutter_native_splash.yaml',
  changes: [
    (
      'flutter_native_splash:\n',
      'flutter_native_splash:\n  android_min_sdk: 24\n',
    ),
  ],
);

/// A provider of a role with one known bug, and the tests of the role that
/// must fail on it in its app.
final class BrokenProvider {
  /// Describes [module], which provides [role] with [bug]: in the app with
  /// [module] and the modules [app], generated with [roleOptions], the tests
  /// of [failures] must fail.
  const BrokenProvider(
    this.module, {
    required this.role,
    required this.bug,
    required this.app,
    required this.failures,
    this.roleOptions = const {},
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
  /// The app entry of the app is that of the fixtures, or [module] itself
  /// if it provides the app entry.
  final List<ModuleId> app;

  /// The tests of the role that must fail on the bug in the app, each with
  /// the reason of its first failure. Every other test of the app must
  /// pass.
  final List<MatrixExpectedFailure> failures;

  /// The values of role options by name that the app is generated with:
  /// another value of a mode option of a role (see [RoleOption.mode]), for
  /// a bug that the tests of the role show in full only in an app with that
  /// value. None by default, so that each role chooses as it does for an
  /// app that got no option.
  final Map<String, String?> roleOptions;

  /// The fixture modules, with [module] in place of the other providers of
  /// [role]: the registry in which the contract harness checks [module]
  /// with every provider of each role that it requires or uses.
  List<SmfModule> get registry => [
        for (final other in fixtureModules())
          if (!other.descriptor.provides.contains(role)) other,
        module,
      ];

  /// The registry of the app: its app entry, that of the fixtures unless
  /// [module] provides the app entry itself, [module] and the modules of
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
      if (!module.descriptor.provides.contains(appEntryRole))
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
  /// [modules], the one with the modules of [app], generated with the
  /// [roleOptions].
  MatrixFailingApp get failingApp => MatrixFailingApp(
        '${module.descriptor.id}',
        modules: modules,
        providers: app,
        roleOptions: roleOptions,
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
            _walkTest,
            'Each location shows the screen of its route, or the screen that '
                'the app starts on if it is in a flow that is over.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerAskingGuardsOnlyAtStart,
        role: routerRole,
        bug: 'It asks the guards of the routes about the screen that the app '
            'starts on, and again when one of them changes, but not about the '
            'locations that go(), push() and replace() are asked to show. So '
            'it shows a location that a guard keeps the user from, and one in '
            'a flow that is over.',
        app: _appWithGates,
        failures: [
          MatrixExpectedFailure(
            'test/router_guards_test.dart',
            'a guard that does not allow shows its target in place of every '
                'location outside its flow',
            'go() to a location that a guard keeps the user from shows the '
                'target of the guard.',
          ),
          MatrixExpectedFailure(
            'test/router_guard_order_test.dart',
            'the first guard that does not allow shows its target, and the '
                'next one once it allows',
            'While a guard does not allow, the target of a guard after it is '
                'a route like any other.',
          ),
          MatrixExpectedFailure(
            'test/router_guard_flow_test.dart',
            _flowTest,
            'go() to a location in a flow that is over shows the screen that '
                'the app starts on.',
          ),
          // A location that is asked for while a guard that does not bring
          // the user back does not allow.
          MatrixExpectedFailure(
            'test/router_guard_return_test.dart',
            _returnTest,
            'go() to a location that a guard keeps the user from shows the '
                'target of the guard.',
          ),
          MatrixExpectedFailure(
            'test/router_walk_guards_test.dart',
            _walkGuardsTest,
            'While a guard does not allow, each location outside its flow '
                'shows the target of the guard, and each location of its flow '
                'its own screen.',
          ),
          // With guards that allow, the walk goes to the routes of their
          // flows too, which are over.
          MatrixExpectedFailure(
            'test/router_walk_test.dart',
            _walkTest,
            'The page on top of the innermost navigator on the screen is '
                'named after the route of each location, or after the route '
                'that the app starts on for a location in a flow that is over.',
          ),
          // A route that asks for a condition that does not hold is a
          // location that a guard keeps the user from too.
          MatrixExpectedFailure(
            'test/router_flow_opens_test.dart',
            _flowOpensTest,
            _flowOpensOnce,
          ),
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            _pushOpensFlow,
          ),
          MatrixExpectedFailure(
            'test/router_condition_flow_test.dart',
            _conditionFlowTest,
            _pushOpensFlow,
          ),
          MatrixExpectedFailure(
            'test/router_condition_two_test.dart',
            _conditionTwoTest,
            _firstOfTwoOpens,
          ),
          MatrixExpectedFailure(
            'test/router_condition_gates_test.dart',
            _conditionGatesTest,
            'While a gate does not allow, go() to a route that asks for no '
                'condition shows the target of the gate.',
          ),
          MatrixExpectedFailure(
            'test/router_condition_early_test.dart',
            _conditionEarlyTest,
            _earlyRequestOpensFlow,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerIgnoringGuardChanges,
        role: routerRole,
        bug: 'It tells the guards of the routes of its pages when one of '
            'them starts or stops allowing, and does not show the location '
            'that they answer.',
        app: _appWithGates,
        failures: [
          MatrixExpectedFailure(
            'test/router_guards_test.dart',
            'a guard that does not allow shows its target in place of every '
                'location outside its flow',
            'Once the guards allow, the router shows the latest location '
                'that was asked for and that a guard kept the user from, with '
                'its query.',
          ),
          MatrixExpectedFailure(
            'test/router_guard_changes_test.dart',
            'a guard that stops allowing shows its target, and the location '
                'below the pushed pages once it allows again',
            'When a guard stops allowing, the router shows its target in '
                'place of the pages that it keeps the user from.',
          ),
          MatrixExpectedFailure(
            'test/router_guard_order_test.dart',
            'the first guard that does not allow shows its target, and the '
                'next one once it allows',
            'Once a guard allows, the next one that does not allow shows its '
                'target.',
          ),
          MatrixExpectedFailure(
            'test/router_guard_flow_test.dart',
            _flowTest,
            'When a guard starts allowing while a page of its flow is on '
                'top, the router leaves the flow: it shows the screen that '
                'the app starts on.',
          ),
          // What the guards answer for a guard that does not bring the user
          // back is an answer like any other: the router does not show it.
          MatrixExpectedFailure(
            'test/router_guard_return_test.dart',
            _returnTest,
            'Once a guard allows, a guard of a later stage that does not '
                'allow shows its target.',
          ),
          MatrixExpectedFailure(
            'test/router_guard_early_change_test.dart',
            'a guard that starts allowing before the router shows its first '
                'location lets the app start on the location that it is '
                'opened with',
            'With guards that allow when the app starts, the app starts on '
                'the location that it is opened with: the one from the '
                'platform, or its start screen for a router that takes no '
                'location from the platform.',
          ),
          // The pages of a flow that the guards answer to close are an
          // answer like any other: the router does not close them, so it
          // never makes the request that waits again.
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            _requestShows,
          ),
          MatrixExpectedFailure(
            'test/router_condition_flow_test.dart',
            _conditionFlowTest,
            _firstRequestMade,
          ),
          MatrixExpectedFailure(
            'test/router_condition_two_test.dart',
            _conditionTwoTest,
            _nextOfTwoOpens,
          ),
          MatrixExpectedFailure(
            'test/router_condition_gates_test.dart',
            _conditionGatesTest,
            'Once the gate and the condition allow, the router shows the '
                'latest location that was asked for.',
          ),
          // Nor does it close a page that asks for a condition that stops
          // holding.
          MatrixExpectedFailure(
            'test/router_condition_stops_test.dart',
            _conditionStopsTest,
            _pushedPageLeaves,
          ),
          MatrixExpectedFailure(
            'test/router_condition_early_test.dart',
            _conditionEarlyTest,
            _earlyRequestOpensNext,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerKeepingPageOnGuardedReplace,
        role: routerRole,
        bug: 'Its replace() asks the guards of the routes, and leaves the '
            'stack as it is when they answer another location, rather than '
            'showing that location in its place: the target of the guard '
            'that keeps the user from the location, or the screen that the '
            'app starts on for a location in a flow that is over.',
        app: _appWithGates,
        failures: [
          MatrixExpectedFailure(
            'test/router_guards_test.dart',
            'a guard that does not allow shows its target in place of every '
                'location outside its flow',
            'replace() with a location that a guard keeps the user from '
                'shows the target of the guard alone, from a page of its flow '
                'too.',
          ),
          MatrixExpectedFailure(
            'test/router_guard_flow_test.dart',
            _flowTest,
            'replace() with a location in a flow that is over shows the '
                'screen that the app starts on.',
          ),
          // Nor does it open the flow of a guard of a condition for a route
          // that asks for it. The other tests of such a guard, but that of
          // two conditions, replace no page with such a route while the
          // flow is closed, so they pass.
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            'replace() with a route that asks for a condition that does not '
                'hold opens the target of the guard of the condition.',
          ),
          MatrixExpectedFailure(
            'test/router_condition_two_test.dart',
            _conditionTwoTest,
            'A request for a route that asks for a condition that does not '
                'hold opens the target of its guard.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerNamingPushedPagesAfterPageBelow,
        role: routerRole,
        bug: 'It tells the guards of the routes of a page that a push showed '
            'under the route of the location below the pushed pages, not '
            'under its own. A gate keeps the user from both, so only a guard '
            'that stands for a condition tells: when the condition stops '
            'holding, a pushed page that asks for it stays over a page that '
            'asks for nothing. And the router does not find the target of '
            'such a guard among its pages, so it drops the request that '
            'opened the flow at once, and opens the flow a second time.',
        app: _appWithGates,
        failures: [
          MatrixExpectedFailure(
            'test/router_condition_stops_test.dart',
            _conditionStopsTest,
            _pushedPageLeaves,
          ),
          // The target that it pushed is no page of the flow to it, so the
          // request does not wait.
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            _pushWaits,
          ),
          MatrixExpectedFailure(
            'test/router_condition_flow_test.dart',
            _conditionFlowTest,
            _pushWaits,
          ),
          // And when the condition holds, the guards find no page of the
          // flow among the pages that it tells of, so the flow stays.
          MatrixExpectedFailure(
            'test/router_condition_two_test.dart',
            _conditionTwoTest,
            _nextOfTwoOpens,
          ),
          // The walk asks for a route of the condition from the target,
          // which opens over itself.
          MatrixExpectedFailure(
            'test/router_walk_guards_test.dart',
            _walkGuardsTest,
            _walkOfCondition,
          ),
          MatrixExpectedFailure(
            'test/router_condition_early_test.dart',
            _conditionEarlyTest,
            _earlyRequestOpensNext,
          ),
          // Nor does it find the target of a gate among its pages when that
          // target was pushed, so it drops the request that waits for the
          // flow of the target.
          MatrixExpectedFailure(
            'test/router_condition_gates_test.dart',
            _conditionGatesTest,
            _requestWaitsBehindGate,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerAskingAboutTopLevelRoute,
        role: routerRole,
        bug: 'It asks the guards of the routes about a location that go(), '
            'push() or replace() is asked to show by the name of the '
            'top-level route of the location, not by that of its own route. '
            'A gate answers the same for both, so only a guard that stands '
            'for a condition tells: a route that asks for the condition '
            'below a route that asks for nothing shows to everyone.',
        app: _appWithGates,
        failures: [
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            'push() of a route that asks for a condition that does not hold, '
                'below a route that asks for none, opens the target of the '
                'guard of the condition.',
          ),
          // It shows that route while the flow is open too.
          MatrixExpectedFailure(
            'test/router_condition_flow_test.dart',
            _conditionFlowTest,
            'While the flow of a guard of a condition is open, a further '
                'request for a route that asks for the condition shows '
                'nothing.',
          ),
          // And for a route that asks for one more condition than the route
          // above it, only the guard of the condition of that route answers.
          MatrixExpectedFailure(
            'test/router_condition_two_test.dart',
            _conditionTwoTest,
            _firstOfTwoOpens,
          ),
          // The walk goes to that route while the condition does not hold.
          MatrixExpectedFailure(
            'test/router_walk_guards_test.dart',
            _walkGuardsTest,
            _walkOfCondition,
          ),
          MatrixExpectedFailure(
            'test/router_condition_early_test.dart',
            _conditionEarlyTest,
            _earlyRequestOpensFlow,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerShowingFlowInPlace,
        role: routerRole,
        bug: 'It shows the target of a guard that stands for a condition in '
            'place of its whole stack, as the target of a gate, where the '
            'guards answer to show it over the page on top, and keeps no '
            'request waiting. So the user cannot go back to the page that '
            'they were on, and the location that was asked for does not '
            'show once the condition holds.',
        // The app of the guards with a layout, so that the test of the
        // requests from the main navigation applies too. The fixture
        // feature comes first, so the app starts on its screen.
        app: [BottomTabsModule.id, ..._appWithGates],
        failures: [
          MatrixExpectedFailure(
            'test/router_flow_opens_test.dart',
            _flowOpensTest,
            _flowOpensOverPage,
          ),
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            'The target opens over the page that the user is on, and the '
                'pages below it stay.',
          ),
          MatrixExpectedFailure(
            'test/router_condition_flow_test.dart',
            _conditionFlowTest,
            'The target of a guard of a condition opens over the page that '
                'the user is on.',
          ),
          MatrixExpectedFailure(
            'test/router_condition_two_test.dart',
            _conditionTwoTest,
            'The target of a guard of a condition opens over the page that '
                'the user is on.',
          ),
          MatrixExpectedFailure(
            'test/layout_condition_test.dart',
            _conditionLayoutTest,
            'The target of a guard of a condition opens over the main '
                'navigation, which stays below it.',
          ),
          // It keeps no request waiting, so none waits either when the gate
          // of the flow stops allowing meanwhile. And the page that the flow
          // was opened over is gone, so that gate has no location to bring
          // the user back to.
          MatrixExpectedFailure(
            'test/router_condition_gates_test.dart',
            _conditionGatesTest,
            _requestWaitsBehindGate,
          ),
          MatrixExpectedFailure(
            'test/router_condition_early_test.dart',
            _conditionEarlyTest,
            _earlyRequestOpensFlow,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerForgettingWaitingRequest,
        role: routerRole,
        bug: 'It opens the target of a guard that stands for a condition '
            'over the page on top and keeps the request waiting, but drops '
            'the request when the guards close the pages of the flow, '
            'rather than making it again. So once the condition holds, the '
            'user is back on the page that the flow was opened over, and '
            'the location that was asked for does not show.',
        app: _appWithGates,
        failures: [
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            _requestShows,
          ),
          MatrixExpectedFailure(
            'test/router_condition_flow_test.dart',
            _conditionFlowTest,
            _firstRequestMade,
          ),
          MatrixExpectedFailure(
            'test/router_condition_two_test.dart',
            _conditionTwoTest,
            _nextOfTwoOpens,
          ),
          MatrixExpectedFailure(
            'test/router_condition_early_test.dart',
            _conditionEarlyTest,
            _earlyRequestOpensNext,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerKeepingSelectedBranch,
        role: routerRole,
        bug: 'When it shows the location that the guards of the routes '
            'answer, it puts the branches of the main navigation back on '
            'their destinations, but for the selected one, which keeps its '
            'pages. So once a guard that does not bring the user back allows '
            'again, that branch still has a page that the guard kept the '
            'user from.',
        // The app of the guards with a layout and the second fixture
        // feature, whose destination is the branch that is selected when
        // the guard stops allowing. The fixture feature comes first, so the
        // app starts on its screen.
        app: [
          BottomTabsModule.id,
          FakeFeatureModule.id,
          FakeSecondModule.id,
          FakeLateGateModule.id,
          FakeGateModule.id,
          FakeClockBadgeModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/layout_guard_return_test.dart',
            'after a guard that does not bring the user back, the user is in '
                'the main navigation on the screen that the app starts on, '
                'and every branch is back on its destination',
            'The target of a guard takes the stacks of every branch of the '
                'main navigation, the selected one too: when the user does '
                'not come back to that branch, it is back on its destination '
                'all the same.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerKeepingBranchesForAFrame,
        role: routerRole,
        bug: 'When it shows the location that the guards of the routes '
            'answer, it leaves the pages of the branches of the main '
            'navigation where they are, and takes them when it next builds '
            'its pages without the main navigation. So when a guard stops '
            'allowing and allows again in one turn, as when one user signs '
            'out and the next one in, no frame shows the target of the '
            'guard, and a branch that the user does not come back to still '
            'has a page that the guard kept the user from.',
        // The app of the guards with a layout and the second fixture
        // feature, whose destination has the branch that the user does not
        // come back to. The fixture feature comes first, so the app starts
        // on its screen.
        app: [
          BottomTabsModule.id,
          FakeFeatureModule.id,
          FakeSecondModule.id,
          FakeLateGateModule.id,
          FakeGateModule.id,
          FakeClockBadgeModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/layout_guards_test.dart',
            'the user comes back into the main navigation, to the '
                'destination that a pushed page was opened from',
            'A guard stopped allowing and allowed again in one turn. The '
                'target of the guard took the stacks of every branch of the '
                'main navigation all the same: a branch that was not '
                'selected is back on its destination.',
          ),
          MatrixExpectedFailure(
            'test/layout_guard_return_test.dart',
            'after a guard that does not bring the user back, the user is in '
                'the main navigation on the screen that the app starts on, '
                'and every branch is back on its destination',
            'The target of the guard took the stacks of every branch of the '
                'main navigation all the same: the other branch is back on '
                'its destination when the user selects it.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerKeepingNavigatorsOfBranches,
        role: routerRole,
        bug: 'When the main navigation leaves its stack, as when the '
            'location that the guards of the routes answer takes its place '
            'or go() shows a page outside it, the branches keep their '
            'navigators. The page of the main navigation that left stays in '
            'the tree until the transition to the page that took its place '
            'is over. So a main navigation that comes back before that has '
            'the keys of those navigators in the tree a second time, and '
            'Flutter throws.',
        // The app of the guards with a layout and the second fixture
        // feature, so that the main navigation has two branches, and with
        // the fixture screen log, which the tests of the main navigation
        // need. The fixture feature comes first, so the app starts on its
        // screen.
        app: [
          BottomTabsModule.id,
          FakeFeatureModule.id,
          FakeSecondModule.id,
          FakeLateGateModule.id,
          FakeGateModule.id,
          FakeClockBadgeModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeScreenLogModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/layout_guard_return_test.dart',
            'after a guard that does not bring the user back, the user is in '
                'the main navigation on the screen that the app starts on, '
                'and every branch is back on its destination',
            'A guard that allows again while the transition to its target '
                'is on its way leaves the router with one main navigation, '
                'which it shows without an error.',
          ),
          MatrixExpectedFailure(
            'test/main_navigation_return_test.dart',
            'go() out of the main navigation and back shows the destination '
                'without an error, in one turn and while the transition is '
                'on its way',
            'go() back into the main navigation while the transition to the '
                'page that took its place is on its way leaves the router '
                'with one main navigation, which it shows without an error.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerThrowingWithNoRouteToClose,
        role: routerRole,
        bug: 'It throws a StateError when the back button of the system has '
            'no route to close, as on the first page of the app, rather than '
            'leaving the button to the system.',
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
            'The back button of the system throws nothing on the page that '
                'the router stayed on.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.routerDroppingRoutesWithoutPage,
        role: routerRole,
        bug: 'It pops the routes without a page from its root navigator '
            'whenever the guards of the routes answer nothing to a '
            'notification, so the screen that the action of an onboarding '
            'step shows over the onboarding goes away when a guard notifies, '
            'though no page changed.',
        // The fixture gates with their badge, whose guards the test of the
        // onboarding screen role has notify, the fixture onboarding, which
        // provides that role, and the fixture steps, whose step ask shows
        // the screen.
        app: [
          FakeGateModule.id,
          FakeClockBadgeModule.id,
          FakeBlocModule.id,
          FakeOnboardingModule.id,
          FakeStepsModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/onboarding_screen_role/step_actions_test.dart',
            'the action of a step runs once, with the context of the screen, '
                'takes no tap until its future completes and then shows the '
                'next page, also when it fails, a screen that it shows stays '
                'while the guards notify, and later shows the next page '
                'without it',
            'A route without a page that the action of a step pushes on the '
                'navigator at the root of the app stays on top while the '
                'guards of the routes notify, also when a guard of a condition '
                'stops and starts allowing.',
          ),
        ],
      ),
      BrokenProvider(
        _goRouterAskingWithinItsCalls,
        role: routerRole,
        bug: 'Its redirect asks the guards of the routes about the locations '
            'that the router hands go_router itself too, with no pages, as '
            'for a link. So when the router pushes the target of a guard '
            'that stands for a condition, the guards answer to open that '
            'target over the screen that the app starts on, and again for '
            'that push, without end, which the router refuses with a '
            'StateError.',
        // The two fixture features and the fixture gates with their badge,
        // for a route that asks for a condition and its guard, without the
        // late gate, so that the other tests of the guards and of the
        // conditions, each of which this router fails too, are not among
        // the tests of the app.
        app: [
          FakeFeatureModule.id,
          FakeSecondModule.id,
          FakeGateModule.id,
          FakeClockBadgeModule.id,
          FakeBlocModule.id,
          FakeDiModule.id,
          FakeAnalyticsModule.id,
          FakeCrashModule.id,
          FakeServiceLogModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/router_flow_opens_test.dart',
            _flowOpensTest,
            _routerThrowsNothing,
          ),
        ],
      ),
      BrokenProvider(
        BrokenLayoutModule.givingFirstDestination(),
        role: layoutRole,
        bug: 'Its AppShell shows a tab for each destination, but gives only '
            'the first one to the code that reads its destinations.',
        app: _appWithMainNavigation,
        failures: [
          MatrixExpectedFailure(
            'test/layout_screens_test.dart',
            'each switch to another destination is heard of once',
            'The AppShell has the destination of each feature.',
          ),
          // The test of the labels reads them from the destinations of the
          // shell too.
          MatrixExpectedFailure(
            'test/destination_labels_test.dart',
            _labelsTest,
            'While the app follows a device in English, each destination '
                'gives its label in English.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenLayoutModule.keepingLabels(),
        role: layoutRole,
        bug: 'Its AppShell reads the label of each destination when it is '
            'first built and keeps it, so its tabs show the labels in the '
            'language of before once the app is in another language.',
        // The fixture texts, with the preferences that their role requires,
        // so that the app has two languages, and the second fixture
        // feature, whose label has a translation.
        app: [
          ..._appWithMainNavigation,
          FakeL10nModule.id,
          FakePreferencesModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/destination_labels_test.dart',
            _labelsTest,
            'The layout shows no label of a destination in a language that '
                'the app is not in.',
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
      BrokenProvider(
        BrokenModule.preferencesForgettingWrites,
        role: preferencesRole,
        bug: 'Its writes never reach its disk, so the next start of the app '
            'reads nothing of what was saved.',
        // The fixture setting and the fixture theme, whose role remembers
        // the theme mode in the preferences: the next start has neither.
        app: [FakePreferencesUserModule.id, FakeThemeModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/preferences_role_test.dart',
            'the next start reads what was saved, and nothing that was '
                'removed',
            'The next start reads what was saved.',
          ),
          MatrixExpectedFailure(
            'test/preferences_restorers_test.dart',
            'a restorer reads at the next start what its module saved',
            'Each restorer reads at the next start what was saved.',
          ),
          MatrixExpectedFailure(
            'test/theme_role/theme_mode_remembered_test.dart',
            'the next start of the app has the mode that is saved under the '
                'key of the role',
            'The next start restores the mode whose name is saved under the '
                'key of the role.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.preferencesNeverCopyingLists,
        role: preferencesRole,
        bug: 'It never copies a list: it keeps the list that it is given, and '
            'a read returns the list that it keeps. So a later change of the '
            'list that was saved, or of one that was read, changes what it '
            'reads.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            'test/preferences_role_test.dart',
            'the preferences keep a copy of a list that they are given',
            'A change of a list that was saved changes nothing that the '
                'preferences have.',
          ),
          MatrixExpectedFailure(
            'test/preferences_role_test.dart',
            'a read returns a copy of the list that the preferences have',
            'A change of a list that was read changes nothing that the '
                'preferences have.',
          ),
          // The probe of the role, which the start check runs on a device,
          // has the checks of the lists too.
          MatrixExpectedFailure(
            'test/preferences_role_test.dart',
            'the probe of the role finds no problem',
            'The probe finds no problem with preferences that keep the '
                'contract of the role in one run of the app.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.preferencesCastingValues,
        role: preferencesRole,
        bug: 'Its reads cast the value of a key to the type they ask for, so '
            'a read of a key with a value of another type throws a TypeError '
            'rather than returning null.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            'test/preferences_role_test.dart',
            'a read of a key with a value of another type returns null, and '
                'does not throw',
            'A read returns null when the key has no value of the type it '
                'asks for, and never throws.',
          ),
          // A value saved over one of another type is read by the type that
          // the key had too, which then throws.
          MatrixExpectedFailure(
            'test/preferences_role_test.dart',
            'a write replaces what its key had, a value of another type too',
            'A key has one value: a write replaces what the key had, '
                'whatever its type.',
          ),
          MatrixExpectedFailure(
            'test/preferences_role_test.dart',
            'the probe of the role finds no problem',
            'The probe finds no problem with preferences that keep the '
                'contract of the role in one run of the app.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.textsDelegateForEnglishOnly,
        role: localizationRole,
        bug: 'The delegate of its texts supports English only, whatever the '
            'languages of the app: in another language of the app, the root '
            'loads no texts of the app.',
        app: [
          FakeRouterModule.id,
          FakeSecondModule.id,
          FakePreferencesModule.id,
        ],
        failures: [
          // A test that puts the app into another language checks first
          // that its root can be in each language of the app.
          MatrixExpectedFailure(
            'test/localization_role/languages_test.dart',
            _languagesTest,
            _eachLanguageSupported,
          ),
          MatrixExpectedFailure(
            'test/localization_role/device_test.dart',
            _deviceTest,
            _eachLanguageSupported,
          ),
          MatrixExpectedFailure(
            'test/localization_role/saved_language_test.dart',
            'a choice of the user is saved under the key of the role, '
                'removed when the app follows the device again, and restored '
                'by the next start',
            _eachLanguageSupported,
          ),
          // The probe of the role, which the start check runs on a device,
          // has the check of the delegates too: the test fails with the
          // problem that the probe finds.
          MatrixExpectedFailure(
            'test/localization_role/probe_test.dart',
            _probeTest,
            'No delegate of FixtureTexts of the root of the app supports '
                'uk.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.textsInFirstLanguage,
        role: localizationRole,
        bug: 'Its texts are always in the first language of the app, '
            'whatever language the root of the app is in.',
        // A settings screen, which gets the setting of the language, and a
        // feature with a text in two languages.
        app: [
          FakeRouterModule.id,
          FakeSecondModule.id,
          FakePreferencesModule.id,
          SettingsModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/language_setting/language_setting_test.dart',
            'the setting of the language shows the choice of the user, and '
                'its sheet chooses a language of the app or the languages '
                'of the device',
            'The setting shows its texts in the language that the user '
                'chose.',
          ),
          // On a device in the last language of the app, the texts of the
          // setting stay in the first one before the user chose anything.
          MatrixExpectedFailure(
            'test/language_setting/language_setting_device_test.dart',
            'on a device in the last language of the app, the setting of '
                'the language follows the device, names a choice that code '
                'makes, shows the language that the next start restores, '
                'and has no option but those of the app and of the device',
            'While the app follows the device, the setting shows its texts '
                'in the language of the device.',
          ),
          // The root can be in each language, so the tests of the role get
          // to the texts, which do not follow it.
          MatrixExpectedFailure(
            'test/localization_role/languages_test.dart',
            _languagesTest,
            'The app and its texts follow the language that the user chose: '
                'a text reads in it, or in English when it has no '
                'translation into it.',
          ),
          MatrixExpectedFailure(
            'test/localization_role/device_test.dart',
            _deviceTest,
            'While the app follows the device, each text of the app reads '
                'in the language that the app is in.',
          ),
          // The probe finds the first text of the app that has a
          // translation, in the language of that translation.
          MatrixExpectedFailure(
            'test/localization_role/probe_test.dart',
            _probeTest,
            'The text title of the module fake_second reads "Second screen" '
                'in uk rather than "Другий екран".',
          ),
          // The title of the settings screen is a text of the module of
          // the screen, so its own test finds it in the first language
          // once the app is in the second.
          MatrixExpectedFailure(
            'test/settings_language_test.dart',
            'the title of the settings screen is in the language of the app',
            'The title of the screen is in the language of the app, uk.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenDiModule(),
        role: diRole,
        bug: 'It registers every service but one, the last in the order of '
            'the registrations without a function to dispose of it, which it '
            'registers only in a condition that is false when the app runs.',
        app: [FakeRegistrationsModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/di_role/di_role_test.dart',
            'the services resolve once the app started, none once the '
                'container is reset, and all once they are registered again',
            'FixtureReplica does not resolve: Bad state: FixtureReplica is '
                'not registered.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenSettingsModule(),
        role: settingsScreenRole,
        bug: 'Its screen creates the widget of every entry of the role, but '
            'shows them all but the last one.',
        // A feature and a module without screens, each with a setting, and
        // the fixture theme, with the preferences that its role requires:
        // the entry of the theme mode, which the template of the theme role
        // contributes, comes after those of the modules, so it is the one
        // that the screen leaves out. The app has no provider of the
        // localization role, whose template would add the setting of the
        // language after it.
        app: [
          FakeRouterModule.id,
          FakeSecondModule.id,
          FakeScreenLogModule.id,
          FakeThemeModule.id,
          FakePreferencesModule.id,
        ],
        failures: [
          MatrixExpectedFailure(
            'test/settings_screen_role/settings_entries_test.dart',
            'the settings screen shows every entry of the modules once, one '
                'below the other in the order of the role',
            'Every entry of the modules is on the settings screen once.',
          ),
          MatrixExpectedFailure(
            'test/theme_setting/theme_setting_test.dart',
            'the settings screen shows the entry of the theme mode, which '
                'shows the mode of the app and chooses the mode that the '
                'user taps',
            'The settings screen shows the entry of the theme mode once.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenOnboardingModule(),
        role: onboardingScreenRole,
        bug: 'Its screen shows a page for each step of the onboarding, also '
            'for a step whose showIf would leave it out, which it never '
            'asks.',
        // A router, which the role requires, and the fixture steps, whose
        // step ask has a showIf that the test of its conditions makes leave
        // it out.
        app: [FakeRouterModule.id, FakeStepsModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/onboarding_screen_role/step_conditions_test.dart',
            'a step whose showIf leaves it out when the onboarding opens is '
                'not shown, and a step that shows stays once its showIf would '
                'leave it out',
            'A step whose condition does not hold when the onboarding starts '
                'is not shown.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.themeWithLightDarkTheme,
        role: themeRole,
        bug: 'Its createDarkTheme() returns a light theme, the one that its '
            'createLightTheme() returns, so the app is light in the dark '
            'mode.',
        // The preferences, which the theme role requires.
        app: [FakePreferencesModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/theme_role/theme_mode_test.dart',
            'the app shows the mode that is chosen: its root takes the mode, '
                'and the screen below it gets the light or the dark theme of '
                'the app',
            'In the dark mode, the theme of the app is dark.',
          ),
        ],
      ),
      BrokenProvider(
        _appEntryBuildingRootOnce,
        role: appEntryRole,
        bug: 'Its App keeps the MaterialApp that it built first and returns '
            'it each time it builds again, so the root does not follow an '
            'inherited widget that its arguments read from its context.',
        // A provider of the theme role, whose mode the arguments of the root
        // read from its context, and the preferences that the role requires.
        app: [FakeThemeModule.id, FakePreferencesModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/theme_role/theme_mode_test.dart',
            'the app shows the mode that is chosen: its root takes the mode, '
                'and the screen below it gets the light or the dark theme of '
                'the app',
            'The root of the app rebuilds when the mode that its arguments '
                'read from its context changes, and takes the mode that was '
                'chosen.',
          ),
          // The themes of the fixture theme read its colour from the
          // context of the root too.
          MatrixExpectedFailure(
            'test/theme_look_test.dart',
            'the screens get the themes of the colour that the fixture '
                'theme keeps, and those of another colour once it changes',
            'The root of the app rebuilds in the new colours when the widget '
                'that its themes read the colour from notifies.',
          ),
        ],
      ),
      BrokenProvider(
        _appIconWithAlpha,
        role: appIconRole,
        bug: 'Its icon for the App Store is made from the logo on a '
            'transparent background and keeps the alpha, which the App Store '
            'refuses.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            _appIconTests,
            'on iOS the icon for the App Store has no alpha',
            'The App Store refuses an icon with alpha',
          ),
          MatrixExpectedFailure(
            _appIconTests,
            'on iOS the icon for the App Store has the pixels of the source',
            'is made from the image of the role',
          ),
        ],
      ),
      BrokenProvider(
        _appEntryDefaultingToRelease,
        role: appEntryRole,
        bug: 'The line default-flavor of its pubspec names the flavor for a '
            'release, so a command without --flavor builds the app of the '
            'users, under its id.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            _flavorTests,
            'a command without --flavor builds the default flavor of the app',
            'A command without --flavor builds the default flavor of the app '
                'that the app entry role names.',
          ),
          MatrixExpectedFailure(
            _flavorTests,
            'the probe of the flavor finds no problem',
            'The app has the flavor that its build asked for.',
          ),
        ],
      ),
      BrokenProvider(
        _splashWithAndroidMinSdk,
        role: splashRole,
        bug: 'Its configuration sets android_min_sdk, so the tool leaves the '
            'launch background that Android below 12 reads without an image.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            'test/splash_role/splash_role_test.dart',
            'below Android 12, the window background of the activity has an '
                'image in each mode, at each version of the system',
            'The launch background that the system shows below Android 12 '
                'has an image, in each mode and at each version of the system.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.authRestoringUserLate,
        role: authRole,
        bug: 'Its function returns the service before it has read who is '
            'signed in on the device: the service has nobody at first and '
            'tells of that user a moment later, so a start of the app is '
            'over without its user.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            _nextStartTests,
            'the next start of the app has the account that was signed in, '
            'as soon as it is over',
            _knownAtStart,
          ),
          MatrixExpectedFailure(
            _nextStartTests,
            'the next start of the app has the anonymous user who was signed '
            'in, in every mode',
            _knownAtStart,
          ),
          // The start after a link has nobody either.
          MatrixExpectedFailure(
            _nextStartTests,
            _leftOnDeviceTest,
            _linkKeptOnDevice,
          ),
          // The test expects the account right after the start, before it
          // deletes it.
          MatrixExpectedFailure(
            _nextStartTests,
            'the account of a user whom a start found on the device can be '
            'deleted, at the latest once the user has signed in again',
            _knownAtStart,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.authLinkingAsNewUser,
        role: authRole,
        bug: 'Its linkPassword() creates a new user for the account, rather '
            'than giving the account to the anonymous user who is signed in: '
            'the user of the account has another id.',
        app: [],
        // The session of an app in the mode anonymous gives an anonymous
        // user the account on a sign-up, so there the test of the session
        // fails on the bug too, next to the test of the service, which
        // fails on it in every mode.
        roleOptions: {'auth-mode': 'anonymous'},
        failures: [
          MatrixExpectedFailure(
            'test/auth_role/auth_service_test.dart',
            'an anonymous user has an id of its own and no email address, '
                'and keeps the id with an account',
            'linkPassword() gives the anonymous user who is signed in an '
                'account: the user keeps the id, is no longer anonymous and '
                'has the email address.',
          ),
          MatrixExpectedFailure(
            'test/auth_role/app_session_test.dart',
            'the session of the app follows its user through a sign-up, a '
                'sign-out, a sign-in and the deletion of the account, as the '
                'mode of the app says',
            'In the mode anonymous, a sign-up gives the anonymous user the '
                'account: the user keeps the id.',
          ),
          // The next start has the account under the new id.
          MatrixExpectedFailure(
            _nextStartTests,
            _leftOnDeviceTest,
            _linkKeptOnDevice,
          ),
          // The token of the account is that of another user.
          MatrixExpectedFailure(
            _userTokenTests,
            'an anonymous user has a token, and keeps the id with a refresh '
                'and with an account',
            'The account that linkPassword() gave an anonymous user has a '
                'token, with the id of that user.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.authLinkingCredentialAsNewUser,
        role: authRole,
        bug: 'Its linkWith() creates a new user for the identity of the '
            'credential, rather than giving it to the anonymous user who is '
            'signed in: the user of the identity has another id.',
        // The fixture way to sign in, whose function the test of the
        // session calls, and whose issuer the test of the service builds
        // credentials of. The session of an app in every mode gives an
        // anonymous user the identity with linkWith(), so the test of the
        // session fails on the bug too, next to the test of the service.
        app: [FakeSignInMethodModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/auth_methods/credential_test.dart',
            'linkWith gives the anonymous user who is signed in the identity, '
                'and the user keeps the id',
            'linkWith keeps the id of the anonymous user: the user who is '
                'signed in gets the identity of the credential, is no longer '
                'anonymous and lists its issuer.',
          ),
          MatrixExpectedFailure(
            'test/auth_methods/session_test.dart',
            'the session signs in with each way to sign in of the app: an '
                'anonymous user gets the identity and keeps the id, a later '
                'user signs in to its account, and once the account is '
                'deleted the identity has a new user',
            'An anonymous user who signs in with a way to sign in keeps the '
                'id: the session gives that user the identity with linkWith, '
                'and the user is no longer anonymous.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.authTokenNotRefreshed,
        role: authRole,
        bug: 'Its forced read of the token gives the token that the user has, '
            'so a server that refused the token refuses the next one too.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            _userTokenTests,
            'the user of an account has a token, which a forced refresh '
            'replaces',
            _newToken,
          ),
          MatrixExpectedFailure(
            _userTokenTests,
            'an anonymous user has a token, and keeps the id with a refresh '
            'and with an account',
            _newToken,
          ),
          MatrixExpectedFailure(
            _userTokenTests,
            'the session refreshes a token that a server refused once, for '
            'all the reads at the same time and for those that come later',
            _newToken,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.authTokenKeptAfterSignOut,
        role: authRole,
        bug: 'It gives the last token that it gave with nobody signed in, so '
            'the requests of the next person on the device go to a server as '
            'the user who left.',
        // The fixture REST, with the fixture values of .env, which it
        // requires, so that the test of the requests of the users of the
        // session applies to the app too.
        app: [FakeRestModule.id, FakeEnvModule.id],
        failures: [
          MatrixExpectedFailure(
            _userTokenTests,
            'the service gives no token while nobody is signed in',
            _noToken,
          ),
          MatrixExpectedFailure(
            _userTokenTests,
            'the session gives the token of its user, as the mode of the app '
            'says',
            _noTokenAfterSignOut,
          ),
          MatrixExpectedFailure(
            _restSessionTests,
            'a request without an account carries what the mode of the app '
                'says',
            'In the modes required and guest, nobody has no token, so the '
                'request goes without a header.',
          ),
          MatrixExpectedFailure(
            _restSessionTests,
            'after a sign-out, a request carries no token of the user who left',
            'After a sign-out a request goes without a token, and in the mode '
                'anonymous with the token of the next anonymous user: never as '
                'the user who left.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.authTokenKeptForNextUser,
        role: authRole,
        bug: 'It gives every user the token of the first, so a server takes '
            'the next person on the device for the user before.',
        app: [],
        failures: [
          MatrixExpectedFailure(
            _userTokenTests,
            'two users have different tokens',
            'Two users have different tokens: a server tells who the user is '
                'by the token.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.notificationsForgettingSchedules,
        role: notificationsRole,
        bug: 'Its function forgets the notifications that are scheduled each '
            'time it opens them, so the next start of the app has none of '
            'them.',
        // The fixture preferences, since the role requires the preferences.
        app: [FakePreferencesModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/notifications_role/next_start_test.dart',
            'a scheduled notification is still scheduled after the next '
                'start, until it is cancelled',
            'The next start keeps the notifications that the app scheduled.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.pushRegisteringAtEachStart,
        role: pushRole,
        bug: 'Its function registers the device anew each time it opens the '
            'push messages, so the device gets a new address a while after '
            'each start, and the next start of the app does not have the '
            'address that the backend kept.',
        // The fixture notifications, which the push role requires, and the
        // fixture preferences, which those require.
        app: [FakeNotificationsModule.id, FakePreferencesModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/push_role/next_start_test.dart',
            'a service that the function of the provider creates again has '
                'the address that the device kept, so the next start has the '
                'same one',
            'A backend keeps the address of a device, so a service that the '
                'function of the provider creates again has the address that '
                'the device kept, and the next start has the same one.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.purchasesKeptByService,
        role: purchasesRole,
        bug: 'Its service keeps the purchases in a field of its own, for '
            'every user together: a user of the app has what any other user '
            'bought through that service, and a service that its function '
            'creates again has nothing.',
        // The fixture sign-in, so that the test of the purchases of the
        // users of the session applies to the app too.
        app: [FakeAuthModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/purchases_role/provider_test.dart',
            'the purchases of each user stay apart: a fresh user has nothing, '
                'a purchase gives that user premium access, another fresh '
                'user has nothing, and the first user has the access again',
            'A provider keeps the purchases of each user apart: a user that '
                'no identification named before, identified after another '
                'user of the app, has nothing bought, whatever the users of '
                'the app before bought.',
          ),
          MatrixExpectedFailure(
            'test/purchases_role/next_start_test.dart',
            'the store keeps what a user bought, so the next start has the '
                'premium access of that user',
            'The store keeps what a user bought, so the next start has it: a '
                'service that the function of the provider creates again '
                'gives the user the same premium access.',
          ),
          MatrixExpectedFailure(
            'test/purchases_session/purchases_session_test.dart',
            'after a sign-out, the next user of the device has none of the '
                'purchases of the user who signed out, and a sign-in to the '
                'account gives them back',
            'Without a restore, the next user of the device never gets the '
                'purchases of the one who signed out: after a sign-out the '
                'user of the device is a new one, with nothing bought, and in '
                'the mode anonymous so is the next anonymous user.',
          ),
          MatrixExpectedFailure(
            'test/purchases_session/purchases_session_test.dart',
            'the user without an account keeps what it bought at the next '
                'start of the app, in every mode',
            'The store keeps what the user without an account bought, and the '
                'device keeps that user from one launch of the app to the '
                'next, so the next start has its premium access',
          ),
          MatrixExpectedFailure(
            'test/purchases_session/purchases_session_test.dart',
            'a sign-in to an account that exists already leaves the purchases '
                'with the user of the device, and the next user of the device '
                'after a sign-out of that account has none of them',
            'After the sign-out of an account, the next user of the device is '
                'a new one, with nothing bought',
          ),
        ],
      ),
      BrokenProvider(
        BrokenEnvModule(),
        role: envRole,
        bug: 'Its AppEnv returns the value of a key as the command that built '
            'the app read it from .env, so a key that .env leaves empty is an '
            'empty text rather than null.',
        // The module that reads values of .env, whose keys the test of the
        // role checks, and whose test gives one of them an empty value.
        app: [FakeEnvUserModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/env_role/env_role_test.dart',
            'AppEnv returns null for each key that .env leaves empty',
            'FAKE_ENV_USER_SECOND is empty in .env, so '
                'AppEnv.fakeEnvUserSecond is null: an empty value counts as '
                'missing.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.restDecodingQuery,
        role: restRole,
        bug: 'Its transport sends the query of an address decoded, so a value '
            'with an & or an = reaches the server as something else.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restAddressTests,
            'a request reaches the path of the address, with its query',
            'A provider sends the address as it is, with its query.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.restLeakingErrors,
        role: restRole,
        bug: 'It reports only a broken connection as a failed one, so a '
            'failure to connect and a failed TLS handshake reach the code as '
            'the reason unknown.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restFailureTests,
            'a port where nothing listens is the reason network, for each '
                'method',
            'A failure to connect is RestConnectionFailed.',
          ),
          MatrixExpectedFailure(
            _restFailureTests,
            'a TLS handshake that fails is the reason network',
            'A TLS handshake that fails is RestConnectionFailed',
          ),
          MatrixExpectedFailure(_restProbeTests, _restProbeTest, _restProbe),
        ],
      ),
      BrokenProvider(
        BrokenModule.restQuotingErrors,
        role: restRole,
        bug: 'Its hint has the text of an error, which may quote the address '
            'with its query, so a key of the query reaches a log.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restFailureTests,
            'a connection that breaks in a body is the reason network, and '
                'the hint has no query',
            'The hint of a provider has no query',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.restFollowingRedirects,
        role: restRole,
        bug: 'It follows a redirect itself, with every header of the exchange, '
            'so the token of the user goes to the host that a server names.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restTokenTests,
            _redirectToHostTest,
            _redirectToHostLeaves,
          ),
          MatrixExpectedFailure(
            _restTokenTests,
            _redirectToPortTest,
            _redirectToPortLeaves,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.restKeepingHeaders,
        role: restRole,
        bug: 'It keeps the first authorization that it sent as a default of '
            'its later calls, so a repeat has the token that the server '
            'refused, and a request to another origin has it too.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restTokenTests,
            'a request to another port or another host has no token',
            'The token goes only to the origin of the address',
          ),
          MatrixExpectedFailure(
            _restTokenTests,
            _redirectToHostTest,
            _redirectToHostLeaves,
          ),
          MatrixExpectedFailure(
            _restTokenTests,
            _redirectToPortTest,
            _redirectToPortLeaves,
          ),
          MatrixExpectedFailure(
            _restTokenTests,
            'a header authorization of the caller stays, in place of the '
                'token',
            'A header of the caller takes precedence over the token.',
          ),
          MatrixExpectedFailure(
            _restRefreshTests,
            'a 401 gets a new token once, and repeats once with it and with '
                'the same body',
            'The repeat after a refresh has the new token',
          ),
          MatrixExpectedFailure(
            _restLogTests,
            _restLogTest,
            'A debug build prints one line for each attempt.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.restRepeatingRequests,
        role: restRole,
        bug: 'It repeats a failed exchange itself, so a server gets a POST '
            'twice, which may have done what it asked.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restRepeatTests,
            'a GET stops after two repeats, with the reason of the status',
            'The client makes each repeat, and a provider makes one attempt '
                'for each.',
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            'a POST does not repeat after a 503',
            _oneAttempt,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            'a PUT does not repeat after a 503',
            _oneAttempt,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            'a PATCH does not repeat after a 503',
            _oneAttempt,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            'a DELETE does not repeat after a 503',
            _oneAttempt,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            'a connection that breaks repeats a GET, and not a POST',
            'A GET repeats twice at most, and a provider makes one attempt '
                'for each.',
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            _retryAfterDateTest,
            _retryAfterDate,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            _retryAfterLongTest,
            'The client takes no wait that long, and a provider repeats '
            'nothing itself.',
          ),
          MatrixExpectedFailure(
            _restStopTests,
            'a cancel wakes the wait for a repeat at once',
            'The client waits for the Retry-After, and a provider repeats '
                'nothing itself.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.restLosingReplyHeaders,
        role: restRole,
        bug: 'It gives a reply without its headers, so the client reads no '
            'Retry-After and no location of a redirect.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restFailureTests,
            'the headers of a reply come with their names in lower case, and '
                'the values of one header together',
            'A provider keeps the headers of a reply, with their names in '
                'lower case',
          ),
          MatrixExpectedFailure(
            _restTokenTests,
            'a redirect on the origin of the address keeps the token',
            _redirectFollowed,
          ),
          MatrixExpectedFailure(
            _restTokenTests,
            _redirectToHostTest,
            _redirectFollowed,
          ),
          MatrixExpectedFailure(
            _restTokenTests,
            _redirectToPortTest,
            _redirectFollowed,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            'a GET waits for the Retry-After of a reply, in seconds',
            'A provider keeps the headers of a reply, and the client waits '
                'for the Retry-After in them.',
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            _retryAfterDateTest,
            _retryAfterDate,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            _retryAfterLongTest,
            _retryAfterOnFailure,
          ),
          MatrixExpectedFailure(
            _restRepeatTests,
            'a POST does not wait, and the failure has the Retry-After',
            _retryAfterOnFailure,
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.restIgnoringStop,
        role: restRole,
        bug: 'It does not stop an exchange, so the connection of a call that '
            'ended stays open.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restStopTests,
            'no answer within the timeout is the reason timeout, and the '
            'connection closes',
            _connectionCloses,
          ),
          MatrixExpectedFailure(
            _restStopTests,
            'a body that comes bit by bit past the timeout is the reason '
            'timeout, and the connection closes',
            _connectionCloses,
          ),
          MatrixExpectedFailure(
            _restStopTests,
            'a cancel while the server holds the request ends the call at '
            'once, and the connection closes',
            _connectionCloses,
          ),
          MatrixExpectedFailure(
            _restStopTests,
            'a cancel in the middle of a body ends the call at once, and the '
            'connection closes',
            _connectionCloses,
          ),
          MatrixExpectedFailure(_restProbeTests, _restProbeTest, _restProbe),
        ],
      ),
      BrokenProvider(
        BrokenModule.restLoggingHeaders,
        role: restRole,
        bug: 'It prints the headers of each exchange, so the token of the user '
            'is in the log of the device.',
        app: _appWithRest,
        failures: [
          MatrixExpectedFailure(
            _restLogTests,
            _restLogTest,
            'Nothing that a client or a provider prints, or says in a failure, '
            'has a header, a query or a body.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.serviceLogNotingAnalyticsTwice,
        role: analyticsRole,
        bug: 'Its analytics service notes each call twice, as a service does '
            'that sends each event twice.',
        app: [FakeAnalyticsModule.id, FakeCrashModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/analytics_role_test.dart',
            'the analytics service of the app forwards each call to every '
                'analytics service once',
            'Each call reaches every analytics service once, in the order of '
                'the calls.',
          ),
          MatrixExpectedFailure(
            'test/analytics_role_test.dart',
            'an analytics service that throws as it is called keeps no other '
                'from the call, and its failure does not reach the code that '
                'called',
            'The service log gets the call once.',
          ),
          MatrixExpectedFailure(
            'test/analytics_role_test.dart',
            'an analytics service that returns a future that fails keeps no '
                'other from the call, and its failure does not reach the code '
                'that called',
            'The service log gets the call once.',
          ),
          MatrixExpectedFailure(
            'test/analytics_role_start_test.dart',
            'the other analytics services get each call',
            'The service log gets the call.',
          ),
        ],
      ),
      BrokenProvider(
        BrokenModule.crashReportingTakingFlutterErrors,
        role: crashReportingRole,
        bug: 'Its start sets the handler of the errors of Flutter to a report '
            'of its own, so the handler of the role calls it in place of the '
            'handler that presented the errors: none is presented, and it '
            'reports each of them twice.',
        app: [FakeAnalyticsModule.id, FakeServiceLogModule.id],
        failures: [
          MatrixExpectedFailure(
            'test/crash_reporting_role_test.dart',
            'an error of Flutter reaches every crash reporter once, as fatal, '
                'once the handler that the start-up found presents it',
            'The handler of the errors of Flutter that the start-up found '
                'presents each of them once.',
          ),
          MatrixExpectedFailure(
            'test/crash_reporting_role_test.dart',
            'a crash reporter that throws as it is called keeps no other from '
                'a call, and its failure reaches neither the code that called '
                'nor the handlers of the errors',
            'Every other crash reporter gets each call once, and no report of '
                'the failure of the service log.',
          ),
          MatrixExpectedFailure(
            'test/crash_reporting_role_test.dart',
            'a crash reporter that returns a future that fails keeps no other '
                'from a call, and its failure reaches neither the code that '
                'called nor the handlers of the errors',
            'Every other crash reporter gets each call once, and no report of '
                'the failure of the service log.',
          ),
          MatrixExpectedFailure(
            'test/crash_reporting_role_factory_test.dart',
            'the other crash reporters get each error that nothing catches, '
                'and each call',
            'The handlers of the errors that the start-up installed, and the '
                'crash reporter of the app, reach the fixture crash reporting.',
          ),
        ],
      ),
    ];

/// The other modules of the app of a router that breaks what the role says
/// of the guards of the routes: the fixture late gate and the fixture
/// gates, in the order of the registry of the fixtures, whose guards the
/// tests close and open, with the provider of the fixture badge role, whose
/// condition one of those guards stands for; the fixture feature, whose
/// screens the guards keep the user from, and on whose screen the app
/// starts; the second fixture feature, three routes of which ask for that
/// condition; and what the fixture feature and the tests of the listeners
/// of the screen need.
const List<ModuleId> _appWithGates = [
  FakeFeatureModule.id,
  FakeSecondModule.id,
  FakeLateGateModule.id,
  FakeGateModule.id,
  FakeClockBadgeModule.id,
  FakeBlocModule.id,
  FakeDiModule.id,
  FakeAnalyticsModule.id,
  FakeCrashModule.id,
  FakeServiceLogModule.id,
];

/// The other modules of the app of a broken provider of the REST role: the
/// fixture values of .env, since the role requires the env role, and whose
/// getter of the address the test of the role reads.
const List<ModuleId> _appWithRest = [FakeEnvModule.id];

/// The files of the tests of the REST role.
const _restAddressTests = 'test/rest_role/address_test.dart';
const _restFailureTests = 'test/rest_role/failures_test.dart';
const _restTokenTests = 'test/rest_role/token_test.dart';
const _restRefreshTests = 'test/rest_role/refresh_test.dart';
const _restRepeatTests = 'test/rest_role/repeats_test.dart';
const _restStopTests = 'test/rest_role/stop_test.dart';
const _restLogTests = 'test/rest_role/log_test.dart';
const _restProbeTests = 'test/rest_role/probe_test.dart';

/// The file of the tests of the token of the session on a request.
const _restSessionTests = 'test/rest_session/session_token_test.dart';

/// The name of the test of the probe of the REST role, and its reason.
const _restProbeTest = 'the probe of the role finds no problem';
const _restProbe =
    'The stack of a provider reaches a server on the device, stops an '
    'exchange, and fails as a connection fails for a closed port and for a '
    'request over http:// to an address that no machine has.';

/// The name of the test of what a debug build prints of a call.
const _restLogTest =
    'a call with a refresh prints a line for each attempt, with no token, no '
    'query and no body';

/// The names of two tests of a redirect to another origin, and the reasons of
/// their expectations of the headers at that origin and that the client
/// follows it.
const _redirectToHostTest =
    'a redirect to another host takes the token and the credentials of the '
    'caller away';
const _redirectToPortTest =
    'a redirect to another port takes the token away, and a hop back gets it '
    'again';
const _redirectToHostLeaves =
    'The client decides which header goes where, so a provider follows no '
    'redirect: at another origin, the token and the cookie of the caller are '
    'gone.';
const _redirectToPortLeaves =
    'The client decides which header goes where, so a provider follows no '
    'redirect: another port gets no token, and only a hop back to the origin '
    'of the address does.';
const _redirectFollowed =
    'A GET follows a redirect, whose location is a header of the reply.';

/// The reason of the tests that a method does not repeat, and of the tests of
/// a Retry-After.
const _oneAttempt =
    'A method that may have done what it asked does not repeat, so a provider '
    'makes one attempt for each exchange.';
const _retryAfterDateTest =
    'a GET waits for the Retry-After of a reply, as a date';
const _retryAfterDate =
    'A provider keeps the headers of a reply, and the client waits for the '
    'date of the Retry-After in them.';
const _retryAfterLongTest =
    'a Retry-After over the longest wait gives no repeat, and the failure has '
    'it';
const _retryAfterOnFailure =
    'A provider keeps the headers of a reply, and the failure has the wait '
    'that the client did not take.';

/// The reason of the tests that an exchange that has to stop closes its
/// connection.
const _connectionCloses =
    'When RestExchange.stop completes, a provider closes the connection at '
    'once.';

/// The other modules of the app of a broken layout: a router, the two
/// fixture features, whose destinations the main navigation shows, and what
/// the first of them and the tests of the listeners of the screen need.
const List<ModuleId> _appWithMainNavigation = [
  FakeRouterModule.id,
  FakeFeatureModule.id,
  FakeSecondModule.id,
  FakeBlocModule.id,
  FakeDiModule.id,
  FakeAnalyticsModule.id,
  FakeCrashModule.id,
  FakeServiceLogModule.id,
  FakeScreenLogModule.id,
];

/// The name of the test of the walk of the routes.
const _walkTest =
    'each location that needs no values shows the page and the screen of '
    'its route, or the screen that the app starts on if its flow is over';

/// The name of the test of the flow of a guard of the routes.
const _flowTest =
    'the routes of the flow of a guard show only while the guard does not '
    'allow, and the screen that the app starts on in their place once the '
    'flow is over';

/// The name of the test of a guard of the routes that does not bring the
/// user back.
const _returnTest =
    'a guard that does not bring the user back shows the screen that the app '
    'starts on once it allows again, or a location that was asked for while '
    'it did not allow';

/// The name of the test of the walk of the routes while a guard keeps the
/// user out.
const _walkGuardsTest =
    'the walk of the routes holds while a guard keeps the user out, once the '
    'flows of the guards are over, and while a condition does not hold';

/// The name of the test of a condition that stops holding on a page that
/// asks for it, and the reason of its first expectation that such a page
/// closes.
const _conditionStopsTest =
    'a condition that stops holding closes the pages that ask for it with '
    'the pages over them, a pushed one and one below a route that asks for '
    'nothing, and the user is on the page below';
const _pushedPageLeaves =
    'When a condition stops holding, the router closes a pushed page that '
    'asks for the condition, over a page that asks for none: the user is on '
    'the page below.';

/// The names of the tests of a guard that stands for a condition: of the
/// requests for the routes that ask for it, of its flow while it is open,
/// of the guard next to the gates, of the requests from the main
/// navigation, and of a route that asks for two conditions.
const _conditionsTest =
    'a request for a route that asks for a condition opens the flow of its '
    'guard over the page that the user is on, back returns to that page, '
    'and the router does what was asked once the condition holds';
const _conditionFlowTest =
    'the flow of a condition stays open for the request that opened it '
    'while one of its pages is among the pages, and closes with the pages '
    'over it once the condition holds';
const _conditionGatesTest =
    'a gate decides before a guard of a condition, the flow that the two '
    'have is over once both allow, and a guard of a condition that does not '
    'bring the user back makes the router forget where the user was';
const _conditionLayoutTest =
    'the flow of a condition opens over the main navigation, which stays '
    'below with its destination selected, and the route that was asked for '
    'shows over it once the condition holds';
const _conditionTwoTest =
    'for a route that asks for two conditions, the flow of the first guard '
    'that does not allow opens, and that of the next once the first allows; '
    'the router keeps one request waiting';

/// The name of the test of one request for a route that asks for a
/// condition, which needs the fixture gates without the late gate, and the
/// reasons of its expectations: that the router throws nothing, that the
/// target of the guard opens, and that it opens over the page that the user
/// is on.
const _flowOpensTest =
    'a request for a route that asks for a condition opens the target of '
    'its guard once, without an error';
const _routerThrowsNothing =
    'A router throws nothing when it opens the target of a guard for a '
    'request.';
const _flowOpensOnce =
    'push() of a route that asks for a condition that does not hold opens '
    'the target of the guard of the condition, of which the listeners of the '
    'screen hear once.';
const _flowOpensOverPage =
    'The target of a guard of a condition opens once, over the page that the '
    'user is on, which stays below it.';

/// The name of the test of a push() before the router has a page, and the
/// reasons of two of its expectations: that the flow of the first guard
/// opens over the screen that the app starts on, and that of the next once
/// the first allows.
const _conditionEarlyTest =
    'a push() of a route that asks for two conditions before the router has '
    'a page opens the flow of each guard in turn over the screen that the '
    'app starts on, and shows the route once both hold';
const _earlyRequestOpensFlow =
    'A request for a route that asks for a condition that does not hold, '
    'made before the router has a page, opens the target of the guard over '
    'the screen that the app starts on.';
const _earlyRequestOpensNext =
    'Once the first condition holds, the target of the guard of the second '
    'opens for a request that was made before the router had a page, and '
    'the listeners of the screen hear nothing of the screen that the app '
    'starts on between the two flows.';

/// The reason of the expectation of the test of a condition next to the
/// gates that the request of an open flow still waits when the gate of
/// that flow stops allowing.
const _requestWaitsBehindGate =
    'The request that opened the flow of a condition waits while a page of '
    'the flow is among the pages: the target of a gate with the same flow '
    'is one.';

/// The reasons of some expectations of the tests of a condition: that its
/// flow opens for a push(), that the push() waits while the flow is open,
/// that the router shows what push() asked for once the condition holds,
/// and that it then makes the request that opened the flow.
const _pushOpensFlow =
    'push() of a route that asks for a condition that does not hold opens '
    'the target of the guard of the condition.';
const _pushWaits =
    'A push() that opened the flow of a guard waits while the flow is open.';
const _requestShows =
    'Once the condition holds, the router closes the flow and shows the '
    'location that push() asked for over the page that the flow was opened '
    'over.';
const _firstRequestMade =
    'Once the condition holds, the router makes the request that opened the '
    'flow, not one that came while the flow was open.';

/// The reasons of two expectations of the test of a route that asks for
/// two conditions: that the flow of the first guard opens, and that of the
/// next once the first allows.
const _firstOfTwoOpens =
    'For a route that asks for two conditions that do not hold, the target '
    'of the first guard of the app that stands for one of them opens.';
const _nextOfTwoOpens =
    'Once the first condition holds, the router closes its flow and asks '
    'about the request again: the target of the guard of the second '
    'condition opens, and the listeners of the screen hear nothing of the '
    'page below in between.';

/// The reason of the expectation of the walk of the routes while a
/// condition does not hold.
const _walkOfCondition =
    'While a condition does not hold, each location that asks for it shows '
    'the target of its guard, each location of the flow of that guard its '
    'own screen, and each other location what it shows with guards that '
    'allow.';

/// The name of the test of the labels of the destinations.
const _labelsTest =
    'the labels of the destinations follow the language of the app';

/// The names of three tests of the localization role, and the reason of
/// one of their expectations: that the root of the app can be in each
/// language of the app.
const _languagesTest =
    'once the user chose a language, the app is in it, and each text of the '
    'app reads in it, in each language of the app';
const _deviceTest =
    'while the user chose no language, the app is in the language that the '
    'device prefers among its own, and in its first one when the device asks '
    'for none of them';
const _probeTest = 'the probe of the role finds no problem';
const _eachLanguageSupported =
    'For each language of the app, the root has a delegate of each kind of '
    'localizations that supports it.';

/// The file of the test of the native projects of the app icon role.
const _appIconTests = 'test/app_icon_role/app_icon_role_test.dart';

/// The file of the tests of the token of the auth role, and the reasons of
/// its expectations that the fixture sign-in with a known bug of the token
/// fails.
const _userTokenTests = 'test/auth_role/user_token_test.dart';

/// The reason of the tests of a forced refresh of the token.
const _newToken = 'A read with forceRefresh asks the server of the provider '
    'for a new token: it differs from the one before, the user stays, and the '
    'reads after it give the new one.';

/// The reason of the test of the service with nobody signed in.
const _noToken = 'With nobody signed in, the service has no token to give: a '
    'read answers null, also a read that forces a refresh, and no earlier '
    'token stays behind for it.';

/// The reason of the test of the session after a sign-out.
const _noTokenAfterSignOut = 'After a sign-out the session has no token, and '
    'in the mode anonymous the token of the new anonymous user.';

/// The file of the test of the flavor of a running app.
const _flavorTests = 'test/flavors/default_flavor_test.dart';

/// The file of the tests of the next start of the auth role, and the
/// reason of the expectation of each of them that a start of the app has
/// the user of the device as soon as it is over.
const _nextStartTests = 'test/auth_role/next_start_test.dart';
const _knownAtStart =
    'When the next start of the session is over, the session has the user '
    'who was signed in on the device: who uses the app is known before the '
    'first frame.';

/// The name of the test of what a link and a deletion leave on the device,
/// and the reason of its expectation that the next start has the account
/// that an anonymous user got, with the id of that user.
const _leftOnDeviceTest =
    'the next start has what the service left on the device: the account '
    'that an anonymous user got, and nobody once the user was deleted';
const _linkKeptOnDevice =
    'The account that linkPassword() gave an anonymous user is kept on the '
    'device: the next start has that account, with the id of the anonymous '
    'user.';

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

/// The apps whose tests must fail for what a module of the app does, rather
/// than a provider of a role; `tool/broken_providers_matrix.dart` generates
/// them and runs their tests with those of the broken providers.
///
/// The app of the fixture gates that start closed has guards that nothing
/// opens for the tests of the app, as the mocks of the app test of their
/// module would. The test of the walk of the routes must fail on them, by
/// their names and with what the module of a guard does about it, and every
/// other test of the app must pass.
List<MatrixFailingApp> brokenModuleApps() => const [
      MatrixFailingApp(
        'fake_gate_stays_closed',
        modules: [
          FlutterCoreModule(),
          FakeRouterModule(),
          FakeBlocModule(),
          FakeGateModule(open: false),
          // The fixture badge role, which the fixture gates require.
          FakeClockBadgeModule(),
        ],
        failures: [
          MatrixExpectedFailure(
            'test/router_walk_test.dart',
            _walkTest,
            'These guards of the routes do not allow, so the walk cannot '
                'reach the routes outside their flows, and the tests of the '
                'other modules of the app do not see the screens that they '
                'expect. The module of a guard opens it for the tests of the '
                'app in the mocks of its app test (MatrixAppTest.mocks), '
                'before the app starts.',
          ),
        ],
      ),
    ];

/// The roles whose contract the app tests check but no broken provider
/// breaks, each with the reason.
const Map<Role, String> brokenProviderExemptions = {};
