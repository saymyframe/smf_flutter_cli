import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/utils/string_ext.dart';

class AppRoutesGenerator {
  String generateAppRoutes(List<Route> routes) {
    final buffer = StringBuffer();
    final seen = <String>{};

    for (final route in routes) {
      // Like the router, treat an empty name as no name.
      final nameConstName = (route.name?.isEmpty ?? true) ? null : route.name;
      // camelCase splits on every non-alphanumeric character, so a path
      // gives one word per segment: '/user-profile/:id' -> 'userProfileId'.
      final pathConstName = '${(nameConstName ?? route.path).camelCase()}Path';

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
}
