import 'package:smf_contracts/smf_contracts.dart';

class ShellRegistry {
  static final _shells = <String, ShellDeclaration>{
    'main-tabs': const ShellDeclaration(
      id: 'main-tabs',
      type: ShellType.tabBar,
      screen: RouteScreen('MainTabsShell'),
      widgetFilePath: 'core/widgets/main_tabs_shell.dart',
    ),
  };

  static ShellDeclaration? resolve(String id) => _shells[id];
}
