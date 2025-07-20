import 'package:smf_contracts/src/routing/routing.dart';

class NestedRoute extends BaseRoute {
  const NestedRoute({
    required this.path,
    required this.children,
    super.name,
    super.guards = const [],
  });

  final String path;
  final List<BaseRoute> children;
}
