/// The tests that the matrix of CI adds to the apps of the fixture modules,
/// which this package keeps in its `app_tests`, and the roles whose
/// contract they check with every provider; `tool/matrix.dart` runs them.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// The tests of the apps of the fixture modules, and the roles whose
/// contract they check with every provider: the router role and the layout
/// role, whose providers call the listeners of the screen.
///
/// They select the apps with a provider of a role by the roles of the app,
/// whichever module provides it, and name the fixture modules whose files
/// they use: the fixture features and the fixture analytics, whose
/// listener of the screen notes what it hears.
Future<MatrixAppTests> fixtureAppTests() async {
  final appTests = await appTestsDirectoryOf('fixture_registry');
  return MatrixAppTests(
    [
      // The listeners of the screen, whichever module provides the router:
      // the test starts the app with main() and navigates through the
      // navigation facade of the router role.
      MatrixAppTest(
        '$appTests/router_screens',
        appliesTo: _hearsScreens,
        roles: {routerRole},
      ),
      // The listeners of the screen as the user switches between the
      // destinations of the two fixture features, whichever modules provide
      // the router and the layout: the test selects a destination through
      // the AppShell of the layout role. The apps it applies to have the
      // tests of router_screens, whose helpers it uses.
      MatrixAppTest(
        '$appTests/layout_screens',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.hook!.presentRoles.contains(layoutRole) &&
            app.modules.contains(const ModuleId('fake_second')),
        roles: {routerRole, layoutRole},
      ),
      // What only go_router does: a refresh of its routes, which the
      // listeners of the screen do not hear of. It checks no role, so it
      // names its module, as `tools/app_tests_test.dart` lets it. The apps
      // it applies to have the tests of router_screens, whose helpers it
      // uses.
      MatrixAppTest(
        '$appTests/go_router_screens',
        appliesTo: (app) =>
            _hearsScreens(app) &&
            app.modules.contains(const ModuleId('go_router')),
      ),
    ],
    testedRoles: {routerRole, layoutRole},
  );
}

/// Whether the tests of the listeners of the screen can hear the screens of
/// [app]: it has a router, whichever module provides it, the fixture
/// feature, whose screens they navigate between, and the fixture
/// analytics, whose listener of the screen notes each.
bool _hearsScreens(MatrixApp app) =>
    app.hook!.presentRoles.contains(routerRole) &&
    app.modules.contains(const ModuleId('fake_feature')) &&
    app.modules.contains(const ModuleId('fake_analytics'));
