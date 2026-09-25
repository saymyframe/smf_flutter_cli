import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/access.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/machine_files.dart';
import 'package:smf_pipeline/src/order.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/templates.dart';

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

/// Brick variables that the pipeline sets itself, besides the tags of
/// sockets, `smf_…`, and the presence flags of roles, `has_…`; see
/// [isReservedVar].
const _reservedVars = {'app_name', 'org_name'};

/// Whether the pipeline or mason sets the brick variable [name] itself, so
/// neither a brick nor a render hook may set it: the names of the app, the
/// tags of sockets, the presence flags of roles, and mason's case lambdas
/// and brace variables.
bool isReservedVar(String name) =>
    _reservedVars.contains(name) ||
    name.startsWith('smf_') ||
    name.startsWith('has_') ||
    masonLambdas.contains(name) ||
    masonVariables.contains(name);

/// The request that the hooks of the roles get: the data of [collection]
/// that applies, the present roles of [resolution], the [context] and the
/// [choices] of the roles once they are made.
///
/// Data of the wrong type, or for a role its contributor has no access to,
/// is reported with its contribution by [validate] and left out here: the
/// hooks would only add confusing problems about it, and building their
/// input cannot fail on the type.
RoleHookRequest hookRequest({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
  required ModuleContext context,
  Map<Role, Object?> choices = const {},
}) =>
    RoleHookRequest(
      data: [
        for (final data in collection.roleData)
          if (data.role.accepts(data.value) &&
              rolesOf(data.origin!, registry, resolution)
                  .access
                  .contains(data.role))
            data,
      ],
      presentRoles: resolution.presentRoles,
      context: context,
      choices: choices,
    );

/// The names of the brick variables among [vars] that are not plain data:
/// `null`, strings, numbers, booleans, and lists and maps of them with
/// string keys. mason calls a function as a lambda and renders another
/// object as nothing.
List<String> nonPlainVars(Map<String, Object?> vars) {
  bool plain(Object? value) => switch (value) {
        null || String() || num() || bool() => true,
        final List<Object?> items => items.every(plain),
        final Map<Object?, Object?> map =>
          map.keys.every((key) => key is String) && map.values.every(plain),
        _ => false,
      };
  return [
    for (final MapEntry(:key, :value) in vars.entries)
      if (!plain(value)) key,
  ];
}

/// The dev dependency the pipeline adds when a [CodegenRequest] applies.
///
/// `build_runner` 2.7 and later always delete conflicting outputs, so the
/// pipeline runs `build_runner build` without flags.
const codegenDependency =
    PubspecContribution.hosted('build_runner', '^2.7.0', dev: true);

/// The names of the brick variables among [vars] whose text mason would
/// change, since it removes a backslash before a line break or a non-ASCII
/// character from everything it renders; see
/// [Fragment.hasStrippedBackslash]. Lists and maps are searched too.
List<String> strippedVars(Map<String, Object?> vars) {
  bool strips(Object? value) => switch (value) {
        final String text => Fragment.hasStrippedBackslash(text),
        final Iterable<Object?> items => items.any(strips),
        final Map<Object?, Object?> map =>
          map.keys.any(strips) || map.values.any(strips),
        _ => false,
      };
  return [
    for (final MapEntry(:key, :value) in vars.entries)
      if (strips(value)) key,
  ];
}

