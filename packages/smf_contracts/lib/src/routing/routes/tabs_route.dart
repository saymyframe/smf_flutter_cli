import 'package:smf_contracts/src/routing/routing.dart';

class TabsRoute extends BaseRoute {
  const TabsRoute({required this.children, super.name, super.guards});

  final List<BaseRoute> children;
}
