class RouteContext {
  const RouteContext({required this.pathParams, required this.queryParams});

  final Map<String, String> pathParams;
  final Map<String, String?> queryParams;

  T getPathParam<T>(String name) {
    final value = pathParams[name];
    if (value == null) {
      throw ArgumentError('Missing path param $name');
    }

    return _cast<T>(value);
  }

  T? getQueryParam<T>(String name) {
    final value = queryParams[name];
    return value == null ? null : _cast<T>(value);
  }

  T _cast<T>(String value) {
    if (T == String) return value as T;
    if (T == int) return int.parse(value) as T;
    if (T == double) return double.parse(value) as T;
    if (T == bool) return (value.toLowerCase() == 'true') as T;
    throw UnsupportedError('Unsupported type $T');
  }
}
