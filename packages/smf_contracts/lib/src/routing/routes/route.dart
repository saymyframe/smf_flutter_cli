import 'package:smf_contracts/src/routing/routing.dart';

class Route extends BaseRoute {
  const Route({
    required this.path,
    super.screen,
    this.parameters = const [],
    this.meta,
    super.name,
    super.guards,
    super.imports,
  });

  final String path;
  final List<RouteParameter> parameters;
  final RouteMeta? meta;
}
