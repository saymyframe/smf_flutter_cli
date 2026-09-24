enum ParameterSource { path, query }

class RouteScreenArgs {
  const RouteScreenArgs({
    required this.name,
    required this.sourceName,
    required this.source,
    this.isNamed = true,
  });

  final String name;
  final String sourceName;
  final ParameterSource source;
  final bool isNamed;
}
