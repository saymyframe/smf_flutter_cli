import 'package:smf_contracts/src/routing/guard/binding/binding.dart';

/// A guard implementation for projects routed with the auto_route package
/// (`RoutingMode.autoRouter`).
class AutoRouteGuard extends GuardImplementation {
  /// Creates a binding to the guard class [className]; [code] is the
  /// expression that creates an instance of it, such as `'AuthGuard()'`.
  AutoRouteGuard({required this.className, required super.code, super.imports});

  /// Name of the guard class, which implements auto_route's `AutoRouteGuard`.
  final String className;
}
