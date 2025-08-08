import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name.snakeCase()}}/core/services/navigation/navigation_service.dart';

class GoRouterNavigationService implements NavigationService {
  const GoRouterNavigationService();

  @override
  Future<T?> navigateTo<T extends Object?>(
    BuildContext context,
    NavigationTarget target, {
    NavigationStrategy strategy = NavigationStrategy.push,
  }) async {
    final uri = _buildUri(target);

    switch (strategy) {
      case NavigationStrategy.push:
        return GoRouter.of(context).push(uri.toString(), extra: target.extra);

      case NavigationStrategy.pushReplacement:
        return GoRouter.of(
          context,
        ).pushReplacement(uri.toString(), extra: target.extra);
    }
  }

  Uri _buildUri(NavigationTarget target) {
    var path = target.routeName;
    for (final entry in target.pathParams.entries) {
      path = path.replaceAll(
        ':${entry.key}',
        Uri.encodeComponent(entry.value.toString()),
      );
    }

    return Uri(
      path: path,
      queryParameters: target.queryParams.isEmpty
          ? null
          : {
              for (final entry in target.queryParams.entries)
                entry.key: entry.value.toString(),
            },
    );
  }
}
