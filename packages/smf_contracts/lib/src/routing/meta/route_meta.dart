import 'package:smf_contracts/smf_contracts.dart';

/// How a route appears as an entry of a navigation shell, such as a tab.
///
/// Every child of a [NestedRoute] linked to a [ShellType.tabBar] shell needs
/// one; generation fails otherwise.
class RouteMeta {
  /// Creates shell entry details with an [icon], [label] and [order].
  const RouteMeta({required this.icon, this.label, this.order});

  /// Dart expression of the entry's `IconData`, inserted into generated code
  /// as is, for example `'Icons.home'`.
  final String icon;

  /// Optional text label of the entry.
  final String? label;

  /// Position of the entry among the entries of the shell, which may come
  /// from several modules; lower values come first, and entries without an
  /// order come last.
  final int? order;
}
