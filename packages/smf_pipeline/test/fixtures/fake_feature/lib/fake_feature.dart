/// A fake feature for the tests of the SMF pipeline. Not a module to use.
///
/// It has a start route with a child that takes a path and a query
/// parameter, a destination of the main navigation, a variant for each
/// fake state manager, and a composition file that resolves a service, so
/// it uses the navigation facade, the annotation sockets of the router, and
/// the rules for resolving services.
library;

import 'package:fake_feature/bundles/fake_feature_bloc_bundle.dart';
import 'package:fake_feature/bundles/fake_feature_bundle.dart';
import 'package:fake_feature/bundles/fake_feature_riverpod_bundle.dart';
import 'package:smf_contracts/lego.dart';

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
