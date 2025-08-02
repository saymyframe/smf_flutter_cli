import 'package:smf_contracts/smf_contracts.dart';

class RouteGroup {
  const RouteGroup({
    required this.routes,
    this.initialRoute,
    this.coreGuards = const [],
  });

  factory RouteGroup.empty() => const RouteGroup(routes: []);

  final String? initialRoute;
  final List<BaseRoute> routes;
  final List<RouteGuard> coreGuards;
}
