/// Fake features for the tests of the SMF pipeline. Not modules to use.
///
/// The first has a start route with a child that takes a path and a query
/// parameter, a destination of the main navigation, a variant for each
/// fake state manager, and a composition file that resolves a service, so
/// it uses the navigation facade, the annotation sockets of the router, and
/// the rules for resolving services. It does not list the localization
/// role, so the label of its destination is in English in every app. The
/// second has another start route with a destination, so an app with both
/// has two screens that can start it and two destinations, a route outside
/// the main navigation, whose page a router shows over it, and a setting
/// for the settings screen of an app that has one. Its screens, its setting
/// and the label of its destination are texts of the module, which it gives
/// the localization role: in the language of the app with the role, and in
/// English without it. It also has a route outside the main navigation,
/// with a route below it, that asks for a condition of the fixture badge
/// role, which it uses. The third has two guards
/// over gates that a test opens and closes, each with a route to show while
/// its gate is closed, the first with a route below it, and a third guard
/// that stands for that condition and shows the route of the first. It
/// depends on one of the two fake state managers, so the apps with every
/// fixture come with guards and without, and the routes of the second
/// feature that ask for the condition have a guard in the first and none
/// in the others. The fourth has one guard over a gate of its own, of
/// a later stage than the guards of the third, which does not bring the
/// user back. It depends on the same state manager, and the registries list
/// it before the third, so the stages of the guards go against the order of
/// their modules.
library;

import 'package:fake_feature/bundles/fake_feature_bloc_bundle.dart';
import 'package:fake_feature/bundles/fake_feature_bundle.dart';
import 'package:fake_feature/bundles/fake_feature_riverpod_bundle.dart';
import 'package:fake_feature/bundles/fake_gate_bundle.dart';
import 'package:fake_feature/bundles/fake_late_gate_bundle.dart';
import 'package:fake_feature/bundles/fake_second_bundle.dart';
import 'package:fake_feature/bundles/fake_second_settings_bundle.dart';
import 'package:fake_roles/fake_roles.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// A feature with a start screen and a details screen.
final class FakeFeatureModule extends SmfModule {
  /// Creates the module.
  const FakeFeatureModule();

  /// The id of the module.
  static const id = ModuleId('fake_feature');

  static const _folder = 'features/fake_feature';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'A start screen and details (fixture)',
        kind: ModuleKinds.feature,
        requires: const {diRole, analyticsRole},
        variants: Variants(
          role: stateManagementRole,
          // Each variant imports the package of its provider, whose
          // constraint the provider owns.
          byProvider: {
            const ModuleId('fake_bloc'): (context) => [
                  BrickContribution(fakeFeatureBlocBundle),
                  const PubspecContribution.hosted('flutter_bloc', 'any'),
                ],
            const ModuleId('fake_riverpod'): (context) => [
                  BrickContribution(fakeFeatureRiverpodBundle),
                  const PubspecContribution.hosted('flutter_riverpod', 'any'),
                ],
          },
        ),
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeFeatureBundle),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: 'home',
              screen: ScreenRef(
                'FixtureHomeScreen',
                import: ImportRef.app('$_folder/fixture_home_screen.dart'),
              ),
              // The module does not list the localization role, so its
              // label is in English in every app.
              destination: Destination(
                label: LocalizedText('label', en: 'Fixture'),
                icon: Fragment(
                  'Icons.star',
                  imports: [ImportRef('package:flutter/material.dart')],
                ),
              ),
              startCandidate: true,
              children: [
                Route(
                  'details/:id',
                  name: 'details',
                  screen: ScreenRef(
                    'FixtureDetailsScreen',
                    import:
                        ImportRef.app('$_folder/fixture_details_screen.dart'),
                  ),
                  params: [
                    RouteParam.path('id', type: int),
                    RouteParam.query('tab', type: String, optional: true),
                  ],
                ),
              ],
            ),
          ]),
        ),
      ];
}

/// A second feature with a start screen that is a destination of the main
/// navigation, and a screen outside the main navigation, which a router
/// shows over it.
///
/// It uses the localization role: each screen shows a text of the module,
/// and the label of its destination is one too.
///
/// It uses the settings screen role too: in an app with a settings screen,
/// it generates the widget of a setting, which shows a text of the module
/// as well, and gives the role an entry for it. The widget has the class
/// name of the setting of the fixture screen log, `FixtureSetting`, in a
/// file of its own: an app with both analyzes only if the screen imports
/// the file of each with a prefix of its own, as the role asks of every
/// provider.
///
/// And it uses the fixture badge role: its route `/fake_second/members`,
/// outside the main navigation, asks for the condition that the role
/// publishes ([BadgeRole.holder]), and so does the route below it, by being
/// there. The module declares no guard and knows no module that has one.
/// In an app with a guard that stands for the condition, the router shows
/// the target of that guard in place of the two routes while the condition
/// does not hold. In an app without one, as in an app without the role,
/// they show like any other route.
final class FakeSecondModule extends SmfModule {
  /// Creates the module.
  const FakeSecondModule();

