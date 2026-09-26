import 'package:smf_bottom_tabs/bundles/bottom_tabs_bundle.dart';
import 'package:smf_contracts/lego.dart';

/// The module of the main navigation of the app as tabs in a bar at the
/// bottom, and so a provider of the layout role.
///
/// It generates `AppShell` in `lib/core/layout/app_shell.dart`: a
/// `Scaffold` with the screen of the selected destination as its body and a
/// Material 3 `NavigationBar` with a tab for each destination of the app,
/// with its icon and label. With one destination there is nothing to switch
/// to, so the bar is hidden. Selecting a tab calls `onSelect` with its
/// index.
///
/// The router of the app builds the shell from the destinations that the
/// features declare, in the order of the features, and keeps the stack of
/// each tab; an app without destinations has no shell. The bar shows at
/// most [maxDestinations], so `smf create` stops before it generates an app
/// with more.
final class BottomTabsModule extends SmfModule {
  /// Creates the module.
  const BottomTabsModule();

  /// The id of the module.
  static const id = ModuleId('bottom_tabs');

  /// The most destinations the bar shows, as the guidelines of Material
  /// Design advise for a navigation bar.
  static const maxDestinations = 5;

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Tabs in a bar at the bottom of the app',
        kind: ModuleKinds.layout,
        providers: [_BottomTabsProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(bottomTabsBundle)];
}

/// Provides the layout role with at most [BottomTabsModule.maxDestinations].
final class _BottomTabsProvider extends LayoutProvider {
  const _BottomTabsProvider();

  @override
  int get maxDestinations => BottomTabsModule.maxDestinations;
}
