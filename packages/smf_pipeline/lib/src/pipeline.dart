import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/choices.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/explain.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/identity.dart';
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

  /// The contributions of each socket that apply, in order.
  ///
  /// These are the contributions known before rendering; stage 8 adds the
  /// fragments of the render hooks of roles and providers, and orders the
  /// sockets again.
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

/// The app that `smf create` generated.
final class GeneratedApp {
  /// Creates the record of the app [name] at [path].
  const GeneratedApp({
    required this.name,
    required this.path,
    this.leftOut = const [],
    this.skippedSteps = const [],
  });

  /// The package name of the app, such as `my_app`.
  final String name;

  /// The absolute path of the app's directory.
  final String path;

  /// The modules lenient mode left out.
  final List<LeftOut> leftOut;

  /// The post-generation steps that did not run, with their commands for
  /// the user to run later.
  final List<SkippedStep> skippedSteps;
}

/// The `create` command of SMF: generates a Flutter app from the modules of
/// a [registry].
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

  /// Generates the app of [request] and returns it, or `null` after
  /// `--explain` printed what would happen.
  ///
  /// It plans the app in the stages 1 to 7 (see [CreatePlanning.plan]),
  /// then:
  /// 8. Rendering: the files of the app, in memory.
  /// 9. Post-generation: in a temporary directory, `flutter pub get`, code
  ///    generation, the steps of the modules, `dart fix` and
  ///    `dart format`.
  /// 10. Moving: the app goes to its directory, without the files Flutter
  ///    writes with the temporary path, and `flutter pub get` writes them
  ///    again there.
  ///
  /// If a stage after rendering fails, the app stays in the temporary
  /// directory, which the error names.
  ///
  /// Throws a [GenerationFailedException] with the errors found, or an
  /// [SmfUsageException] for a problem of the command line.
  Future<GeneratedApp?> run(CreateRequest request) async {
    final plan = await this.plan(request);
    if (plan == null) return null;
    try {
      return await _generate(plan);
    } finally {
      await plan.environment.dispose();
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
      );
    } on Object {
      rendering.fail();
      rethrow;
    }
    rendering.complete();

    final temporary =
        await fileSystem.systemTempDirectory.createTemp('smf_create_');
    final directory = temporary.childDirectory(plan.context.appName);
    for (final file in app.files.values) {
      final written = fileSystem.file(
        fileSystem.path.joinAll([directory.path, ...file.path.split('/')]),
      );
      await written.parent.create(recursive: true);
      await written.writeAsBytes(file.bytes);
    }

    final target = plan.selection.target;
    final List<SkippedStep> skipped;
    try {
      skipped = await runPostGen(
        directory: directory.path,
        environment: environment,
        steps: plan.postGenOrder.contributions,
        codegen: plan.collection.applyingOf<CodegenRequest>().isNotEmpty,
        fullDartFix: plan.request.dartFix,
      );
      await moveApp(fileSystem, source: directory.path, target: target);
    } on GenerationFailedException catch (error) {
      throw GenerationFailedException(
        '${error.message}\nThe app so far is in ${directory.path}.',
        issues: error.issues,
      );
    }
    await temporary.delete(recursive: true);
    await getPackagesInPlace(environment, target.path);
    return GeneratedApp(
      name: plan.context.appName,
      path: target.path,
      leftOut: plan.leftOut,
      skippedSteps: skipped,
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

    final lenience = _Lenience(strict: request.strict, logger: logger);
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
        // --explain asks nothing, but tells what a run with the same
        // terminal would do.
        interactive: host.hasTerminal && request.input,
        skipExternalSetup: request.skipExternalSetup,
      );
      if (lenience.leaveOut(validation.issues)) {
        continue;
      }

      final preflight = await runPreflight(
        plannedChecks(collection, sdkCheck),
        environment,
        explain: request.explain,
        strict: request.strict,
        pubspec: validation.pubspec,
        known: checked,
      );
      if (!request.explain && lenience.leaveOut(preflight.issues)) {
        continue;
      }

      if (request.explain) {
        explain(
          selection: selection,
          context: context,
          resolution: resolution,
          validation: validation,
          preflight: preflight,
          leftOut: lenience.leftOut,
          strict: request.strict,
          onConflict: request.onConflict,
          sdkIssues: preflight.versionIssues,
          codegen: [
            for (final collected in collection.applyingOf<CodegenRequest>())
              collected.origin,
          ],
        ).forEach(logger.info);
        await environment.dispose();
        return null;
      }

      for (final module in resolution.modules) {
        if (module.reason is! Requested) {
          logger.info('Adding ${module.id}: ${module.reason}.');
        }
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
        leftOut: List.unmodifiable(lenience.leftOut),
      );
    }
  }
}

/// What lenient mode has decided so far in a run: the modules it left out
/// and the warnings already reported.
final class _Lenience {
  _Lenience({required this.strict, required this.logger});

  final bool strict;
  final SmfLogger logger;
  final Set<ModuleId> excluded = {};
  final List<LeftOut> leftOut = [];
  final Set<String> _warned = {};

  /// Reports the warnings among [issues], each once per run, and decides
  /// what their errors mean: nothing if there are none, a retry without the
  /// modules at fault if lenient mode can leave them all out (returns
  /// `true`), or a [GenerationFailedException] otherwise.
  bool leaveOut(List<SmfIssue> issues) {
    for (final issue in issues) {
      if (!issue.isError && _warned.add('$issue')) logger.warn('$issue');
    }
    final errors = [
      for (final issue in issues)
        if (issue.isError) issue,
    ];
    if (errors.isEmpty) return false;
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
    if (strict || culprits.isEmpty) {
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
