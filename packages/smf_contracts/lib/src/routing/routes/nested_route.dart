import 'package:smf_contracts/src/routing/routing.dart';

/// Routes shown inside a navigation shell, such as tabs of the main tab bar.
///
/// A module adds, for example, its own tab by linking a nested route to the
/// shell. The routing module merges the nested routes of all modules that
/// link to the same shell, so the shell shows the children of all of them.
class NestedRoute extends BaseRoute {
  /// Creates the routes [children], shown inside the shell of [shellLink].
  const NestedRoute({
    required this.children,
    required this.shellLink,
    super.guards,
    super.imports,
  });

  /// The routes shown inside the shell; in a tab-bar shell, each child is a
  /// tab and needs a [Route.meta].
  final List<Route> children;

  /// The shell that shows [children].
  final RouteShellLink shellLink;
}
