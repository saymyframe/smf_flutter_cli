part of '../contributions.dart';

/// Checks of the machine that a module needs before generation, such as an
/// installed and logged-in Firebase CLI.
///
/// The pipeline runs the checks after validation, in the order of the list.
/// In an interactive run it offers to install what is missing; otherwise it
/// prints instructions. See [PreflightCheck].
final class Preflight extends Contribution {
  /// Creates the preflight of a module with [checks].
  const Preflight(this.checks, {super.when});

  /// The checks, run in this order.
  final List<PreflightCheck> checks;
}
