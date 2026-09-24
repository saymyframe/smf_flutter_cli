import 'package:smf_contracts/smf_contracts.dart';

/// Kinds of navigation shell.
enum ShellType {
  /// A shell with a tab bar, where each child route is a tab.
  tabBar,

  /// A shell that shows its child routes as pages of a page view.
  pageView,
}

/// A navigation shell: a widget around the child routes of every
/// [NestedRoute] linked to it.
///
/// Shells are declared in [ShellRegistry]; modules link to them with a
/// [RouteShellLink].
class ShellDeclaration {
  /// Declares the shell [id] of the given [type].
  const ShellDeclaration({
    required this.id,
    required this.type,
    required this.screen,
    required this.widgetFilePath,
  });

  /// Id that a [RouteShellLink] refers to, for example `'main-tabs'`.
  final String id;

  /// The kind of shell.
  final ShellType type;

  /// The shell widget, which the router constructs with the current child
  /// route as its `child` argument.
  final RouteScreen screen;

  /// Path of the shell widget's file relative to the app's `lib/`
  /// directory, for example `'core/widgets/main_tabs_shell.dart'`.
  ///
  /// The routing module's brick provides this file with a slot for the
  /// shell's entries, such as [MustacheSlots.tabsWidget], and the router
  /// imports it. The file is removed when no route links to the shell.
  final String widgetFilePath;
}
