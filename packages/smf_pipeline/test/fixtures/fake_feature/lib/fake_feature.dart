/// Fake features for the tests of the SMF pipeline. Not modules to use.
///
/// The first has a start route with a child that takes a path and a query
/// parameter, a destination of the main navigation, a variant for each
/// fake state manager, and a composition file that resolves a service, so
/// it uses the navigation facade, the annotation sockets of the router, and
/// the rules for resolving services. The second has another start route
/// with a destination, so an app with both has two screens that can start
/// it and two destinations, a route outside the main navigation, whose
/// page a router shows over it, and a setting for the settings screen of
/// an app that has one. Its screens and its setting show texts of the
/// module, which it gives the localization role: in the language of the
/// app with the role, and in English without it.
library;

import 'package:fake_feature/bundles/fake_feature_bloc_bundle.dart';
import 'package:fake_feature/bundles/fake_feature_bundle.dart';
import 'package:fake_feature/bundles/fake_feature_riverpod_bundle.dart';
import 'package:fake_feature/bundles/fake_second_bundle.dart';
import 'package:fake_feature/bundles/fake_second_settings_bundle.dart';
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
              destination: Destination(
                label: 'Fixture',
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
/// It uses the localization role: each screen shows a text of the module.
///
/// It uses the settings screen role too: in an app with a settings screen,
/// it generates the widget of a setting, which shows a text of the module
/// as well, and gives the role an entry for it. The widget has the class
/// name of the setting of the fixture screen log, `FixtureSetting`, in a
/// file of its own: an app with both analyzes only if the screen imports
/// the file of each with a prefix of its own, as the role asks of every
/// provider.
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

  static const _folder = 'features/fake_second';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A second start screen (fixture)',
        kind: ModuleKinds.feature,
        uses: {localizationRole, settingsScreenRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          fakeSecondBundle,
          vars: localizationRole.varsOf(id, texts),
        ),
        localizationRole.data(texts),
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
                label: 'Second',
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
          ]),
        ),
        // Only an app with a settings screen gets the widget of the
        // setting, and only there does the entry apply.
        BrickContribution(
          fakeSecondSettingsBundle,
          when: const {settingsScreenRole},
        ),
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
