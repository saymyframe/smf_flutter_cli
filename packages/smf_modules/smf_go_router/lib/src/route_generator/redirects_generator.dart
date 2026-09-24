import 'package:smf_contracts/smf_contracts.dart';

/// Renders route guards as a go_router `redirect` callback.
class RedirectsGenerator {
  /// A `(context, state) { ... }` callback that evaluates the go_router
  /// redirect code of [guards] in order and returns the first non-null
  /// location, or `null` to allow navigation.
  ///
  /// Throws an [ArgumentError] naming the index of a guard without a
  /// [GoRouteRedirect] binding.
  static String generateCombinedRedirectCode(List<RouteGuard> guards) {
    final redirects = <String>[];

    for (var i = 0; i < guards.length; i++) {
      final guard = guards[i];
      final impl = guard.bindings[RoutingMode.goRouter];

      if (impl is! GoRouteRedirect) {
        throw ArgumentError(
          'Guard $i does not have a valid GoRouteRedirect binding',
        );
      }

      final func = impl.code.trim();
      final varName = 'r$i';

      redirects
        ..add('final $varName = $func;')
        ..add('if ($varName != null) return $varName;');
    }

    redirects.add('return null;');

    return '''
    (context, state) {
      ${redirects.join('\n  ')}
    }''';
  }
}
