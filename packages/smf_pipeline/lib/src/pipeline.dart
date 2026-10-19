import 'package:file/file.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/choices.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/explain.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/identity.dart';
import 'package:smf_pipeline/src/manual_steps.dart';
import 'package:smf_pipeline/src/move.dart';
import 'package:smf_pipeline/src/order.dart';
import 'package:smf_pipeline/src/postgen.dart';
import 'package:smf_pipeline/src/preflight.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/render.dart';
import 'package:smf_pipeline/src/request.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/selection.dart';
import 'package:smf_pipeline/src/validation.dart';

/// A module that lenient mode left out, and why.
final class LeftOut {
  /// Creates the record.
  const LeftOut(this.module, this.reason);

  /// The module.
  final ModuleId module;

  /// The problem that made the pipeline leave it out.
  final String reason;
}

/// Everything the stages 1 to 7 decided, which the rendering stages turn
/// into an app.
final class GenerationPlan {
  /// Creates the plan.
  const GenerationPlan({
    required this.request,
    required this.selection,
    required this.context,
    required this.resolution,
    required this.collection,
    required this.socketOrders,
    required this.postGenOrder,
    required this.manualSteps,
    required this.setupLink,
    required this.pubspec,
    required this.preflight,
    required this.choices,
    required this.environment,
    this.leftOut = const [],
  });

  /// The command line.
  final CreateRequest request;

  /// What the user asked for, and where the app goes.
  final Selection selection;

  /// The app being generated.
  final ModuleContext context;

  /// The modules of the app and the roles they provide.
  final Resolution resolution;

  /// The contributions of the modules and role templates, decided by the
  /// [choices]: a contribution with conditions on what roles chose applies
  /// only where they hold (see [Collection.decide]).
  final Collection collection;

  /// The contributions of each socket that apply, in order.
  ///
  /// These are the contributions known before rendering; stage 8 adds the
  /// fragments of the render hooks of roles and providers, and orders the
  /// sockets again.
  final Map<SocketRef, ContributionOrder> socketOrders;

  /// The post-generation steps that apply, in the order they run.
  final ContributionOrder postGenOrder;

  /// The steps of the app that its developer does by hand, which stage 5
  /// planned before the roles chose (see [ValidationResult.manualSteps]).
  final List<PlannedManualStep> manualSteps;

  /// The link to the guide of the [manualSteps], which the front end named
  /// for them (see [ValidationResult.setupLink]).
  final Uri? setupLink;

  /// The merged `pubspec.yaml`.
  final MergedPubspec pubspec;

  /// The state of the machine.
  final PreflightReport preflight;

  /// The results of the roles' `choose` hooks.
  final Map<Role, Object?> choices;

  /// The environment of the run, with the Flutter SDK and the directories
  /// of installed tools. The caller disposes of it.
  final PipelineEnvironment environment;

  /// The modules lenient mode left out.
  final List<LeftOut> leftOut;
}

/// The app that `smf create` generated.
final class GeneratedApp {
  /// Creates the record of the app [name] at [path].
  const GeneratedApp({
    required this.name,
    required this.path,
    this.leftOut = const [],
    this.skippedSteps = const [],
    this.manualSteps = const [],
    this.setupLink,
  });

  /// The package name of the app, such as `my_app`.
  final String name;

  /// The absolute path of the app's directory.
  final String path;

  /// The modules lenient mode left out.
  final List<LeftOut> leftOut;

  /// The post-generation steps that did not run, with their commands for
  /// the user to run later, and their notices.
  final List<SkippedStep> skippedSteps;

  /// The steps of the setup of the app that its developer does by hand,
  /// since no command can do them, each once and in order (see
  /// [ManualStep]).
  final List<ManualStep> manualSteps;

  /// The page that guides the developer through the [manualSteps], which
  /// the [CreatePipeline.setupLink] of the front end named for them, or
  /// `null` for an app without steps or a front end that names no page.
  final Uri? setupLink;
}

