import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// Stage 7 of the pipeline: runs the [RoleTemplate.choose] hook of every
/// present role with a template, in the order of [choiceOrder], and returns
/// their results by role.
///
/// The hook of a role gets the data of the role that applies, of
/// [collection] as stage 4 made it, but only where each condition of the
/// data on what another role chose holds (see [Contribution.whenChosen]):
/// that role has chosen by then.
///
/// The hooks read the role options in [optionValues] and ask the user if
/// the run is interactive. An option of a role that is not present is
/// reported as a warning, since nothing reads it. An [SmfUsageException]
/// or an [SmfCancelledException] from a hook stops generation.
///
/// [onChoice] gets each role and its choice once the hook of the role has
/// made it, before the next hook runs.
///
/// Throws a [StateError] if the roles cannot be ordered, which validation
/// reports first.
Future<Map<Role, Object?>> chooseRoles({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
  required Map<String, String?> optionValues,
  required PipelineEnvironment environment,
  required ModuleContext context,
  void Function(Role role, Object? choice)? onChoice,
}) async {
  final present = resolution.presentRoles;
  _warnOfAbsentRoles(registry, present, optionValues, environment.logger);

  final data = collection.roleData;
  final (:order, :cycle) = choiceOrder(present, data);
  if (cycle.isNotEmpty) {
    throw StateError(
      'The roles cannot choose, because the conditions of their data form '
      'a cycle: ${cycle.join(' → ')}.',
    );
  }
  final options = {
    for (final role in present)
      for (final option in role.options) option.name: optionValues[option.name],
  };
  final choices = <Role, Object?>{};
  for (final role in order) {
    final template = role.template!;
    final request = RoleChoiceRequest(
      data: [
        for (final item in data)
          if (!identical(item.role, role) ||
              item.whenChosen.every(
                (condition) =>
                    condition.holds(presentRoles: present, choices: choices),
              ))
            item,
      ],
      presentRoles: present,
      optionValues: options,
      environment: environment,
      context: context,
    );
    // The context's runtime type argument is the role's data type, which
    // the hook of the role's template takes.
    final Object? choice;
    try {
      choice = await template.choose(role.choiceContext(request));
    } on SmfUsageException {
      rethrow;
    } on SmfCancelledException {
      rethrow;
    } on Object catch (error) {
      throw GenerationFailedException(
        'The template of the $role failed to choose: $error',
      );
    }
    choices[role] = choice;
    onChoice?.call(role, choice);
  }
  return choices;
}

/// The order in which the [present] roles with a template choose, and the
/// roles of a cycle that keeps some of them from choosing, the first role
/// again at its end, or an empty list.
///
/// A role chooses after each role of a condition of its [data] on what
/// another role chose (see [Contribution.whenChosen]), when that role is
/// present and has a template: its data depends on the choice. Otherwise
/// the roles keep the order of [present], so that a role waits only as
/// long as it has to and the other questions keep their order. The data of
/// a role with a condition of the role itself is left to validation, which
/// reports it.
({List<Role> order, List<Role> cycle}) choiceOrder(
  Set<Role> present,
  List<RoleData<Object>> data,
) {
  final choosing = [
    for (final role in present)
      if (role.template != null) role,
  ];
  final after = {
    for (final role in choosing)
      role: {
        for (final item in data)
          if (identical(item.role, role))
            for (final condition in item.whenChosen)
              if (!identical(condition.role, role) &&
                  choosing.contains(condition.role))
                condition.role,
      },
  };
  final order = <Role>[];
  final waiting = [...choosing];
  while (waiting.isNotEmpty) {
    final next =
        waiting.where((role) => after[role]!.every(order.contains)).firstOrNull;
    if (next == null) {
      // Each role that waits, waits for another one that waits.
      final path = <Role>[];
      var role = waiting.first;
      while (!path.contains(role)) {
        path.add(role);
        role = after[role]!.firstWhere(waiting.contains);
      }
      return (
        order: order,
        cycle: [...path.sublist(path.indexOf(role)), role],
      );
    }
    order.add(next);
    waiting.remove(next);
  }
  return (order: order, cycle: const []);
}

/// Warns of each of the [optionValues] that is an option of a role of
/// [registry] that is not among the [present] roles, since nothing reads it.
void _warnOfAbsentRoles(
  ModuleRegistry registry,
  Set<Role> present,
  Map<String, String?> optionValues,
  SmfLogger logger,
) {
  for (final role in registry.roles) {
    if (present.contains(role)) continue;
    for (final option in role.options) {
      if (optionValues.containsKey(option.name)) {
        logger.warn(
          '--${option.name} has no effect: no module of the app provides '
          'the $role.',
        );
      }
    }
  }
}
