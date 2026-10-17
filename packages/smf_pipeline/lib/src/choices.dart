import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// Stage 7 of the pipeline: runs the [RoleTemplate.choose] hook of every
/// present role with a template, in the order of [choiceOrder], and returns
/// their results by role, with the issues of the choices.
///
/// The hook of a role gets the data of the role that applies, of
/// [collection] as stage 4 made it, but only where each condition of the
/// data on what another role chose holds (see [Contribution.whenChosen]):
/// that role has chosen by then.
///
/// The hooks read the role options in [optionValues] and ask the user if
/// the run is interactive. An [SmfUsageException] or an
/// [SmfCancelledException] from a hook stops generation, and so does a hook
/// that fails. Then the issues of the hooks before it are reported through
/// the logger of [environment] first.
///
/// The issues are the warnings that each hook reported with
/// [RoleChoiceContext.warn], each a warning of the role's template unless
/// it names its own origin, and an error of the role's template for each of
/// those warnings whose code is not a code of the role (see [reportedBy]).
/// An option in [optionValues] of a role that is not present is a warning
/// of stage 5, the validation, which comes before the choices.
///
/// [onChoice] gets each role and its choice once the hook of the role has
/// made it, before the next hook runs.
///
/// Throws a [StateError] if the roles cannot be ordered, which validation
/// reports first.
Future<({Map<Role, Object?> choices, List<SmfIssue> issues})> chooseRoles({
  required Resolution resolution,
  required Collection collection,
  required Map<String, String?> optionValues,
  required PipelineEnvironment environment,
  required ModuleContext context,
  void Function(Role role, Object? choice)? onChoice,
}) async {
  final present = resolution.presentRoles;
  final issues = <SmfIssue>[];

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
    final choiceContext = role.choiceContext(request);
    final Object? choice;
    try {
      choice = await template.choose(choiceContext);
    } on Object catch (error) {
      _report(issues, environment.logger);
      if (error is SmfUsageException || error is SmfCancelledException) {
        rethrow;
      }
      throw GenerationFailedException(
        'The template of the $role failed to choose: $error',
      );
    }
    final origin = RoleTemplateOrigin(role);
    for (final warning in choiceContext.warnings) {
      issues.add(
        reportedBy(
          warning,
          role: role,
          who: 'The template of the $role',
          origin: origin,
        ),
      );
    }
    choices[role] = choice;
    onChoice?.call(role, choice);
  }
  return (choices: choices, issues: issues);
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

/// Reports [issues], those of the choices before a hook that stopped
/// generation, through [logger], since the caller of [chooseRoles] gets
/// none of them then.
void _report(List<SmfIssue> issues, SmfLogger logger) {
  for (final issue in issues) {
    // The logger marks the severity itself.
    if (issue.isError) {
      logger.error(issueLine(issue));
    } else {
      logger.warn(issueLine(issue));
    }
  }
}