/// Stage 5 of the pipeline: checks the contributions against the rules of
/// the lego model and the hooks of the roles, orders the contributions of
/// every socket, and merges the pubspec.
///
/// Checks, in this order:
/// - the rules of the pipeline for each contribution: who may use which
///   socket, role and [Contribution.when], bricks without hooks and with one
///   owner per file, brick variables that are not reserved and that mason
///   renders as they are;
/// - the rules of each module's kind;
/// - the pubspec, with [codegenDependency] if code generation is requested:
///   it has a Dart SDK constraint, and the app is not named like a
///   dependency;
/// - the `validate` hooks of the present roles' templates and providers,
///   and the module rules of the roles;
/// - the tags of the sockets in the bricks (see [checkTemplateTags]), that
///   every socket and every section of the pubspec with contributions has
///   its tag, and that every socket that needs a value has one;
/// - the order of every socket, and a dry render of its contributions, so
///   that a merge conflict names its contributors before anything is
///   generated;
/// - that every post-generation step can run in this run, [interactive]
///   and with [skipExternalSetup] as given, or may be skipped.
ValidationResult validate({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
  required ModuleContext context,
  bool interactive = true,
  bool skipExternalSetup = false,
}) {
  final issues = <SmfIssue>[...collection.issues];
  // Sockets with a contribution that breaks a rule, whose tags are not
  // worth reporting too.
  final broken = <SocketRef>{};
  for (final collected in collection.all) {
    final found = contributionIssues(collected, registry, resolution).toList();
    if (found.isEmpty) continue;
    issues.addAll(found);
    if (collected.contribution case SocketContribution(:final socket)) {
      broken.add(socket);
    }
  }
  issues
    ..addAll(_ownerIssues(collection))
    ..addAll(_preflightIssues(collection));
  for (final module in resolution.modules) {
    issues.addAll(_kindIssues(module, collection));
  }

  final codegen = collection.applyingOf<CodegenRequest>().isNotEmpty;
  // First, so that a module whose constraint conflicts is at fault.
  final merged = mergePubspec([
    if (codegen)
      const Collected(codegenDependency, PipelineOrigin(), applies: true),
    ...collection.all,
  ]);
  final pubspec = merged.pubspec;
  if (pubspec.sdk == null && merged.issues.isEmpty) {
    issues.add(
      const SmfIssue(
        'No module sets the Dart SDK constraint of the app, which pub needs '
        'in every pubspec.yaml.',
        hint: 'The module that generates pubspec.yaml contributes '
            'PubspecContribution.environment(sdk: ...).',
      ),
    );
  }
  final clash = pubspec.dependencies[context.appName] ??
      pubspec.devDependencies[context.appName];
  if (clash != null) {
    issues.add(
      SmfIssue(
        'The app is named ${context.appName}, like its dependency from '
        '${clash.origins.join(', ')}, and a package cannot depend on '
        'itself.',
        hint: 'Name the app differently.',
      ),
    );
  }
  issues
    ..addAll(merged.issues)
    ..addAll(_hookIssues(registry, resolution, collection, context));
  final tags = scanBricks(
    registry: registry,
    resolution: resolution,
    collection: collection,
  );
  issues
    ..addAll(tags.issues)
    ..addAll(_pubspecTagIssues(pubspec, tags, collection))
    ..addAll(_requiredValueIssues(resolution, collection));

  final bySocket = <SocketRef, List<Collected>>{};
  final postGen = <Collected>[];
  for (final collected in collection.applying) {
    switch (collected.contribution) {
      case final SocketContribution socket:
        bySocket.putIfAbsent(socket.socket, () => []).add(collected);
      case final PostGenStep step:
        postGen.add(collected);
        final needsTerminal = step.interactive && !interactive;
        final needsSetup = step.external && skipExternalSetup;
        if ((needsTerminal || needsSetup) && !step.skippable) {
          final why = needsTerminal
              ? 'without a terminal'
              : 'with --skip-external-setup';
          issues.add(
            SmfIssue(
              'The step ${step.description ?? step.tool.executable} of '
              '${collected.origin} cannot run $why, and the app is not '
              'complete without it.',
              origin: collected.origin,
            ),
          );
        }
      default:
        break;
    }
  }

  issues.addAll(
    _taglessIssues(
      {
        for (final MapEntry(key: socket, value: contributions)
            in bySocket.entries)
          if (!broken.contains(socket)) socket: contributions,
      },
      tags,
      resolution,
    ),
  );

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

/// The problems of [collected] with the rules of the pipeline: the roles in
/// its [Contribution.when], who may use which role and socket, and, for a
/// brick, its hooks, variables and files.
///
/// Stage 8 checks the fragments of the render hooks with it too.
Iterable<SmfIssue> contributionIssues(
  Collected collected,
  ModuleRegistry registry,
  Resolution resolution,
) sync* {
  final origin = collected.origin;
  final contribution = collected.contribution;
  final roles = rolesOf(origin, registry, resolution);

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
        if (isReservedVar(name)) {
          yield SmfIssue(
            'The brick ${brick.bundle.name} of $origin sets the variable '
            '$name, which the pipeline sets itself.',
            origin: origin,
          );
        }
      }
      for (final name in strippedVars(brick.vars)) {
        yield SmfIssue(
          'The variable $name of the brick ${brick.bundle.name} of $origin '
          'has a backslash before a line break or a non-ASCII character, '
          'which mason removes.',
          origin: origin,
        );
      }
      for (final name in nonPlainVars(brick.vars)) {
        yield SmfIssue(
          'The variable $name of the brick ${brick.bundle.name} of $origin '
          'is not plain data: strings, numbers, booleans, and lists and maps '
          'of them.',
          origin: origin,
        );
      }
      for (final file in brick.bundle.files) {
        // A path with a variable is checked once it is rendered.
        if (file.path.contains('{{')) continue;
        if (machineFileProblem(file.path) case final problem?) {
          yield SmfIssue(
            'The brick ${brick.bundle.name} of $origin generates '
            '${file.path}, which $problem.',
            hint: 'Remove the file from the brick.',
            origin: origin,
            path: file.path,
          );
        }
      }
      if (origin case ModuleOrigin(:final module)) {
        final kind = resolution.module(module)?.descriptor.kind;
        for (final file in brick.bundle.files) {
          // A path with a variable is checked once it is rendered.
          if (kind != null &&
              !file.path.contains('{{') &&
              !kind.allowsFile(module, file.path)) {
            yield SmfIssue(
              'The module $module generates ${file.path}, where modules of '
              'the ${kind.id} kind may not.',
              origin: origin,
              path: file.path,
            );
          }
        }
      }
    case CodegenRequest(:final outputs):
      for (final output in outputs) {
        if (!_isDartPathInApp(output)) {
          yield SmfIssue(
            'The output $output of the code generation of $origin is not '
            'the path of a Dart file inside the app, such as '
            'lib/core/di/dependencies.config.dart.',
            origin: origin,
          );
        }
      }
    case Preflight() || PubspecContribution() || PostGenStep():
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

/// Whether [path] is the relative path of a Dart file inside the app, with
/// forward slashes.
bool _isDartPathInApp(String path) {
  final segments = path.split('/');
  return path.endsWith('.dart') &&
      !path.contains(r'\') &&
      !path.contains(':') &&
      segments.every((s) => s.isNotEmpty && s != '.' && s != '..');
}

/// Preflight checks whose ids are not lower snake_case or not unique for
/// their contributor, which the pipeline keys their results by.
Iterable<SmfIssue> _preflightIssues(Collection collection) sync* {
  final ids = <String, Set<String>>{};
  for (final collected in collection.all) {
    if (collected.contribution case Preflight(:final checks)) {
      final origin = collected.origin;
      final seen = ids.putIfAbsent(contributorName(origin), () => {});
      for (final check in checks) {
        if (!SmfNames.isSnakeCase(check.id) || !seen.add(check.id)) {
          yield SmfIssue(
            'The preflight check "${check.id}" of $origin needs a lower '
            'snake_case id that its other checks do not have.',
            origin: origin,
          );
        }
      }
    }
  }
}

/// A socket for one value of a present role or of a module of the app that
/// cannot render without one, such as the minimum iOS version, but got
/// none: the providers of the role, or the module, contribute its base
/// value.
Iterable<SmfIssue> _requiredValueIssues(
  Resolution resolution,
  Collection collection,
) sync* {
  final contributed = {
    for (final collected in collection.applyingOf<SocketContribution>())
      (collected.contribution as SocketContribution).socket,
  };
  bool missing(SocketRef socket) => switch (socket.kind) {
        ValueSocket(required: true) => !contributed.contains(socket),
        _ => false,
      };
  for (final role in resolution.presentRoles) {
    for (final socket in role.sockets.where(missing)) {
      final providers = resolution.providersOf(role);
      yield SmfIssue(
        'The $socket needs a value, but nothing contributes one; the '
        'provider of the ${role.id} contributes its base value.',
        origin: providers.length == 1 ? providers.single.origin : null,
      );
    }
  }
  for (final module in resolution.modules) {
    for (final socket in module.descriptor.sockets.where(missing)) {
      yield SmfIssue(
        'The $socket needs a value, but nothing contributes one; the module '
        '${module.id} contributes its base value.',
        origin: module.origin,
      );
    }
  }
}

/// Contributions to a socket whose tag no brick of the app holds, so their
/// code would be lost.
///
/// The template that lacks the tag is at fault: that of the only provider of
/// the socket's role, or of the module that owns the socket. The tag of a
/// member of a role's family may be in the files of any module, so no one
/// is named for it.
Iterable<SmfIssue> _taglessIssues(
  Map<SocketRef, List<Collected>> bySocket,
  BrickTags tags,
  Resolution resolution,
) sync* {
  for (final MapEntry(key: socket, value: contributions) in bySocket.entries) {
    if (tags.found.containsKey(socket)) continue;
    final contributors = {
      for (final collected in contributions) collected.origin,
    };
    final providers = switch (socket.role) {
      final role? when socket.familyKey.isEmpty => resolution.providersOf(role),
      _ => const <ResolvedModule>[],
    };
    final owner = switch (socket.module) {
      final module? => resolution.module(module)?.origin,
      null => providers.length == 1 ? providers.single.origin : null,
    };
    yield SmfIssue(
      '${contributors.join(', ')} '
      '${contributors.length == 1 ? 'contributes' : 'contribute'} to the '
      '$socket, but no template of the app has its tag '
      '${socket.tags.join(', ')}, so what they contribute would be lost.',
      origin: owner,
    );
  }
}

/// A section of [pubspec] that has entries but whose tag the brick with
/// `pubspec.yaml` lacks, so it would be lost.
///
/// Without such a brick there is nothing to check here; the contract
/// harness reports every tag of the pipeline missing.
Iterable<SmfIssue> _pubspecTagIssues(
  MergedPubspec pubspec,
  BrickTags tags,
  Collection collection,
) sync* {
  final owner = [
    for (final collected in collection.applyingOf<BrickContribution>())
      if ((collected.contribution as BrickContribution)
          .bundle
          .files
          .any((file) => file.path == 'pubspec.yaml'))
        collected.origin,
  ].firstOrNull;
  if (owner == null) return;
  final texts = pubspecSocketTexts(pubspec);
  for (final socket in PipelineSockets.all) {
    if (texts[socket.tag]!.isEmpty || tags.found.containsKey(socket)) {
      continue;
    }
    yield SmfIssue(
      'The pubspec.yaml of $owner has no tag ${socket.tag}, so that section '
      'of the pubspec would be lost.',
      hint: 'Put {{{${socket.tag}}}} at the start of a line of pubspec.yaml.',
      origin: owner,
    );
  }
}

/// Two bricks that generate the same file.
///
/// A path with a variable is left to stage 8, which compares the rendered
/// paths.
Iterable<SmfIssue> _ownerIssues(Collection collection) sync* {
  final owners = <String, ContributionOrigin>{};
  for (final collected in collection.applyingOf<BrickContribution>()) {
    final brick = collected.contribution as BrickContribution;
    for (final file in brick.bundle.files) {
      if (file.path.contains('{{')) continue;
      final existing = owners[file.path];
      owners[file.path] = collected.origin;
      if (existing != null) {
        final who = existing == collected.origin
            ? 'Two bricks of $existing generate'
            : 'Both $existing and ${collected.origin} generate';
        yield SmfIssue(
          '$who ${file.path}; every file has one brick.',
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
  ModuleRegistry registry,
  Resolution resolution,
  Collection collection,
  ModuleContext context,
) sync* {
  final request = hookRequest(
    registry: registry,
    resolution: resolution,
    collection: collection,
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
