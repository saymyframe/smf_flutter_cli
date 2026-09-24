import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';

/// Renders one kind of [BaseRoute] as go_router code.
abstract interface class RouteGenerationStrategy<T extends BaseRoute> {
  /// The go_router route for [route] as an entry of a `routes` list,
  /// trailing comma included.
  String generate(T route, RouteGenerationContext context);

  /// The resolved import directives the code of [generate] needs.
  List<String> imports(T route, RouteGenerationContext context);
}
