import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/order.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// What stage 5 found and computed.
final class ValidationResult {
  /// Creates the result.
  const ValidationResult({
    required this.issues,
    required this.socketOrders,
    required this.postGenOrder,
    required this.pubspec,
  });

  /// The errors and warnings found.
  final List<SmfIssue> issues;

  /// The contributions of each socket that apply, in their final order.
  final Map<SocketRef, ContributionOrder> socketOrders;

  /// The post-generation steps that apply, in the order they run.
  final ContributionOrder postGenOrder;

  /// The merged `pubspec.yaml`.
  final MergedPubspec pubspec;

  /// Whether generation cannot continue.
  bool get hasErrors => issues.any((issue) => issue.isError);
}

/// Brick variables that the pipeline sets itself.
const _reservedVars = {'app_name', 'org_name'};

/// Stage 5 of the pipeline: checks the contributions against the rules of
/// the lego model and the hooks of the roles, orders the contributions of
/// every socket, and merges the pubspec.
///
/// Checks, in this order:
/// - the rules of the pipeline for each contribution: who may use which
///   socket, role and [Contribution.when], bricks without hooks and with one
///   owner per file, reserved brick variables;
/// - the rules of each module's kind;
/// - the pubspec;
/// - the `validate` hooks of the present roles' templates and providers,
///   and the module rules of the roles;
/// - the order of every socket, and a dry render of its contributions, so
///   that a merge conflict names its contributors before anything is
///   generated.
ValidationResult validate({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
  required ModuleContext context,
}) {
  final issues = <SmfIssue>[
    for (final collected in collection.all)
      ..._contributionIssues(collected, registry, resolution),
    ..._ownerIssues(collection),
    for (final module in resolution.modules) ..._kindIssues(module, collection),
  ];

  final merged = mergePubspec(collection.all);
  issues
    ..addAll(merged.issues)
    ..addAll(_hookIssues(resolution, collection, context));

  final bySocket = <SocketRef, List<Collected>>{};
  final postGen = <Collected>[];
  for (final collected in collection.applying) {
    switch (collected.contribution) {
      case final SocketContribution socket:
        bySocket.putIfAbsent(socket.socket, () => []).add(collected);
      case PostGenStep():
        postGen.add(collected);
      default:
        break;
    }
  }

  final orders = <SocketRef, ContributionOrder>{};
  for (final MapEntry(key: socket, value: contributions) in bySocket.entries) {
    final order = orderContributions(contributions, resolution);
    orders[socket] = order;
    issues.addAll(_orderIssues('the $socket', order));
    final valid = [
      for (final collected in order.contributions)
        if (socket
            .problemsWith(collected.contribution as SocketContribution)
            .isEmpty)
          collected.contribution as SocketContribution,
    ];
    if (valid.length != order.contributions.length) continue;
    try {
      socket.render(valid);
    } on MergeConflict catch (conflict) {
      issues.add(
        SmfIssue(
          'The contributions to the $socket conflict: $conflict.',
          origin: conflict.incomingOrigin,
        ),
      );
    } on Object catch (error) {
      issues.add(SmfIssue('The $socket cannot be rendered: $error.'));
    }
  }

  final postGenOrder = orderContributions(postGen, resolution);
  issues.addAll(_orderIssues('the post-generation steps', postGenOrder));

  return ValidationResult(
    issues: issues,
    socketOrders: orders,
    postGenOrder: postGenOrder,
    pubspec: merged.pubspec,
  );
}

Iterable<SmfIssue> _orderIssues(String what, ContributionOrder order) sync* {
  if (order.cycle.isEmpty) return;
  yield SmfIssue(
    'The contributors to $what cannot be ordered, because their order edges '
    'form a cycle: ${order.cycle.join(', ')}.',
    hint: 'Run with --explain to see the edges.',
  );
}

/// The roles whose sockets, symbols and data [origin] may use, and those it
/// may list in [Contribution.when].
({Set<Role> access, Set<Role> when}) _rolesOf(
  ContributionOrigin origin,
  ModuleRegistry registry,
  Resolution resolution,
) {
  final open = registry.openRoles;
  switch (origin) {
    case ModuleOrigin(:final module):
      final roles =
          resolution.module(module)?.descriptor.roles ?? const <Role>{};
      return (access: {...roles, ...open}, when: roles);
    case RoleTemplateOrigin(:final role):
      final roles = {role, ...role.visibleRoles};
      return (access: {...roles, ...open}, when: roles);
    case PipelineOrigin():
      return (access: open, when: const {});
  }
}