/// The `create` command of SMF: generates a Flutter app from the modules of
/// a [registry].
///
/// The pipeline knows no role and no module: everything specific comes from
/// the [registry] and the hooks of its roles.
final class CreatePipeline {
  /// Creates the pipeline for the modules of [registry] on [host], which
  /// names the guide of the steps by hand of an app with [setupLink].
  const CreatePipeline({
    required this.registry,
    required this.host,
    this.setupLink,
  });

  /// The modules the CLI offers.
  final ModuleRegistry registry;

  /// The machine the pipeline runs on.
  final SmfHost host;

  /// Names the page that guides the developer through the steps by hand of
  /// an app (see [SetupLink]), or `null` for a front end that names none:
  /// then the app has no link to its steps.
  final SetupLink? setupLink;

  /// Generates the app of [request] and returns it, or `null` after
  /// `--explain` printed what would happen.
  ///
  /// It plans the app in the stages 1 to 7: selection, identity,
  /// resolution, collection, validation, preflight checks and the choices of
  /// the roles. Then:
  /// 8. Rendering: the files of the app, in memory.
  /// 9. Post-generation: in a temporary directory, `flutter pub get`, code
  ///    generation, the steps of the modules, `dart fix` and
  ///    `dart format`.
  /// 10. Moving: the app goes to its directory, without the files Flutter
  ///    writes with the temporary path, and `flutter pub get` writes them
  ///    again there.
  ///
  /// If a stage after rendering fails, the app stays in the temporary
  /// directory, which the error names. If the user cancels the run before
  /// the app is in its place, nothing of it stays.
  ///
  /// Throws a [GenerationFailedException] with the errors found, and with
  /// `--strict` the warnings about what the app is made of that stopped it
  /// (see [plan]), an [SmfUsageException] for a problem of the command
  /// line, or an [SmfCancelledException] when the user cancels the run.
  Future<GeneratedApp?> run(CreateRequest request) async {
    final plan = await this.plan(request);
    if (plan == null) return null;
    try {
      return await _generate(plan);
    } finally {
      try {
        await plan.environment.dispose();
      } on FileSystemException catch (error) {
        plan.environment.logger.warn(
          'The temporary files of the run could not be deleted: $error',
        );
      }
    }
  }

  Future<GeneratedApp> _generate(GenerationPlan plan) async {
    final environment = plan.environment;
    final fileSystem = environment.fileSystem;
    final logger = environment.logger;

    final rendering = logger.progress('Rendering the app');
    final RenderedApp app;
    try {
      app = renderApp(
        registry: registry,
        resolution: plan.resolution,
        collection: plan.collection,
        context: plan.context,
        choices: plan.choices,
        pubspec: plan.pubspec,
        manualSteps: plan.manualSteps,
        setupLink: plan.setupLink,
      );
    } on Object {
      rendering.fail();
      rethrow;
    }
    rendering.complete();

    final temporary =
        await fileSystem.systemTempDirectory.createTemp('smf_create_');
    final directory = temporary.childDirectory(plan.context.appName);
    logger.detail('Generating the app in ${directory.path}');

    final List<SkippedStep> skipped;
    try {
      for (final file in app.files.values) {
        final written = fileSystem.file(
          fileSystem.path.joinAll([directory.path, ...file.path.split('/')]),
        );
        await written.parent.create(recursive: true);
        await written.writeAsBytes(file.bytes);
      }
      skipped = await runPostGen(
        directory: directory.path,
        environment: environment,
        steps: plan.postGenOrder.contributions,
        codegen: plan.collection.applyingOf<CodegenRequest>().toList(),
        checks: plan.preflight.results,
        fullDartFix: plan.request.dartFix,
      );
    } on GenerationFailedException catch (error) {
      throw GenerationFailedException(
        '${error.message}\nThe app so far is in ${directory.path}.',
        issues: error.issues,
      );
    } on FileSystemException catch (error) {
      throw GenerationFailedException(
        'The app could not be written: $error\nThe app so far is in '
        '${directory.path}.',
      );
    } on SmfCancelledException {
      // The user stopped the run, so nothing of it stays behind.
      await _deleteTemporary(temporary, logger);
      rethrow;
    } on Object {
      // A bug; the app is still worth finding.
      logger.warn('The app so far is in ${directory.path}.');
      rethrow;
    }
    // Its errors say where the app stays.
    final target = plan.selection.target;
    await moveApp(
      fileSystem,
      source: directory.path,
      target: target,
      logger: logger,
    );
    await _deleteTemporary(temporary, logger);
    await getPackagesInPlace(environment, target.path);
    return GeneratedApp(
      name: plan.context.appName,
      path: target.path,
      leftOut: plan.leftOut,
      skippedSteps: skipped,
      manualSteps: [for (final planned in plan.manualSteps) planned.step],
      setupLink: plan.setupLink,
    );
  }
}

