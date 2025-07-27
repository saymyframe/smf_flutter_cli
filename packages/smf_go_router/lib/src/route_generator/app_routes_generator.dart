import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/utils/string_ext.dart';

class AppRoutesGenerator {
  String generateAppRoutes(List<Route> routes) {
    final buffer = StringBuffer();
    final seen = <String>{};

    for (final route in routes) {
      final pathConstName = _safeRouteConst(
        route.name ?? _pathToConstName(route.path),
        suffix: 'Path',
      );
      final nameConstName = route.name;

      if (!seen.contains(pathConstName)) {
        buffer.writeln("  static const $pathConstName = '${route.path}';");
        seen.add(pathConstName);
      }

      if (nameConstName != null && !seen.contains(nameConstName)) {
        buffer.writeln("  static const $nameConstName = '$nameConstName';");
        seen.add(nameConstName);
      }
    }

    return buffer.toString();
  }

  String _pathToConstName(String path) {
    return path
        .replaceAll('/', '')
        .replaceAll(':', '')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        .camelCase();
  }

  String _safeRouteConst(String value, {String suffix = ''}) {
    return '${value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').camelCase()}$suffix';
  }
}
