import 'package:smf_bottom_tabs/bundles/bottom_tabs_bundle.dart';
import 'package:smf_bottom_tabs/src/agents.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The module of the main navigation of the app as tabs in a bar at the
/// bottom, and so a provider of the layout role.
///
/// It generates `AppShell` in `lib/core/layout/app_shell.dart`: a
/// `Scaffold` with the screen of the selected destination as its body and,
/// below it, a bar that the file draws itself, with a tab for each
/// destination of the app: its icon over its label, below a hairline. The
/// selected tab differs from the others only in its colour, the secondary
/// colour of the theme, which it takes over a moment, so no tab changes its
/// size. A tap on a tab calls `onSelect` with its index, with the tick of a
/// selection on the device when it is another tab, and the screen of the
/// new destination fades in while it rises a little. With one destination
/// there is nothing to switch to, so the bar is hidden.
///
/// The bar brings what a bar of Flutter would. Each tab is one button for a
/// screen reader, with the label of its destination, selected or not. The
/// bar is 64 high and grows with labels that need more. The text size of
/// the device scales a label at most 1.3 times, and a long press on a tab
/// shows its label in a tooltip at the full size. For a user who asks for
/// less motion, the tab and the screen change at once.
///
/// The router of the app builds the shell from the destinations that the
/// features declare, in the order of the features, and keeps the stack of
/// each tab; an app without destinations has no shell. The bar shows at
/// most [maxDestinations]. With more, `smf create` leaves out the features
/// of the destinations that do not fit, each with a warning, and generates
/// the app without them; with `--strict`, it stops instead. The section of
/// the layout in the guide for coding agents says so for the destinations
/// that are added by hand.
final class BottomTabsModule extends SmfModule {
  /// Creates the module.
  const BottomTabsModule();

  /// The id of the module.
  static const id = ModuleId('bottom_tabs');

  /// The most destinations the bar shows, as the guidelines of Material
  /// Design advise for a bar at the bottom: more tabs get too narrow for
  /// their labels on a phone.
  static const maxDestinations = 5;

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Tabs in a bar at the bottom of the app',
        kind: ModuleKinds.layout,
        providers: [_BottomTabsProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bottomTabsBundle),
        AppEntryRole.agentSections.entry(
          layoutRole.description,
          AgentNote(agentNote),
        ),
      ];
}

/// Provides the layout role with at most [BottomTabsModule.maxDestinations].
final class _BottomTabsProvider extends LayoutProvider {
  const _BottomTabsProvider();

  @override
  int get maxDestinations => BottomTabsModule.maxDestinations;
}
