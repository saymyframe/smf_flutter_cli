class RouteShellLink {
  const RouteShellLink(this.shellName);

  factory RouteShellLink.toMainTabsShell() =>
      const RouteShellLink('MainTabsShell');

  final String shellName;
}
