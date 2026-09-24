import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/nested_route_strategy.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy.dart';
import 'package:smf_go_router/src/route_generator/single_route_strategy.dart';

class RouteGenerationStrategyRegistry {
  static final _strategies = <Type, RouteGenerationStrategy>{
    Route: SingleRouteStrategy(),
    NestedRoute: NestedRouteStrategy(),
  };

  static String generate(BaseRoute route, RouteGenerationContext context) {
    final strategy = _strategies[route.runtimeType];

    if (strategy == null) {
      throw UnsupportedError('No strategy for ${route.runtimeType}');
    }

    return strategy.generate(route, context);
  }

  static List<String> imports(BaseRoute route, RouteGenerationContext context) {
    final strategy = _strategies[route.runtimeType];

    if (strategy == null) {
      throw UnsupportedError('No strategy for ${route.runtimeType}');
    }

    return strategy.imports(route, context);
  }
}
