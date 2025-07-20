abstract class RouteParameter {
  const RouteParameter(this.name, {required this.type, this.optional = false});

  final String name;
  final Type type;
  final bool optional;
}