Iterable<SmfIssue> _contributionIssues(
  Collected collected,
  ModuleRegistry registry,
  Resolution resolution,
) sync* {
  final origin = collected.origin;
  final contribution = collected.contribution;
  final roles = _rolesOf(origin, registry, resolution);

  for (final role in contribution.when) {
    if (!roles.when.contains(role)) {
      yield SmfIssue(
        '$origin lists the ${role.id} in the condition of a contribution, '
        'but does not provide, require or use it.',
        hint: 'Add the role to the uses of the module.',
        origin: origin,
      );
    }
  }

  switch (contribution) {
    case final RoleData<Object> data:
      if (!roles.access.contains(data.role)) {
        yield SmfIssue(
          '$origin contributes data to the ${data.role.id}, but does not '
          'provide, require or use it.',
          origin: origin,
        );
      } else if (!data.role.accepts(data.value)) {
        yield SmfIssue(
          '$origin contributes a ${data.value.runtimeType} to the '
          '${data.role.id}, which takes other data.',
          origin: origin,
        );
      }
    case final SocketContribution socket:
      yield* _socketIssues(socket, origin, roles.access, resolution);
    case final BrickContribution brick:
      if (brick.bundle.hooks.isNotEmpty) {
        yield SmfIssue(
          'The brick ${brick.bundle.name} of $origin has mason hooks, which '
          'the pipeline does not run.',
          hint: 'Move the hooks into Preflight checks and PostGenSteps.',
          origin: origin,
        );
      }
      for (final name in brick.vars.keys) {
        if (_reservedVars.contains(name) ||
            name.startsWith('smf_') ||
            name.startsWith('has_')) {
          yield SmfIssue(
            'The brick ${brick.bundle.name} of $origin sets the variable '
            '$name, which the pipeline sets itself.',
            origin: origin,
          );
        }
      }
      if (origin case ModuleOrigin(:final module)) {
        final kind = resolution.module(module)?.descriptor.kind;
        for (final file in brick.bundle.files) {
          if (kind != null && !kind.allowsFile(module, file.path)) {
            yield SmfIssue(
              'The module $module generates ${file.path}, where modules of '
              'the ${kind.id} kind may not.',
              origin: origin,
              path: file.path,
            );
          }
        }
      }
    case final Preflight preflight:
      final ids = <String>{};
      for (final check in preflight.checks) {
        if (!SmfNames.isSnakeCase(check.id) || !ids.add(check.id)) {
          yield SmfIssue(
            'The preflight check "${check.id}" of $origin needs a unique '
            'lower snake_case id.',
            origin: origin,
          );
        }
      }
    case PubspecContribution() || CodegenRequest() || PostGenStep():
      break;
  }
}

Iterable<SmfIssue> _socketIssues(
  SocketContribution contribution,
  ContributionOrigin origin,
  Set<Role> roles,
  Resolution resolution,
) sync* {
  final socket = contribution.socket;
  for (final problem in socket.problemsWith(contribution)) {
    yield SmfIssue(problem, origin: origin);
  }

  final role = socket.role;
  final owner = socket.module;
  if (role != null) {
    if (!roles.contains(role)) {
      yield SmfIssue(
        '$origin puts code into the $socket, but does not provide, require '
        'or use the ${role.id}.',
        origin: origin,
      );
      return;
    }
    final declared = socket.familyKey.isEmpty
        ? role.sockets.contains(socket)
        : role.socketFamilies.any((family) => _isMember(family, socket));
    if (!declared) {
      yield SmfIssue(
        'The ${role.id} has no $socket.',
        origin: origin,
      );
    }
  } else if (owner != null) {
    final dependsOn = switch (origin) {
      ModuleOrigin(:final module) =>
        resolution.module(module)?.descriptor.dependsOn ?? const {},
      _ => const <ModuleId>{},
    };
    if (!dependsOn.contains(owner)) {
      yield SmfIssue(
        '$origin puts code into the $socket, but only modules that depend '
        'on $owner directly may.',
        origin: origin,
      );
      return;
    }
    final descriptor = resolution.module(owner)?.descriptor;
    final declared = descriptor != null &&
        (socket.familyKey.isEmpty
            ? descriptor.sockets.contains(socket)
            : descriptor.socketFamilies
                .any((family) => _isMember(family, socket)));
    if (!declared) {
      yield SmfIssue('The module $owner has no $socket.', origin: origin);
    }
  }
}

