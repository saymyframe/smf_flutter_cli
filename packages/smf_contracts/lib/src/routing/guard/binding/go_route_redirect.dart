import 'package:smf_contracts/smf_contracts.dart';

/// A guard implementation for projects routed with go_router
/// ([RoutingMode.goRouter]), rendered into a `redirect` callback.
///
/// [code] is a Dart expression evaluated inside
/// `redirect: (context, state) { ... }`, so it can use `context` and
/// `state`, for example `'authGuard(context, state)'`. It must evaluate to a
/// `String?`: the location to redirect to, or `null` to let the navigation
/// continue. When several guards apply, they run in order and the first
/// location returned wins.
class GoRouteRedirect extends GuardImplementation {
  /// Creates a go_router redirect from the expression [code].
  GoRouteRedirect({required super.code, super.imports});
}
