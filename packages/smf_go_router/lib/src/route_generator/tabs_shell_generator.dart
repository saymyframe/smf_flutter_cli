import 'package:smf_contracts/smf_contracts.dart';

class TabsShellGenerator {
  const TabsShellGenerator();

  String generate({
    required ShellDeclaration declaration,
    required List<Route> routes,
  }) {
    final buffer = StringBuffer();

    final tabInfos = routes.map(_extractTabInfo).toList()
      ..sort(
        (a, b) => (a.order ?? double.maxFinite).compareTo(
          b.order ?? double.maxFinite,
        ),
      );
    for (final tab in tabInfos) {
      buffer.writeln(tab);
    }

    return buffer.toString();
  }

  _TabInfo _extractTabInfo(Route route) {
    final meta = route.meta;
    if (meta == null) {
      throw StateError(
        'Route ${route.name} must define RouteMeta to be used in main-tabs shell',
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
