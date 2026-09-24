import 'package:meta/meta.dart';

@immutable
class RouteShellLink {
  const RouteShellLink(this.id);

  factory RouteShellLink.toMainTabsShell() => const RouteShellLink('main-tabs');

  final String id;

  /// Links are equal when they point to the same shell, so routes that
  /// separate modules link to one shell end up in the same shell.
  @override
  bool operator ==(Object other) => other is RouteShellLink && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
