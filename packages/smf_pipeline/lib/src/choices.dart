import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// Stage 7 of the pipeline: runs the [RoleTemplate.choose] hook of every
/// present role with a template, in the order of the present roles, and
/// returns their results by role.
///
/// The hooks read the role options in [optionValues] and ask the user if
/// the run is interactive. An option of a role that is not present is
/// reported as a warning, since nothing reads it. An [SmfUsageException]
/// or an [SmfCancelledException] from a hook stops generation.
Future<Map<Role, Object?>> chooseRoles({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
  required Map<String, String?> optionValues,
  required PipelineEnvironment environment,
  required ModuleContext context,
}) async {
  final present = resolution.presentRoles;
  for (final role in registry.roles) {
    if (present.contains(role)) continue;
    for (final option in role.options) {
      if (optionValues.containsKey(option.name)) {
        environment.logger.warn(
          '--${option.name} has no effect: no module of the app provides '
          'the ${role.id}.',
        );
      }
    }
  }

  final request = RoleChoiceRequest(
    data: collection.roleData,
    presentRoles: present,
    optionValues: {
      for (final role in present)
        for (final option in role.options)
          option.name: optionValues[option.name],
    },
    environment: environment,
    context: context,
  );
  final choices = <Role, Object?>{};
  for (final role in present) {
    final template = role.template;
    if (template == null) continue;
    // The context's runtime type argument is the role's data type, which
    // the hook of the role's template takes.
    try {
      choices[role] = await template.choose(role.choiceContext(request));
    } on SmfUsageException {
      rethrow;
    } on SmfCancelledException {
      rethrow;
    } on Object catch (error) {
      throw GenerationFailedException(
        'The template of the ${role.id} failed to choose: $error',
      );
    }
  }
  return choices;
}
