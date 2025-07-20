enum RouteMetaType { tabBar, pageView }

class RouteMeta {
  const RouteMeta({
    required this.label,
    required this.type,
    this.icon,
    this.order,
  });

  factory RouteMeta.tab({
    required String label,
    required String icon,
    int? order,
  }) => RouteMeta(
    label: label,
    icon: icon,
    type: RouteMetaType.tabBar,
    order: order,
  );

  final String label;
  final String? icon;
  final int? order;
  final RouteMetaType type;
}
