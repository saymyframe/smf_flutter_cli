import 'package:smf_contracts/src/routing/routing.dart';

class RouteGuard {
  const RouteGuard({required this.bindings});

  final Map<RoutingMode, GuardImplementation> bindings;
}
