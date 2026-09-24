import 'package:smf_contracts/smf_contracts.dart';

/// The navigation shells that nested routes can link to, keyed by shell id.
///
/// A [NestedRoute] refers to its shell only by [RouteShellLink.id]; the CLI
/// and the routing module look that id up here to find the shell's widget
/// and file. Generation fails for a link whose id is not registered.
class ShellRegistry {
  static final _shells = <String, ShellDeclaration>{
    'main-tabs': const ShellDeclaration(
      id: 'main-tabs',
      type: ShellType.tabBar,
      screen: RouteScreen('MainTabsShell'),
      widgetFilePath: 'core/widgets/main_tabs_shell.dart',
    ),
  };

  /// Returns the shell registered under [id], or `null` if there is none.
  ///
  /// Every lookup of an id returns the same instance, so declarations can be
  /// used as map keys.
  static ShellDeclaration? resolve(String id) => _shells[id];
}