  /// The id of the module.
  static const id = ModuleId('fake_second');

  /// The texts of the screens: one in English, in Ukrainian and in Maltese,
  /// a language in which Flutter has no texts for its own widgets, so that
  /// no app is in it; and one without a translation, which reads in English
  /// in every language, with a quote that the code of its text escapes.
  static const texts = TextsData([
    LocalizedText(
      'title',
      en: 'Second screen',
      translations: {'uk': 'Другий екран', 'mt': 'It-tieni skrin'},
    ),
    LocalizedText('outside', en: "Outside the app's main navigation"),
  ]);

  /// The label of the destination of the start screen, in English and in
  /// Ukrainian, which the module gives the localization role too: the main
  /// navigation shows it in the language of an app with that role.
  static const label = LocalizedText(
    'label',
    en: 'Second',
    translations: {'uk': 'Другий'},
  );

  /// The text of the setting, which only an app with a settings screen has.
  static const settingTexts = TextsData([
    LocalizedText(
      'setting',
      en: 'Second setting',
      translations: {'uk': 'Друге налаштування'},
    ),
  ]);

  static const _folder = 'features/fake_second';

  static const _members =
      ImportRef.app('$_folder/fixture_members_screens.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A second start screen (fixture)',
        kind: ModuleKinds.feature,
        uses: {localizationRole, settingsScreenRole, badgeRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          fakeSecondBundle,
          vars: localizationRole.varsOf(id, texts),
        ),
        localizationRole.data(texts),
        localizationRole.data(const TextsData([label])),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: 'second',
              screen: ScreenRef(
                'FixtureSecondScreen',
                import: ImportRef.app('$_folder/fixture_second_screen.dart'),
              ),
              destination: Destination(
                label: label,
                icon: Fragment(
                  'Icons.looks_two',
                  imports: [
                    ImportRef('package:flutter/material.dart', show: ['Icons']),
                  ],
                ),
              ),
              startCandidate: true,
            ),
            Route(
              '/outside',
              name: 'outside',
              screen: ScreenRef(
                'FixtureOutsideScreen',
                import: ImportRef.app('$_folder/fixture_outside_screen.dart'),
              ),
            ),
            // The route below it asks for the condition too.
            Route(
              '/members',
              name: 'members',
              screen: ScreenRef('FixtureMembersScreen', import: _members),
              conditions: [BadgeRole.holder],
              children: [
                Route(
                  'card',
                  name: 'memberCard',
                  screen:
                      ScreenRef('FixtureMemberCardScreen', import: _members),
                ),
              ],
            ),
          ]),
        ),
        // Only an app with a settings screen gets the widget of the
        // setting and its text, and only there does the entry apply.
        BrickContribution(
          fakeSecondSettingsBundle,
          vars: localizationRole.varsOf(id, settingTexts),
          when: const {settingsScreenRole},
        ),
        localizationRole.data(settingTexts, when: const {settingsScreenRole}),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef(
              'FixtureSetting',
              import: ImportRef.app('$_folder/fixture_second_setting.dart'),
            ),
          ),
        ),
      ];
}

/// A feature with two guards of the routes that are gates, which keep the
/// user from the other screens of the app while their gates are closed,
/// and a guard that stands for a condition, which keeps the user only from
/// the routes that ask for it.
///
/// The gates are open unless a test closes them, so the guards allow in
/// every app until a test of the guards says otherwise, and the other tests
/// of an app with the module see its screens as they are. The first guard
/// shows the gate screen at `/fake_gate`, with a step below it, and the
/// second, which the app asks after it, the second gate screen at
/// `/fake_gate/second`. Both routes are outside the main navigation, and
/// neither can start the app. Both guards are of the stage `welcome`, so
/// the app asks them as the module declares them, and both bring the user
/// back to where they were once they allow again.
///
/// The third guard stands for the condition of the fixture badge role
/// ([BadgeRole.holder]), which the module requires: it allows while the
/// user holds the badge of the fixture, which a test takes away. It shows
/// the gate screen of the first guard, so the two have one flow, which is
/// over once both allow. The module declares it between the two gates, with
/// their stage, and the app asks it after every gate, that of the fixture
/// late gate too, a gate of a later stage. It does not bring the user back.
/// The module knows no route that asks for the condition: those of the
/// second fixture feature do, in an app with that feature.
///
/// The module depends on one of the two fake state managers, as a feature
/// that works with one state manager does, though it uses nothing of it.
/// So of the apps with every fixture, those with that state manager have
/// the gates and those with the other have no guard, with each router: the
/// tests of the router role and of the layout role run both in apps with
/// guards and in apps without them, which is what most apps are.
///
/// With [open] `false`, the two gates start closed, as the guard of a
/// module does until the user did what it waits for, and nothing opens
/// them for the tests of the app, as the mocks of the app test of such a
/// module would: the app that shows that the walk of the routes fails on
/// such a guard has them (`brokenModuleApps` of the fixture registry). The
/// user holds the badge there too.
final class FakeGateModule extends SmfModule {
  /// Creates the module, whose two gates start open unless [open] is
  /// `false`.
  const FakeGateModule({this.open = true});

