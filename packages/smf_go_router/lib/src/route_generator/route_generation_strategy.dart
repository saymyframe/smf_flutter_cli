import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';

abstract interface class RouteGenerationStrategy<T extends BaseRoute> {
  String generate(T route, RouteGenerationContext context);

  List<String> imports(T route, RouteGenerationContext context);
}
