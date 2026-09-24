import 'package:smf_contracts/smf_contracts.dart';

/// Routing libraries that the bindings of a [RouteGuard] can target.
enum RoutingMode {
  /// The auto_route package.
  autoRouter._('auto_router'),

  /// The go_router package.
  goRouter._('go_router');

  const RoutingMode._(this.mode);

  /// Identifier of the routing library, for example `'go_router'`.
  final String mode;
}
