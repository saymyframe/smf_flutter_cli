import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/order.dart';
import 'package:smf_pipeline/src/pipeline.dart';
import 'package:smf_pipeline/src/preflight.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/selection.dart';
import 'package:smf_pipeline/src/validation.dart';

/// The report of `--explain`: what the pipeline would generate and why, and
/// whether the machine is ready, as lines of text.
///
/// It shows:
/// - the app, its identifiers and its directory;
/// - every module with why it is in the app and its variant;
/// - every present role with its providers;
/// - the modules lenient mode left out;
/// - for every socket with more than one contributor, the order of the
///   contributors and the edges that decide it, and the same for the
///   post-generation steps;
/// - the state of every preflight check, with instructions for what is
///   missing and what a missing required check would do.
List<String> explain({
  required Selection selection,
  required ModuleContext context,
  required Resolution resolution,
  required ValidationResult validation,
  required PreflightReport preflight,
  required List<LeftOut> leftOut,
  required bool strict,
}) {
  final target = selection.target;
  final lines = <String>[
    'App ${context.appName} of ${context.orgName}',
    '  Android application id: ${context.appIdentity.androidApplicationId}',
    '  iOS bundle id: ${context.appIdentity.iosBundleId}',
    '  Directory: ${target.path}${target.conflict ? _conflict : ''}',
    '',
    'Modules',
    for (final module in resolution.modules)
      '  ${module.id}: ${module.reason}${_variant(module)}',
  ];

  if (resolution.presentRoles.isNotEmpty) {
    lines
      ..add('')
      ..add('Roles');
    for (final role in resolution.presentRoles) {
      final providers = resolution.providersOf(role).map((m) => m.id);
      lines.add('  ${role.id}: ${providers.join(', ')}');
    }
  }

  if (leftOut.isNotEmpty) {
    lines
      ..add('')
      ..add('Left out (lenient mode)');
    for (final record in leftOut) {
      lines.add('  ${record.module}: ${record.reason}');
    }
  }

  final ordered = [
    for (final MapEntry(key: socket, value: order)
        in validation.socketOrders.entries)
      if (_contributors(order).length > 1) ('$socket', order),
    if (_contributors(validation.postGenOrder).length > 1)
      ('post-generation steps', validation.postGenOrder),
  ];
  if (ordered.isNotEmpty) {
    lines
      ..add('')
      ..add('Order of contributions');
    for (final (name, order) in ordered) {
      lines.add('  $name: ${_contributors(order).join(', ')}');
      for (final edge in order.edges) {
        lines.add('    $edge');
      }
      if (order.cycle.isNotEmpty) {
        lines.add('    cycle: ${order.cycle.join(', ')}');
      }
    }
  }

  lines
    ..add('')
    ..add('Machine');
  for (final result in preflight.results) {
    final check = result.planned.check;
    final origin = result.planned.origin;
    final by = origin is PipelineOrigin ? '' : ' (for $origin)';
    switch (result.status) {
      case PreflightPassed():
        lines.add('  ✓ ${check.description}$by');
      case PreflightMissing(:final instructions, :final installable):
        lines
          ..add('  ✗ ${check.description}$by: missing')
          ..add('    $instructions');
        if (installable) {
          lines.add('    An interactive run offers to install it.');
        }
      case PreflightFailed(:final message):
        lines.add('  ✗ ${check.description}$by: $message');
    }
    if (!result.passed && check.required) {
      lines.add(
        origin is ModuleOrigin && !strict
            ? '    Generation would leave out ${origin.module}.'
            : '    Generation would stop.',
      );
    }
  }
  return lines;
}

const _conflict = ' (exists and is not empty; see --on-conflict)';

String _variant(ResolvedModule module) =>
    module.variant == null ? '' : ', variant for ${module.variant}';

List<String> _contributors(ContributionOrder order) => {
      for (final collected in order.contributions)
        contributorName(collected.origin),
    }.toList();
