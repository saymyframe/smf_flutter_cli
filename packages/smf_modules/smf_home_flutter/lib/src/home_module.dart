import 'package:smf_contracts/lego.dart';
import 'package:smf_home_flutter/bundles/home_bundle.dart';

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
/// As a feature, the module requires the router role, whichever module
/// provides it, and keeps its file in `lib/features/home/`. The screen has
/// no state, so the module has no variants for the modules that manage
/// state.
final class HomeModule extends SmfModule {
  /// Creates the module.
  const HomeModule();

  /// The id of the module.
  static const id = ModuleId('home');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Start screen with the name of the app',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(homeBundle),
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
                label: 'Home',
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
      ];
}
