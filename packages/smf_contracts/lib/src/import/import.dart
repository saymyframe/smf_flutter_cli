import 'package:smf_contracts/smf_contracts.dart';

/// A Dart import that generated code needs, declared in the DSL.
///
/// Routes, guards and DI groups carry the imports of the code they
/// contribute; generators turn them into statements with [resolve] and add
/// them to the generated file. Use [Import.core] or [Import.features] for
/// files of the generated app, which fill in the app's package name, and
/// [Import.direct] for everything else.
class Import {
  /// Imports [import], a path relative to the [anchor] directory of the
  /// generated app, such as `'analytics/i_analytics_service.dart'` under
  /// [ImportAnchor.coreService].
  // ignore: tighten_type_of_initializing_formals, keeps the public signature.
  const Import.core(this.anchor, this.import)
      : assert(anchor != null, 'Import.core needs an anchor.');

  /// Uses [import], a complete import statement such as
  /// `"import 'package:event_bus/event_bus.dart';"`, as is.
  ///
  /// [resolve] only trims it and adds a missing semicolon.
  const Import.direct(this.import) : anchor = null;

  /// Imports [import], a path relative to the app's `lib/features/`
  /// directory, such as `'home/home_screen.dart'`.
  const Import.features(this.import) : anchor = ImportAnchor.features;

  /// Directory of the generated app that [import] is relative to, or `null`
  /// for an [Import.direct] statement.
  final ImportAnchor? anchor;

  /// Path relative to [anchor], or the complete statement of an
  /// [Import.direct] import.
  final String import;

  /// Returns the import statement, ending with a semicolon.
  ///
  /// An anchored import becomes a `package:{{app_name_sc}}/...` URI without
  /// the leading `lib/`. The generators render the `{{app_name_sc}}`
  /// placeholder with [DslContext.mustacheVariables].
  String resolve() {
    String addSemicolonIfMissing(String import) {
      return import.endsWith(';') ? import : '$import;';
    }

    // Package URIs start below lib/, so only a leading lib/ is dropped.
    String stripLib(String path) {
      return path.startsWith('lib/') ? path.substring('lib/'.length) : path;
    }

    final cleanedImport = stripLib(import);
    const package = "import 'package:{{app_name_sc}}";
    if (anchor != null) {
      final cleanedAnchor = stripLib(anchor!.path);
      return addSemicolonIfMissing("$package/$cleanedAnchor$cleanedImport'");
    }

    return addSemicolonIfMissing(import.trim());
  }
}
