import 'package:smf_contracts/src/routing/routing.dart';

class RouteDefinition extends BaseRoute {
  const RouteDefinition({
    required this.path,
    required super.screen,
    this.parameters = const [],
    this.imports = const [],
    this.meta,
    this.shellLink,
    super.name,
    super.guards,
  });

  final String path;
  final List<RouteParameter> parameters;
  final List<RouteImport> imports;
  final RouteMeta? meta;
  final RouteShellLink? shellLink;
}
