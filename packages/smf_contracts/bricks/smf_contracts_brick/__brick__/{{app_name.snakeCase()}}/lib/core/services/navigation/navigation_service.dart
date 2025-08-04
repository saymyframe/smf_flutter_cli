import 'package:flutter/material.dart';

enum NavigationStrategy { push, pushReplacement }

class NavigationTarget {
  final String routeName;
  final Map<String, dynamic> pathParams;
  final Map<String, dynamic> queryParams;
  final Object? extra;

  const NavigationTarget({
    required this.routeName,
    this.pathParams = const {},
    this.queryParams = const {},
    this.extra,
  });
}

abstract interface class NavigationService {
  Future<T?> navigateTo<T extends Object?>(
    BuildContext context,
    NavigationTarget target, {
    NavigationStrategy strategy = NavigationStrategy.push,
  });
}
