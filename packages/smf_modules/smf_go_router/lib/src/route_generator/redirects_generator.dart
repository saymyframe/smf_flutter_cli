import 'package:smf_contracts/smf_contracts.dart';

class RedirectsGenerator {
  static String generateCombinedRedirectCode(List<RouteGuard> guards) {
    final redirects = <String>[];

    for (int i = 0; i < guards.length; i++) {
      final guard = guards[i];
      final impl = guard.bindings[RoutingMode.goRouter];

      if (impl is! GoRouteRedirect) {
        throw ArgumentError(
          'Guard $i does not have a valid GoRouteRedirect binding',
        );
      }

      final func = impl.code.trim();
      final varName = 'r$i';

      redirects.add("final $varName = $func;");
      redirects.add("if ($varName != null) return $varName;");
    }

    redirects.add('return null;');

    return '''
    (context, state) {
      ${redirects.join('\n  ')}
    }''';
  }
}
