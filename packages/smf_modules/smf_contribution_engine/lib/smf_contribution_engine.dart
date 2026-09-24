/// Patches existing Dart files: adds imports and statements, inserts list
/// elements, replaces widgets and edits their arguments.
///
/// Each change is a `Contribution` that finds its target in the parsed file.
/// `PatchEngine` applies contributions to a project and renders the Mustache
/// placeholders in the text they insert.
library;

export 'src/contribution.dart';
export 'src/contributions/contributions.dart';
export 'src/smf_patch_engine.dart';
