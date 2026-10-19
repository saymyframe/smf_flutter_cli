import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/access.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/order.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// A step of the app that its developer does by hand (see [ManualStep]),
/// with every contributor that lists it.
final class PlannedManualStep {
  /// Creates the planned [step], which [contributors] list.
  const PlannedManualStep(this.step, this.contributors);

  /// The step, as the first of its [contributors] gives it.
  final ManualStep step;

  /// Who lists the step, each once, in the order of the steps: modules,
  /// the variants of modules, and the templates of roles.
  final List<ContributionOrigin> contributors;

  /// The step as `<id>: <title> (<contributors>)`, such as
  /// `push.apns_key: Give Firebase your Apple push key (push)`.
  @override
  String toString() => '${step.id}: ${step.title} (${contributors.join(', ')})';
}

/// The steps by hand of the app of [resolution], which stage 5 plans once,
/// before the roles choose, so that a run that stops before the choices,
/// as `--explain` does, has the steps of the app too:
/// 1. the steps among the contributions of [collection] that apply, and
///    those that the `manualSteps` hooks of the templates and providers of
///    the present roles return for the data of [request] (see
///    [RoleTemplate.manualSteps]), which apply as the steps among the
///    contributions do (see [collectedOf]);
/// 2. in the order of their contributors, as the steps after generation
///    (see [orderContributions]). The order only tells the developer which
///    step to do first, so a cycle of its edges is no problem here: the
///    contributors on it are ordered by name among themselves;
/// 3. each id once, in the place of its first step, with the contributors
///    of every step with the id;
/// 4. the steps with an id of a role before the others, each group in its
///    order: a role publishes a step that contributors which do not know
///    each other share, so it comes before their own steps.
///
/// The issues are those of the hooks, each of the origin of its hook: a
/// hook that throws, and a step that breaks a rule of [manualStepIssues] or
/// has conditions of its own, since a hook asks for the presence of the
/// roles itself. A step with a title other than that of the first step
/// with its id is an issue of its contributor, the later of the two in the
/// order of the steps. Stage 5 reports the problems of the steps among the
/// contributions with those of the other contributions.
({List<PlannedManualStep> steps, List<SmfIssue> issues}) planManualSteps({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
  required RoleHookRequest request,
}) {
  final issues = <SmfIssue>[];
  final present = resolution.presentRoles;
  final steps = [...collection.applyingOf<ManualStep>()];

  void addHook(ContributionOrigin origin, List<ManualStep> Function() hook) {
    final List<ManualStep> listed;
    try {
      listed = hook();
    } on Object catch (error) {
      issues.add(
        SmfIssue(
          'The hook of $origin that lists the steps by hand failed: $error',
          origin: origin,
        ),
      );
      return;
    }
    final access = rolesOf(origin, registry, resolution).access;
    for (final step in listed) {
      issues.addAll(_hookStepIssues(step, origin, access));
      final collected = collectedOf(step, origin, present, fromHook: true);
      if (collected.applies) steps.add(collected);
    }
  }

  for (final role in present) {
    // The input's runtime type argument is the role's data type, which the
    // hooks of the role's template and providers take.
    final input = role.hookInput(request);
    if (role.template case final template?) {
      addHook(RoleTemplateOrigin(role), () => template.manualSteps(input));
    }
    for (final module in resolution.providersOf(role)) {
      final provider = Resolution.providerObject(module, role);
      addHook(module.origin, () => provider.manualSteps(input));
    }
  }

  // Most apps have no steps, and the order of the contributors walks the
  // edges of every module of the app.
  if (steps.isEmpty) return (steps: const [], issues: issues);
  final byId = <ManualStepId, (ManualStep, List<ContributionOrigin>)>{};
  for (final collected in orderContributions(steps, resolution).contributions) {
    final step = collected.contribution as ManualStep;
    final origin = collected.origin;
    final first = byId[step.id];
    if (first == null) {
      byId[step.id] = (step, [origin]);
      continue;
    }
    final (kept, contributors) = first;
    if (step.title != kept.title) {
      issues.add(_titleConflict(step, kept, contributors.first, origin));
    }
    if (!contributors.contains(origin)) contributors.add(origin);
  }
  final planned = [
    for (final (step, contributors) in byId.values)
      PlannedManualStep(step, List.unmodifiable(contributors)),
  ];
  return (
    steps: List.unmodifiable([
      for (final each in planned)
        if (each.step.id.role != null) each,
      for (final each in planned)
        if (each.step.id.role == null) each,
    ]),
    issues: issues,
  );
}

/// What the render hooks and the structural rules of a role that is open
/// to all modules get of [steps], the planned steps of the app (see
/// [RoleHookInput.manualSetup]): [ManualSetup.none] for an app without
/// steps.
ManualSetup manualSetupOf(List<PlannedManualStep> steps) => steps.isEmpty
    ? ManualSetup.none
    : ManualSetup(
        steps: List.unmodifiable([for (final planned in steps) planned.step]),
      );

