import 'package:smf_contracts/smf_contracts.dart';

class RouteGroup {
  const RouteGroup({required this.routes, this.coreGuards = const []});

  factory RouteGroup.empty() => const RouteGroup(routes: []);

  final List<BaseRoute> routes;
  final List<RouteGuard> coreGuards;
}
