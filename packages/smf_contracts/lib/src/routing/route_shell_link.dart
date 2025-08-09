class RouteShellLink {
  const RouteShellLink(this.id);

  factory RouteShellLink.toMainTabsShell() => const RouteShellLink('main-tabs');

  final String id;
}
