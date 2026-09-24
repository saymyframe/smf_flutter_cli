import 'package:meta/meta.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// A reference from a [NestedRoute] to a navigation shell, by shell id.
///
/// The id is resolved with [ShellRegistry] during generation.
@immutable
class RouteShellLink {
  /// Creates a link to the shell registered under [id].
  const RouteShellLink(this.id);

  /// A link to the app's main tab-bar shell.
  factory RouteShellLink.toMainTabsShell() => const RouteShellLink('main-tabs');

  /// Id of the linked shell in [ShellRegistry].
  final String id;

  /// Links are equal when they point to the same shell, so routes that
  /// separate modules link to one shell end up in the same shell.
  @override
  bool operator ==(Object other) => other is RouteShellLink && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
