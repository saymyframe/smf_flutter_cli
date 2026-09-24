import 'package:smf_contracts/smf_contracts.dart';

/// Renders the tabs of a tab bar shell, such as `MainTabsShell`, as the
/// `_TabInfo` entries of its tabs list.
class TabsShellGenerator {
  /// Creates a tabs shell generator.
  const TabsShellGenerator();

  /// One `_TabInfo(...)` entry per route in [routes], with the path of the
  /// route and the label and icon of its `RouteMeta`. Tabs are ordered by
  /// `RouteMeta.order`; tabs without one come last.
  ///
  /// Throws a [StateError] for a route without `RouteMeta`.
  String generate({
    required ShellDeclaration declaration,
    required List<Route> routes,
  }) {
    final tabInfos = routes.map(_extractTabInfo).toList()
      ..sort(
        (a, b) => (a.order ?? double.maxFinite).compareTo(
          b.order ?? double.maxFinite,
        ),
      );

    return tabInfos.map((tab) => '$tab\n').join();
  }

  _TabInfo _extractTabInfo(Route route) {
    final meta = route.meta;
    if (meta == null) {
      throw StateError(
        'Route ${route.name} must define RouteMeta to be used in '
        'main-tabs shell',
      );
    }

    return _TabInfo(
      path: route.path,
      label: meta.label,
      icon: meta.icon,
      order: meta.order,
    );
  }
}

/// Internal representation for generation.
class _TabInfo {
  _TabInfo({
    required this.path,
    required this.label,
    required this.icon,
    this.order,
  });

  final String path;
  final String? label;
  final String icon;
  final int? order;

  @override
  String toString() {
    if (label == null) {
      return '_TabInfo(path: "$path", icon: $icon),';
    }

    return '_TabInfo(path: "$path", label: "$label", icon: $icon),';
  }
}
