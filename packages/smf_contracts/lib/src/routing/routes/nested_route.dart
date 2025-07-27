import 'package:smf_contracts/src/routing/routing.dart';

class NestedRoute extends BaseRoute {
  const NestedRoute({
    required this.children,
    required this.shellLink,
    super.guards,
    super.imports,
  });

  final List<Route> children;
  final RouteShellLink shellLink;
}