/// Deletes [temporary], the temporary directory of a run, or warns if it
/// cannot.
Future<void> _deleteTemporary(Directory temporary, SmfLogger logger) async {
  try {
    await temporary.delete(recursive: true);
  } on FileSystemException catch (error) {
    logger.warn(
      'The temporary directory ${temporary.path} could not be deleted: '
      '$error',
    );
  }
}

/// The stages 1 to 7 of `smf create`, which [CreatePipeline.run] runs
/// before it renders the app. The tests of the pipeline run them alone.
extension CreatePlanning on CreatePipeline {
  /// Runs the stages 1 to 7 for [request] and returns the plan, or `null`
  /// after `--explain` printed what would happen.
  ///
  /// 1. Selection: the app, its directory and the modules asked for.
  /// 2. Identity: the names and platform identifiers of the app.
  /// 3. Resolution: the modules and roles the app needs.
  /// 4. Collection: the contributions of the modules and role templates.
  /// 5. Validation: the rules of the model and the checks of the roles, and
  ///    the plan of the steps that the developer of the app does by hand,
  ///    with the link to their guide (see [CreatePipeline.setupLink]).
  /// 6. Preflight: the machine has what generation needs.
  /// 7. Choices: what only the user can decide, such as the start screen.
  ///    Then the contributions with conditions on what the roles chose
  ///    apply only where the conditions hold; the stages before take them
  ///    as contributions that apply.
  ///
  /// In lenient mode, the default, a problem caused by a module leaves that
  /// module out and the stages run again from 3 without it, unless no app
  /// can be made without the module, as without the only provider of a role
  /// that every app has. With `--strict`, every error stops generation, and
  /// so does every warning about what the app is made of whose code
  /// `--allow-warning` does not name (see [CreateRequest.allowedWarnings]),
  /// after the stage that found it: a warning of the validation before the
  /// machine is checked, and a warning of a choice before the app is
  /// rendered. A warning about the machine never stops it.
  /// `--explain` runs the stages 1 to 5 and the read-only part of 6, prints
  /// what it found, and stops: it never asks, installs, logs in or chooses.
  /// So with `--strict` it stops on a warning of the validation, but not on
  /// a warning of a choice, which the same run without `--explain` stops
  /// on.
  ///
  /// Throws a [GenerationFailedException] with the errors found, and with
  /// `--strict` the warnings about what the app is made of that stopped it,
  /// or an [SmfUsageException] for a problem of the command line.
  Future<GenerationPlan?> plan(CreateRequest request) async {
    final environment = PipelineEnvironment(
      host,
      interactive: host.hasTerminal && request.input && !request.explain,
      skipExternalSetup: request.skipExternalSetup,
    );
    try {
      return await _plan(request, environment);
    } on Object {
      await environment.dispose();
      rethrow;
    }
  }

