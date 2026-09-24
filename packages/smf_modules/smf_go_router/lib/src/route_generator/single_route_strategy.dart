import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/route_generator/redirects_generator.dart';
import 'package:smf_go_router/src/route_generator/route_generation_context.dart';
import 'package:smf_go_router/src/route_generator/route_generation_strategy.dart';

class SingleRouteStrategy implements RouteGenerationStrategy<Route> {
  @override
  String generate(Route route, RouteGenerationContext context) {
    final path = route.path;
    final name = route.name;
    final redirectsCode = RedirectsGenerator.generateCombinedRedirectCode(
      route.guards,
    );

    return '''
    GoRoute(
      path: '$path',
      ${_routeName(name)}
      ${_buildRouteScreen(route)}
      redirect: $redirectsCode,
    ),
    ''';
  }

  String _buildRouteScreen(Route route) {
    if (route.screen == null) {
      return '';
    }

    final screen = route.screen?.className;
    final args = _formatConstructorArgs(
      route.screen!.screenArguments,
      route.parameters,
    );

    return 'builder: (context, state) => $screen($args),';
  }

  String _formatConstructorArgs(
    List<RouteScreenArgs> args,
    List<RouteParameter> parameters,
  ) {
    final paramMap = {for (final p in parameters) p.name: p};

    return args
        .map((arg) {
          final param = paramMap[arg.sourceName];
          if (param == null) {
            throw ArgumentError(
              'Missing RouteParameter for screen argument ${arg.sourceName}',
            );
          }

          final rawSource = _sourceExpr(arg);
          final value = _castExpr(rawSource, param.type, param.optional);

          return arg.isNamed ? '${arg.name}: $value' : value;
        })
        .join(', ');
  }

  String _sourceExpr(RouteScreenArgs arg) {
    switch (arg.source) {
      case ParameterSource.path:
        return "state.pathParameters['${arg.sourceName}']";
      case ParameterSource.query:
        return "state.uri.queryParameters['${arg.sourceName}']";
    }
  }

  String _castExpr(String raw, Type type, bool optional) {
    final safe = optional ? raw : '$raw!';

    if (type == int) return 'int.parse($safe)';
    if (type == double) return 'double.parse($safe)';
    if (type == bool) return '$safe == "true"';

    return safe; // default: String, or fallback
  }

  @override
  List<String> imports(Route route, RouteGenerationContext context) {
    return route.imports.map((i) => i.resolve()).toList();
  }

  String _routeName(String? name) {
    if (name?.isEmpty ?? true) {
      return '';
    }

    return 'name: AppRoutes.$name,';
  }
}
