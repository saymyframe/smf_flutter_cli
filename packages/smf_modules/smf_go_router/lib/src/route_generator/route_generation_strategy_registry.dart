import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/nested_route_strategy.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy.dart';
import 'package:smf_go_router/src/route_generator/single_route_strategy.dart';

/// Picks the [RouteGenerationStrategy] for a route by its exact runtime type:
/// [SingleRouteStrategy] for a [Route], [NestedRouteStrategy] for a
/// [NestedRoute].
class RouteGenerationStrategyRegistry {
  static final _strategies = <Type, RouteGenerationStrategy>{
    Route: SingleRouteStrategy(),
    NestedRoute: NestedRouteStrategy(),
  };

  /// Renders [route] with the strategy for its type.
  ///
  /// Throws an [UnsupportedError] for a route type without a strategy.
  static String generate(BaseRoute route, RouteGenerationContext context) {
    final strategy = _strategies[route.runtimeType];

    if (strategy == null) {
      throw UnsupportedError('No strategy for ${route.runtimeType}');
    }

    return strategy.generate(route, context);
  }

  /// The imports of [route], collected by the strategy for its type.
  ///
  /// Throws an [UnsupportedError] for a route type without a strategy.
  static List<String> imports(BaseRoute route, RouteGenerationContext context) {
    final strategy = _strategies[route.runtimeType];

    if (strategy == null) {
      throw UnsupportedError('No strategy for ${route.runtimeType}');
    }

    return strategy.imports(route, context);
  }
}
