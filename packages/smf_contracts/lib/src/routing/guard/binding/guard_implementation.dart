import 'package:smf_contracts/smf_contracts.dart';

/// The code of a [RouteGuard] for one routing library.
///
/// Each subclass targets one [RoutingMode]: [GoRouteRedirect] for go_router
/// and [AutoRouteGuard] for auto_route.
abstract class GuardImplementation {
  /// Creates an implementation from [code] and the [imports] it needs.
  const GuardImplementation({required this.code, this.imports = const []});

  /// Dart source of the guard in the form its routing library expects; see
  /// the subclasses.
  final String code;

  /// Imports that [code] needs, added to the generated router file.
  final List<Import> imports;
}