bool _isMember(SocketFamily<Object?, SocketKind> family, SocketRef socket) =>
    family.name == socket.name && family.memberOfTag(socket.tag) == socket;

/// Two bricks that generate the same file.
Iterable<SmfIssue> _ownerIssues(Collection collection) sync* {
  final owners = <String, ContributionOrigin>{};
  for (final collected in collection.applyingOf<BrickContribution>()) {
    final brick = collected.contribution as BrickContribution;
    for (final file in brick.bundle.files) {
      final existing = owners.putIfAbsent(file.path, () => collected.origin);
      if (existing != collected.origin) {
        yield SmfIssue(
          'Both $existing and ${collected.origin} generate ${file.path}; '
          'every file has one owner.',
          origin: collected.origin,
          path: file.path,
        );
      }
    }
  }
}

Iterable<SmfIssue> _kindIssues(
  ResolvedModule module,
  Collection collection,
) sync* {
  final kind = module.descriptor.kind;
  final contributions = collection.ofModule(module.id);
  final dataRoles = {
    for (final collected in contributions)
      if (collected.contribution case final RoleData<Object> data) data.role,
  };
  final applyingDataRoles = {
    for (final collected in contributions)
      if (collected.applies)
        if (collected.contribution case final RoleData<Object> data) data.role,
  };
  for (final role in kind.requiredData) {
    if (!applyingDataRoles.contains(role)) {
      yield SmfIssue(
        'The module ${module.id} is of the ${kind.id} kind, so it must '
        'contribute data to the ${role.id}.',
        origin: module.origin,
      );
    }
  }
  for (final role in kind.forbiddenData) {
    if (dataRoles.contains(role)) {
      yield SmfIssue(
        'The module ${module.id} is of the ${kind.id} kind, so it must not '
        'contribute data to the ${role.id}.',
        origin: module.origin,
      );
    }
  }
}

/// Runs the `validate` hooks of the present roles' templates and providers
/// and the module rules of the roles.
Iterable<SmfIssue> _hookIssues(
  Resolution resolution,
  Collection collection,
  ModuleContext context,
) sync* {
  // Data of the wrong type is reported with its contribution and left out
  // here, so building the hooks' input cannot fail.
  final request = RoleHookRequest(
    data: [
      for (final data in collection.roleData)
        if (data.role.accepts(data.value)) data,
    ],
    presentRoles: resolution.presentRoles,
    context: context,
  );
  for (final role in resolution.presentRoles) {
    // The input's runtime type argument is the role's data type, which the
    // hooks of the role's template and providers take.
    final input = role.hookInput(request);
    final template = role.template;
    if (template != null) {
      yield* _guarded(
        RoleTemplateOrigin(role),
        () => template.validate(input),
      );
    }
    for (final module in resolution.providersOf(role)) {
      final provider = Resolution.providerObject(module, role);
      yield* _guarded(
        module.origin,
        () => provider.validate(input),
      );
    }
    for (final module in resolution.modules) {
      if (!module.descriptor.roles.contains(role)) continue;
      yield* _guarded(
        module.origin,
        () => role.checkModule(
          ModuleRuleRequest(
            hook: request,
            module: module.descriptor,
            contributions: [
              for (final collected in collection.ofModule(module.id))
                collected.contribution,
            ],
          ),
        ),
      );
    }
  }
}

/// The issues of [check], each with [origin] unless it names its own; a
/// hook that throws becomes an issue of [origin].
Iterable<SmfIssue> _guarded(
  ContributionOrigin origin,
  List<SmfIssue> Function() check,
) sync* {
  final List<SmfIssue> issues;
  try {
    issues = check();
  } on Object catch (error) {
    yield SmfIssue('A check of $origin failed: $error', origin: origin);
    return;
  }
  for (final issue in issues) {
    yield issueWithOrigin(issue, origin);
  }
}
