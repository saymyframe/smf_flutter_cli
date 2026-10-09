part of '../contributions.dart';

/// Checks of the machine that a module needs before generation, such as an
/// installed and logged-in Firebase CLI.
///
/// The pipeline runs the checks after validation, in the order of the list.
/// In an interactive run it offers to install what is missing; otherwise it
/// prints instructions. See [PreflightCheck].
///
/// The checks of a module run after those of the modules it depends on
/// ([ModuleDescriptor.dependsOn]), directly or not, whether the user named
/// those modules or the pipeline added them. So a check may build on what a
/// check of such a module installs, as a check of the version of a tool
/// does on the check that installs the tool: after an installation, the
/// pipeline runs again the checks after it that have not passed. The checks
/// of modules that do not depend on each other run in the order of the
/// modules of the app.
final class Preflight extends Contribution {
  /// Creates the preflight of a module with [checks].
  const Preflight(this.checks, {super.when});

  /// The checks, run in this order.
  final List<PreflightCheck> checks;
}
