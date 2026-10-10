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
  /// The app entry of the app is that of the fixtures, or [module] itself
  /// if it provides the app entry.
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
            'test/router_conditions_test.dart',
            _conditionsTest,
            'go() to a route that asks for a condition that does not hold '
                'shows the target of the guard of the condition.',
          ),
          MatrixExpectedFailure(
            'test/router_condition_gates_test.dart',
            _conditionGatesTest,
            'While a gate does not allow, go() to a route that asks for no '
                'condition shows the target of the gate.',
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
          // The location that was asked for while a condition did not hold
          // is an answer like any other: the router does not show it.
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            'Once the condition holds, the router shows the location that '
                'was asked for.',
          ),
          MatrixExpectedFailure(
            'test/router_condition_gates_test.dart',
            _conditionGatesTest,
            'Once the gate and the condition allow, the router shows the '
                'latest location that was asked for.',
          ),
          // Nor the target of the guard of a condition that stops holding
          // on a page that asks for it.
          MatrixExpectedFailure(
            'test/router_condition_stops_test.dart',
            _conditionStopsTest,
            _pushedPageLeaves,
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
          // And the target of the guard of a condition that does not hold,
          // for a route that asks for it. The test of such a guard next to
          // the gates replaces no page, so it passes.
          MatrixExpectedFailure(
            'test/router_conditions_test.dart',
            _conditionsTest,
            'replace() with a route that asks for a condition that does not '
                'hold shows the target of the guard of the condition.',
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
            'asks for nothing.',
        app: _appWithGates,
        failures: [
          MatrixExpectedFailure(
            'test/router_condition_stops_test.dart',
            _conditionStopsTest,
            _pushedPageLeaves,
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
            'go() to a route that asks for a condition that does not hold, '
                'below a route that asks for none, shows the target of the '
                'guard of the condition.',
          ),
          // The walk goes to that route while the condition does not hold.
          MatrixExpectedFailure(
            'test/router_walk_guards_test.dart',
            _walkGuardsTest,
            'While a condition does not hold, each location that asks for it '
                'shows the target of its guard, each location of the flow of '
                'that guard its own screen, and each other location what it '
                'shows with guards that allow.',
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
/// asks for it, and the reason of its first expectation of the target of
/// the guard.
const _conditionStopsTest =
    'a condition that stops holding shows the target of its guard in place '
    'of a page that asks for it, a pushed one and one below a route that '
    'asks for nothing';
const _pushedPageLeaves =
    'When a condition stops holding, the router shows the target of its '
    'guard in place of a pushed page that asks for the condition, over a '
    'page that asks for none.';

/// The names of the two tests of a guard that stands for a condition: of
/// the routes that ask for it, and of the guard next to the gates.
const _conditionsTest =
    'a route that asks for a condition shows only while the condition holds, '
    'the target of its guard in its place until then, and every other route '
    'as it is';
const _conditionGatesTest =
    'a gate decides before a guard of a condition, the flow that the two '
    'have is over once both allow, and a guard of a condition that does not '
    'bring the user back makes the router forget where the user was';

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