  Future<GenerationPlan?> _plan(
    CreateRequest request,
    PipelineEnvironment environment,
  ) async {
    final logger = environment.logger;
    final selection = await select(request, registry, environment);
    final context =
        AppNames.contextOf(name: selection.appName, org: selection.org);

    final lenience = _Lenience(
      registry,
      strict: request.strict,
      allowedWarnings: request.allowedWarnings,
      logger: logger,
    );
    final answers = <Role, ModuleId>{};
    final checked = <String, CheckResult>{};
    final sdkCheck = FlutterSdkCheck(
      environment.fileSystem,
      explain: request.explain,
    );

    while (true) {
      final resolved = await resolve(
        requested: selection.requested,
        registry: registry,
        environment: environment,
        declined: selection.declined,
        excluded: lenience.excluded,
        answers: answers,
        explain: request.explain,
      );
      if (lenience.leaveOut(resolved.issues)) {
        continue;
      }
      final resolution = resolved.resolution!;

      final collection = collect(resolution, context);
      final validation = validate(
        registry: registry,
        resolution: resolution,
        collection: collection,
        context: context,
        optionValues: request.roleOptions,
        // --explain asks nothing, but tells what a run with the same
        // terminal would do.
        interactive: host.hasTerminal && request.input,
        skipExternalSetup: request.skipExternalSetup,
        setupLink: setupLink,
      );
      if (lenience.leaveOut(validation.issues)) {
        continue;
      }

      final preflight = await runPreflight(
        plannedChecks(collection, sdkCheck, resolution),
        environment,
        explain: request.explain,
        strict: request.strict,
        canDoWithout: lenience.canDoWithout,
        pubspec: validation.pubspec,
        known: checked,
      );
      if (!request.explain && lenience.leaveOut(preflight.issues)) {
        continue;
      }

      if (request.explain) {
        Explanation(
          selection: selection,
          context: context,
          resolution: resolution,
          validation: validation,
          preflight: preflight,
          leftOut: lenience.leftOut,
          strict: request.strict,
          canDoWithout: lenience.canDoWithout,
          operatingSystem: environment.operatingSystem,
          onConflict: request.onConflict,
          sdkIssues: preflight.versionIssues,
          codegen: _codegenOrigins(collection),
        ).lines.forEach(logger.info);
        await environment.dispose();
        return null;
      }

      _reportAdded(resolution, logger);
      final (:choices, issues: chosen) = await chooseRoles(
        resolution: resolution,
        collection: collection,
        optionValues: request.roleOptions,
        environment: environment,
        context: context,
      );
      // It reports the warnings of the choices, and with --strict stops on
      // them, before anything is rendered. Their errors are of the
      // templates of roles, which lenient mode cannot leave out, so it
      // stops on them rather than plan the app again.
      lenience.leaveOut(chosen);
      return GenerationPlan(
        request: request,
        selection: selection,
        context: context,
        resolution: resolution,
        collection: collection.decide(choices, resolution.presentRoles),
        socketOrders: validation.socketOrders,
        postGenOrder: validation.postGenOrder,
        manualSteps: validation.manualSteps,
        setupLink: validation.setupLink,
        pubspec: validation.pubspec,
        preflight: preflight,
        choices: choices,
        environment: environment,
        leftOut: List.unmodifiable(lenience.leftOut),
      );
    }
  }
}

/// Who asks for code generation among [collection].
List<ContributionOrigin> _codegenOrigins(Collection collection) => [
      for (final collected in collection.applyingOf<CodegenRequest>())
        collected.origin,
    ];

/// Tells about each module of [resolution] that the user did not ask for
/// why it is in the app.
void _reportAdded(Resolution resolution, SmfLogger logger) {
  for (final module in resolution.modules) {
    if (module.reason is! Requested) {
      logger.info('Adding ${module.id}: ${module.reason}.');
    }
  }
}

/// What lenient mode has decided so far in a run: the modules it left out
/// and the warnings already reported.
final class _Lenience {
  _Lenience(
    this.registry, {
    required this.strict,
    required this.allowedWarnings,
    required this.logger,
  });

  final ModuleRegistry registry;
  final bool strict;

  /// The codes of the warnings about what the app is made of that do not
  /// stop a run with [strict].
  final Set<String> allowedWarnings;
  final SmfLogger logger;
  final Set<ModuleId> excluded = {};
  final List<LeftOut> leftOut = [];
  final Set<String> _warned = {};

  /// Whether an app can be made without [modules] and the modules left out
  /// so far; see [_canDoWithout].
  bool canDoWithout(Set<ModuleId> modules) =>
      _canDoWithout(registry, {...excluded, ...modules});

