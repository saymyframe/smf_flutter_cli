import 'package:smf_contracts/smf_contracts.dart';

/// Named slots that brick templates leave open for DSL generators to fill.
///
/// A brick shields the slot from mason's own rendering with a delimiter
/// switch (`{{=<% %>=}}`), so the file it generates still contains a
/// mustache section such as `{{#imports}}{{{.}}}{{/imports}}`. A
/// [DslAwareCodeGenerator] then renders that file again with the [slot] key
/// bound to the code it generated from the DSL of all modules.
enum MustacheSlots {
  /// Import statements that the generated code needs.
  imports._('imports'),

  /// Start-up code of the app's `main` function.
  bootstrap._('bootstrap'),

  /// The router configuration.
  router._('router'),

  /// Constants with the paths and names of the app's routes.
  appRoutes._('appRoutes'),

  /// DI registration statements.
  di._('di'),

  /// The tabs of a [ShellType.tabBar] navigation shell.
  tabsWidget._('tabsWidget'),

  /// The pages of a [ShellType.pageView] navigation shell.
  pagesWidget._('pagesWidget');

  const MustacheSlots._(this.slot);

  /// Key of the slot in templates, for example `'imports'`.
  final String slot;
}
