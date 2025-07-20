import 'package:smf_contracts/smf_contracts.dart';

class RouteGroup {
  const RouteGroup(this.routes, {this.coreGuards = const []});

  factory RouteGroup.empty() => const RouteGroup([]);

  final List<BaseRoute> routes;
  final List<RouteGuard> coreGuards;
}
