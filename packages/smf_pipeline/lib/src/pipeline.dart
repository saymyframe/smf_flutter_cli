import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/choices.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/explain.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/identity.dart';
import 'package:smf_pipeline/src/order.dart';
import 'package:smf_pipeline/src/preflight.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/registry.dart';
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

  /// The contributions of the modules and role templates.
  final Collection collection;

  /// The contributions of each socket that apply, in their final order.
  final Map<SocketRef, ContributionOrder> socketOrders;

  /// The post-generation steps that apply, in the order they run.
  final ContributionOrder postGenOrder;

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

/// The stages of `smf create` up to the choices of the roles: what to
/// generate, checked, with the machine ready for it.
///
/// The pipeline knows no role and no module: everything specific comes from
/// the [registry] and the hooks of its roles.
final class CreatePipeline {
  /// Creates the pipeline for the modules of [registry] on [host].
  const CreatePipeline({required this.registry, required this.host});

  /// The modules the CLI offers.
  final ModuleRegistry registry;

  /// The machine the pipeline runs on.
  final SmfHost host;

  /// Runs the stages 1 to 7 for [request] and returns the plan, or `null`
  /// after `--explain` printed what would happen.
  ///
  /// 1. Selection: the app, its directory and the modules asked for.
  /// 2. Identity: the names and platform identifiers of the app.
  /// 3. Resolution: the modules and roles the app needs.
  /// 4. Collection: the contributions of the modules and role templates.
  /// 5. Validation: the rules of the model and the checks of the roles.
  /// 6. Preflight: the machine has what generation needs.
  /// 7. Choices: what only the user can decide, such as the start screen.
  ///
  /// In lenient mode, the default, a problem caused by a module leaves that
  /// module out and the stages run again from 3 without it; with `--strict`
  /// every error stops generation. `--explain` runs the stages 1 to 5 and
  /// the read-only part of 6, prints what it found, and stops: it never
  /// asks, installs, logs in or chooses.
  ///
  /// Throws a [GenerationFailedException] with the errors found, or an
  /// [SmfUsageException] for a problem of the command line.
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

    final excluded = <ModuleId>{};
    final leftOut = <LeftOut>[];
    final answers = <Role, ModuleId>{};
    final passed = <String>{};
    final sdkCheck = FlutterSdkCheck();

    while (true) {
      final resolved = await resolve(
        requested: selection.requested,
        registry: registry,
        environment: environment,
        declined: selection.declined,
        excluded: excluded,
        answers: answers,
      );
      if (_leaveOut(resolved.issues, request, excluded, leftOut, logger)) {
        continue;
      }
      final resolution = resolved.resolution!;

      final collection = collect(resolution, context);
      final validation = validate(
        registry: registry,
        resolution: resolution,
        collection: collection,
        context: context,
      );
      if (_leaveOut(validation.issues, request, excluded, leftOut, logger)) {
        continue;
      }

      final preflight = await runPreflight(
        plannedChecks(collection, sdkCheck),
        environment,
        explain: request.explain,
        passed: passed,
      );
      if (sdkCheck.found case final sdk?) environment.sdk = sdk;
      if (!request.explain &&
          _leaveOut(preflight.issues, request, excluded, leftOut, logger)) {
        continue;
      }

      if (request.explain) {
        explain(
          selection: selection,
          context: context,
          resolution: resolution,
          validation: validation,
          preflight: preflight,
          leftOut: leftOut,
          strict: request.strict,
        ).forEach(logger.info);
        await environment.dispose();
        return null;
      }

      final choices = await chooseRoles(
        registry: registry,
        resolution: resolution,
        collection: collection,
        optionValues: request.roleOptions,
        environment: environment,
        context: context,
      );
      return GenerationPlan(
        request: request,
        selection: selection,
        context: context,
        resolution: resolution,
        collection: collection,
        socketOrders: validation.socketOrders,
        postGenOrder: validation.postGenOrder,
        pubspec: validation.pubspec,
        preflight: preflight,
        choices: choices,
        environment: environment,
        leftOut: List.unmodifiable(leftOut),
      );
    }
  }

  /// Reports the warnings among [issues] and decides what their errors
  /// mean: nothing if there are none, a retry without the modules at fault
  /// if lenient mode can leave them all out (returns `true`), or a
  /// [GenerationFailedException] otherwise.
  bool _leaveOut(
    List<SmfIssue> issues,
    CreateRequest request,
    Set<ModuleId> excluded,
    List<LeftOut> leftOut,
    SmfLogger logger,
  ) {
    final errors = [
      for (final issue in issues)
        if (issue.isError) issue,
    ];
    if (errors.isEmpty) {
      for (final issue in issues) {
        logger.warn('$issue');
      }
      return false;
    }
    final culprits = <ModuleId, String>{};
    for (final error in errors) {
      if (error.origin case ModuleOrigin(:final module)
          when !excluded.contains(module)) {
        culprits.putIfAbsent(module, () => error.message);
      } else {
        culprits.clear();
        break;
      }
    }
    if (request.strict || culprits.isEmpty) {
      throw GenerationFailedException(
        errors.length == 1
            ? 'Generation stopped because of an error.'
            : 'Generation stopped because of ${errors.length} errors.',
        issues: errors,
      );
    }
    for (final MapEntry(key: module, value: reason) in culprits.entries) {
      excluded.add(module);
      leftOut.add(LeftOut(module, reason));
      logger.warn('Leaving out $module: $reason');
    }
    return true;
  }
}
