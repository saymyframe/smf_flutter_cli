import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_home_flutter/bundles/home_bundle.dart';
import 'package:smf_home_flutter/src/agents.dart';

/// The module of the start screen of the app: a feature with one route,
/// whose screen, `HomeScreen`, shows the name of the app in its app bar and
/// nothing else, a neutral place for the app to start from.
///
/// The route is `/` of the module, so its full path is `/home`. The app can
/// start on it: when no other route can, the app starts there, and
/// otherwise `smf create` asks which route, or takes it from `--start`. The
/// main navigation of the app, when a module provides it, shows the route
/// as Home with the home icon.
///
/// That label is a text of the module, in English and in Ukrainian, which
/// the module gives the localization role, a role that it uses. With the
/// role, the main navigation reads the label from the texts of the app, in
/// the language of the app; without it, the label is the English text.
///
/// As a feature, the module requires the router role, whichever module
/// provides it, and keeps its file in `lib/features/home/`. The screen has
/// no state, so the module has no variants for the modules that manage
/// state.
///
/// The guide for coding agents of the app has a section of the module,
/// which says that the screen is a place to start from, whose content the
/// app replaces.
final class HomeModule extends SmfModule {
  /// Creates the module.
  const HomeModule();

  /// The id of the module.
  static const id = ModuleId('home');

  /// The label of the destination of the screen in the main navigation.
  static const _label = LocalizedText(
    'label',
    en: 'Home',
    translations: {'uk': 'Головна'},
  );

  /// The texts of the module, which it gives the localization role.
  static const _texts = TextsData([_label]);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Start screen with the name of the app',
        kind: ModuleKinds.feature,
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(homeBundle),
        localizationRole.data(_texts),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: 'home',
              screen: ScreenRef(
                'HomeScreen',
                import: ImportRef.app('features/home/home_screen.dart'),
              ),
              destination: Destination(
                label: _label,
                icon: Fragment(
                  'Icons.home',
                  imports: [
                    ImportRef('package:flutter/material.dart', show: ['Icons']),
                  ],
                ),
              ),
              startCandidate: true,
            ),
          ]),
        ),
        AppEntryRole.agentSections.entry(agentHeading, AgentNote(agentNote)),
      ];
}
