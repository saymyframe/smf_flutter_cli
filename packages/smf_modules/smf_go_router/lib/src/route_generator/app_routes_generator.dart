import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/utils/string_ext.dart';

/// Renders the body of the `AppRoutes` class: the constants the generated
/// router and app code use to refer to routes.
class AppRoutesGenerator {
  /// Declares, for each of [routes], a path constant holding its path
  /// template and, for a named route, a constant holding the name as is,
  /// which the router refers to as `AppRoutes.<name>`.
  ///
  /// The path constant is the name, or for an unnamed route the path,
  /// camelCased with a `Path` suffix: `homeScreen` gives `homeScreenPath` and
  /// `/user-profile/:id` gives `userProfileIdPath`. An empty name counts as
  /// no name. When several routes produce the same constant, only the first
  /// one declares it.
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
