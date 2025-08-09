enum RoutingMode {
  autoRouter._('auto_router'),
  goRouter._('go_router');

  const RoutingMode._(this.mode);

  final String mode;
}
