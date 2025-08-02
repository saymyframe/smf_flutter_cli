import 'package:smf_contracts/smf_contracts.dart';

abstract class BaseRoute {
  const BaseRoute({
    this.screen,
    this.name,
    this.guards = const [],
    this.imports = const [],
  });

  final String? name;
  final RouteScreen? screen;
  final List<RouteGuard> guards;
  final List<Import> imports;
}