/// The problems of [step] of [origin], which has access to the roles
/// [access] (see [rolesOf]), with the rules of [ManualStep]:
/// - the name of its id is lower snake_case;
/// - its id is of the module of [origin], a variant counting as its module,
///   or of a role among [access], so a template gives no id of a module;
/// - its title is one line of at most [ManualStep.maxTitleLength]
///   characters with text and without spaces around it, that starts with an
///   upper-case letter or with `iOS`, and has neither a final period nor a
///   backslash.
Iterable<SmfIssue> manualStepIssues(
  ManualStep step,
  ContributionOrigin origin,
  Set<Role> access,
) sync* {
  final id = step.id;
  if (!SmfNames.isSnakeCase(id.name)) {
    yield SmfIssue(
      'The step by hand $id of $origin has the name "${id.name}", which is '
      'not lower snake_case: the link to the guide of a step carries its id '
      'as it is.',
      hint: 'Name the step in lower snake_case, such as apns_key.',
      origin: origin,
    );
  }
  yield* _ownerIssues(id, origin, access);
  if (_titleProblem(step.title) case final problem?) {
    yield SmfIssue(
      'The title of the step by hand $id of $origin $problem: a title is '
      'one line of at most ${ManualStep.maxTitleLength} characters, without '
      'spaces around it, that starts with an upper-case letter or with iOS, '
      'and has no final period and no backslash.',
      hint: 'Tell what the developer does in a few words; the guide of the '
          'step tells how.',
      origin: origin,
    );
  }
}

/// The problems of the owner of [id], the id of a step of [origin], which
/// has access to the roles [access]; see [manualStepIssues].
Iterable<SmfIssue> _ownerIssues(
  ManualStepId id,
  ContributionOrigin origin,
  Set<Role> access,
) sync* {
  if (id.module case final module?) {
    final own = switch (origin) {
      ModuleOrigin(module: final contributor) => contributor,
      _ => null,
    };
    if (own == module) return;
    yield SmfIssue(
      'The step by hand $id of $origin has an id of the module $module, but '
      'only $module gives its steps the ids of $module.',
      hint: own == null
          ? 'The template of a role gives its steps ids of a role, with '
              'ManualStepId.role.'
          : 'Give the step an id of its own module, or list a step of a role '
              'by the id that the role publishes.',
      origin: origin,
    );
  } else if (!access.contains(id.role)) {
    yield SmfIssue(
      '$origin lists the step by hand $id of the ${id.role}, but does not '
      'provide, require or use it.',
      hint: 'Add the role to the uses of the module.',
      origin: origin,
    );
  }
}

/// What is wrong with [title], the title of a step by hand, as a phrase
/// such as `has a line break and ends with a period`, or `null` if it
/// follows the rules of [ManualStep.title].
String? _titleProblem(String title) {
  if (title.trim().isEmpty) return 'is blank';
  // A space at the start is a problem of its own.
  final start = title.trimLeft();
  final first = String.fromCharCode(start.runes.first);
  final problems = [
    if (title.contains('\n') || title.contains('\r')) 'has a line break',
    if (title.trim() != title) 'has a space at its start or end',
    if (title.runes.length > ManualStep.maxTitleLength)
      'is longer than ${ManualStep.maxTitleLength} characters',
    if (first == first.toLowerCase() && !start.startsWith('iOS'))
      'starts with neither an upper-case letter nor iOS',
    if (title.endsWith('.')) 'ends with a period',
    if (title.contains(r'\')) 'has a backslash, which mason may remove',
  ];
  if (problems.isEmpty) return null;
  return problems.length == 1
      ? problems.single
      : '${problems.sublist(0, problems.length - 1).join(', ')} and '
          '${problems.last}';
}

/// The problems of [step] that the hook of [origin], which has access to
/// the roles [access], returned: those of [manualStepIssues], and
/// conditions of its own.
Iterable<SmfIssue> _hookStepIssues(
  ManualStep step,
  ContributionOrigin origin,
  Set<Role> access,
) sync* {
  if (step.when.isNotEmpty) {
    yield SmfIssue(
      'The step by hand ${step.id} that the hook of $origin returned has '
      'conditions of its own, but a hook returns a step only in the apps '
      'that need it.',
      hint: 'Ask for the roles with RoleHookInput.has, and leave the '
          'conditions out.',
      origin: origin,
    );
  }
  yield* manualStepIssues(step, origin, access);
}

/// The problem of [step] of [origin], whose title differs from that of
/// [kept], the step with the same id that [first] listed earlier in the
/// order of the steps.
SmfIssue _titleConflict(
  ManualStep step,
  ManualStep kept,
  ContributionOrigin first,
  ContributionOrigin origin,
) {
  final who = first == origin
      ? 'Two steps by hand of $origin have'
      : 'Both $first and $origin list a step by hand with';
  return SmfIssue(
    '$who the id ${step.id}, but with the titles "${kept.title}" and '
    '"${step.title}"; the app lists the step once, under one title.',
    hint: 'List the step by the constant that its owner publishes.',
    origin: origin,
  );
}