  /// Whether the two gates are open when the app starts.
  final bool open;

  /// The id of the module.
  static const id = ModuleId('fake_gate');

  static const _gates = ImportRef.app('features/fake_gate/fixture_gates.dart');

  static const _screens =
      ImportRef.app('features/fake_gate/fixture_gate_screens.dart');

  /// The state manager that the module depends on.
  static const stateManager = ModuleId('fake_bloc');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Screens behind two gates (fixture)',
        kind: ModuleKinds.feature,
        dependsOn: {stateManager},
        requires: {badgeRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeGateBundle, vars: {'open': open}),
        routerRole.data(
          const RoutesData(
            [
              Route(
                '/',
                name: 'gate',
                screen: ScreenRef('FixtureGateScreen', import: _screens),
                children: [
                  Route(
                    'step',
                    name: 'step',
                    screen:
                        ScreenRef('FixtureGateStepScreen', import: _screens),
                  ),
                ],
              ),
              Route(
                '/second',
                name: 'second',
                screen: ScreenRef('FixtureSecondGateScreen', import: _screens),
              ),
            ],
            guards: [
              RouteGuard(
                name: 'first',
                allows: FunctionRef('fixtureGateOpen', import: _gates),
                redirectTo: 'gate',
                stage: GuardStage.welcome,
              ),
              // It has the flow of the first guard, and comes after the
              // gates of the app though it is declared before one.
              RouteGuard(
                name: 'holder',
                allows: FunctionRef('fixtureHolds', import: _gates),
                redirectTo: 'gate',
                stage: GuardStage.welcome,
                resumes: false,
                condition: BadgeRole.holder,
              ),
              RouteGuard(
                name: 'second',
                allows: FunctionRef('fixtureSecondGateOpen', import: _gates),
                redirectTo: 'second',
                stage: GuardStage.welcome,
              ),
            ],
          ),
        ),
      ];
}

/// A feature with one guard of the routes of a later stage than the guards
/// of the fixture gates ([FakeGateModule]), which does not bring the user
/// back.
///
/// Its gate, the late gate, is open unless a test closes it, as the gates
/// of the fixture gates are. Its guard shows the late gate screen at
/// `/fake_late_gate`, which is outside the main navigation and cannot start
/// the app. The guard is of the stage `identity`, and those of the fixture
/// gates are of the stage `welcome`. So the app asks it after them, though
/// the registries of the fixtures list this module before the fixture
/// gates, and the order of the modules alone would ask it first.
///
/// The guard does not resume ([RouteGuard.resumes]): when its gate closes,
/// the router forgets what it remembered, for the guards of the fixture
/// gates too, and once the gates are open again, the user comes to the
/// screen that the app starts on, unless a location was asked for since.
///
/// The module depends on the fake state manager that the fixture gates
/// depend on, so the apps with every fixture have the guards of both
/// modules or no guard.
final class FakeLateGateModule extends SmfModule {
  /// Creates the module.
  const FakeLateGateModule();

  /// The id of the module.
  static const id = ModuleId('fake_late_gate');

  static const _folder = 'features/fake_late_gate';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A screen behind a late gate (fixture)',
        kind: ModuleKinds.feature,
        dependsOn: {FakeGateModule.stateManager},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeLateGateBundle),
        routerRole.data(
          const RoutesData(
            [
              Route(
                '/',
                name: 'gate',
                screen: ScreenRef(
                  'FixtureLateGateScreen',
                  import:
                      ImportRef.app('$_folder/fixture_late_gate_screen.dart'),
                ),
              ),
            ],
            guards: [
              RouteGuard(
                name: 'late',
                allows: FunctionRef(
                  'fixtureLateGateOpen',
                  import: ImportRef.app('$_folder/fixture_late_gate.dart'),
                ),
                redirectTo: 'gate',
                stage: GuardStage.identity,
                resumes: false,
              ),
            ],
          ),
        ),
      ];
}