  /// Reports the warnings among [issues] that do not stop the run, each
  /// once per run, and decides what the others mean: nothing if there are
  /// none, a retry without the modules at fault if lenient mode can leave
  /// them all out (returns `true`), or a [GenerationFailedException]
  /// otherwise.
  ///
  /// With [strict], the errors and the warnings about what the app is made
  /// of stop the run, but for those whose codes are among the
  /// [allowedWarnings]; a warning about the machine never does. Lenient
  /// mode stops on no warning, and does not leave out modules that no app
  /// can be made without: their errors, with the hints that tell how to fix
  /// them, stop generation.
  bool leaveOut(List<SmfIssue> issues) {
    final stopping = <SmfIssue>[];
    for (final issue in issues) {
      if (issue.isError || _stops(issue)) {
        stopping.add(issue);
      } else if (_warned.add('$issue')) {
        // The logger marks a warning itself.
        logger.warn(issueLine(issue));
      }
    }
    if (stopping.isEmpty) return false;
    final errors = [
      for (final issue in stopping)
        if (issue.isError) issue,
    ];
    final culprits = _culpritsOf(errors);
    if (strict || culprits.isEmpty || !canDoWithout(culprits.keys.toSet())) {
      throw GenerationFailedException(
        _stoppedBy(errors.length, stopping.length - errors.length),
        issues: stopping,
      );
    }
    for (final MapEntry(key: module, value: reason) in culprits.entries) {
      excluded.add(module);
      leftOut.add(LeftOut(module, reason));
      logger.warn('Leaving out $module: $reason');
    }
    return true;
  }

  /// Whether [warning] stops the run: a warning about what the app is made
  /// of, with [strict], whose code is not among the [allowedWarnings].
  bool _stops(SmfIssue warning) =>
      strict &&
      warning.category == WarningCategory.composition &&
      !allowedWarnings.contains(warning.code);

  /// The modules that caused [errors], each with the message of its first
  /// error, or none if an error has no module that lenient mode can still
  /// leave out.
  Map<ModuleId, String> _culpritsOf(List<SmfIssue> errors) {
    final culprits = <ModuleId, String>{};
    for (final error in errors) {
      if (error.origin case ModuleOrigin(:final module)
          when !excluded.contains(module)) {
        culprits.putIfAbsent(module, () => error.message);
      } else {
        return const {};
      }
    }
    return culprits;
  }
}

/// Why generation stopped, because of [errors] errors and [warnings]
/// warnings about what the app is made of, which stop only a run with
/// `--strict`.
String _stoppedBy(int errors, int warnings) {
  final causes = [
    if (errors == 1) 'an error' else if (errors > 1) '$errors errors',
    if (warnings == 1)
      'a warning about the app'
    else if (warnings > 1)
      '$warnings warnings about the app',
  ];
  final goesOn = errors > 0
      ? ''
      : ' Without --strict, the run goes on after '
          '${warnings == 1 ? 'it' : 'them'}.';
  return 'Generation stopped because of ${causes.join(' and ')}.$goesOn';
}

/// Whether [registry] can make an app without the modules [without]: every
/// role that each app has exactly one of keeps a provider that is not among
/// them and neither depends on one of them nor requires a role whose
/// providers are all among them, directly or not.
///
/// Without such a provider, the resolution stops generation anyway, since
/// every app needs the role. So lenient mode keeps a module that the app
/// cannot do without, such as the only provider of the app entry, and stops
/// at its own problem, which tells how to fix it.
bool _canDoWithout(ModuleRegistry registry, Set<ModuleId> without) {
  final gone = {...without};
  bool isGone(SmfModule module) => gone.contains(module.descriptor.id);
  var changed = true;
  while (changed) {
    changed = false;
    for (final module in registry.modules) {
      if (isGone(module)) continue;
      final descriptor = module.descriptor;
      if (descriptor.dependsOn.any(gone.contains) ||
          descriptor.effectiveRequires
              .any((role) => registry.providersOf(role).every(isGone))) {
        gone.add(descriptor.id);
        changed = true;
      }
    }
  }
  return registry.roles.every(
    (role) =>
        role.cardinality != RoleCardinality.exactlyOne ||
        registry.providersOf(role).any((module) => !isGone(module)),
  );
}
