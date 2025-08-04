import 'package:flutter/material.dart';
import 'package:{{app_name.snakeCase()}}/core/services/navigation/go_router_navigation_service.dart';
import 'package:{{app_name.snakeCase()}}/core/services/navigation/navigation_service.dart';

extension NavigationContextExtension on BuildContext {
  Future<void> navigateTo(
    NavigationTarget target, {
    NavigationStrategy strategy = NavigationStrategy.push,
    NavigationService service = const GoRouterNavigationService(),
  }) {
    return service.navigateTo(this, target, strategy: strategy);
  }
}
