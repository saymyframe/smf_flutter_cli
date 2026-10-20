/// The guide of the steps of the setup of an app that its developer does by
/// hand (see [ManualStep]), and the catalog of the steps of the modules of
/// `smf create`, which the site of SMF keeps a copy of and a guide for each
/// step of.
///
/// The catalog is `setup_steps.json` of the package ([setupStepsFile]),
/// which `tool/setup_steps.dart` writes with [setupStepsOf] and
/// [SetupCatalog.next]. It serves the repository of SMF, and its API may
/// change in any release.
library;

import 'dart:convert';

import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

export 'src/setup_guide.dart';

/// The path of the catalog of the steps by hand in the package
/// `smf_flutter_cli`.
const setupStepsFile = 'setup_steps.json';

/// The kind of the owner of a step by hand (see [ManualStepId]).
enum SetupStepOwnerKind {
  /// A module, of a step of its own.
  module,

  /// A role, of a step that contributors which do not know each other
  /// share.
  role,
}

/// A step by hand of the catalog, as the site of SMF reads it.
final class SetupStep {
  /// Creates the step [id], titled [title], of [owner].
  const SetupStep({
    required this.id,
    required this.title,
    required this.owner,
    required this.ownerKind,
    required this.ownerName,
    required this.neededBy,
  });

  /// The step of [json], an object of the catalog (see [toJson]).
  factory SetupStep.fromJson(Map<String, Object?> json) => SetupStep(
        id: json['id']! as String,
        title: json['title']! as String,
        owner: json['owner']! as String,
        ownerKind: SetupStepOwnerKind.values.byName(
          json['ownerKind']! as String,
        ),
        ownerName: json['ownerName']! as String,
        neededBy: [
          for (final module in json['neededBy']! as List<Object?>)
            module! as String,
        ],
      );

  /// The id of the step as the link to its guide carries it,
  /// `<owner>.<name>` (see [ManualStepId.wire]), which names it for good.
  final String id;

  /// What the developer does (see [ManualStep.title]).
  final String title;

  /// The id of the module or of the role whose step it is (see
  /// [ManualStepId.owner]).
  final String owner;

  /// Whether a module or a role owns the step.
  final SetupStepOwnerKind ownerKind;

  /// The owner as the guide names it: for a module its id, the name that
  /// `smf create -m` takes, and for a role its description, such as
  /// `App entry` (see [Role.description]), since a developer never names a
  /// role by its id.
  final String ownerName;

  /// The ids of the modules that bring the step into an app, sorted (see
  /// [setupStepsOf]).
  final List<String> neededBy;

  /// The step as an object of the catalog, with its keys in the order of
  /// the copy of the catalog on the site of SMF.
  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'owner': owner,
        'ownerKind': ownerKind.name,
        'ownerName': ownerName,
        'neededBy': neededBy,
      };
}

/// The catalog of the steps by hand of the modules of `smf create`: the
/// [steps] of their apps today, and the [retired] steps, which no app has
/// any more.
///
/// The link of a run names a step for good, so the site of SMF keeps the
/// guide of every step that the catalog ever had: a step that leaves the
/// apps moves to [retired], and stays there unless it comes back (see
/// [next]).
final class SetupCatalog {
  /// Creates the catalog of [steps] and [retired] steps.
  const SetupCatalog({this.steps = const [], this.retired = const []});

  /// The catalog of [text], as [render] writes it.
  factory SetupCatalog.parse(String text) {
    final json = jsonDecode(text) as Map<String, Object?>;
    List<SetupStep> stepsOf(String key) => [
          for (final step in json[key]! as List<Object?>)
            SetupStep.fromJson(step! as Map<String, Object?>),
        ];
    return SetupCatalog(steps: stepsOf('steps'), retired: stepsOf('retired'));
  }

  /// The steps of the apps, in the order of [setupStepsOf].
  final List<SetupStep> steps;

  /// The steps that the apps no longer have, in the order of their ids.
  final List<SetupStep> retired;

  /// The catalog that follows this one for [steps], the steps of the apps
  /// now: its retired steps are those of this catalog and the steps that
  /// left the apps, each as this catalog has it, but for a step that is
  /// among [steps] again, in the order of their ids.
  SetupCatalog next(List<SetupStep> steps) {
    final current = {for (final step in steps) step.id};
    final retired = {
      // A step of the apps of this catalog replaces a retired step with
      // its id, which a catalog written by hand could have.
      for (final step in [...this.retired, ...this.steps])
        if (!current.contains(step.id)) step.id: step,
    };
    return SetupCatalog(
      steps: List.unmodifiable(steps),
      retired: List.unmodifiable([
        for (final id in retired.keys.toList()..sort()) retired[id]!,
      ]),
    );
  }

  /// The catalog as the text of [setupStepsFile]: JSON indented by two
  /// spaces, with a final line break.
  String render() => '${const JsonEncoder.withIndent('  ').convert({
            'steps': [for (final step in steps) step.toJson()],
            'retired': [for (final step in retired) step.toJson()],
          })}\n';
}

/// The steps by hand of the apps of [modules], the modules of `smf create`,
/// each once by its id, for the catalog (see [SetupCatalog.next]).
///
/// The contract harness validates, without rendering, the apps of every
/// case of [ContractHarness.checkAll] and the apps with every module
/// ([ContractHarness.casesOfAll]), and a step is in the catalog when one of
/// those apps has it (see [ContractResult.manualSteps]). The apps of the
/// other values of the mode options of the roles have the steps of the
/// apps with the first values, since no step depends on what a role chose
/// (see [RoleTemplate.manualSteps]).
///
/// Of a step, [SetupStep.neededBy] has each module that lists it, in an
/// app, itself or in a variant, and for the template of a role that lists
/// it, the modules that provide the role in that app. The steps come in
/// the order that an app with every module lists them in, those of the
/// first such app first, which has the first provider of each role, then
/// those that only the next apps with every module have, in their order,
/// and then the steps of the smaller apps by id: those of a hook that
/// lists a step for an app without some role, for instance. So the order
/// of the steps that a developer of a full app does stays, and the file
/// changes only with the steps of the modules.
///
/// Throws a [StateError] when an app has errors, since the steps of such
/// an app would come from modules that `smf create` refuses, and when two
/// apps give one step two titles, which the pipeline cannot see: it checks
/// the titles of a step within an app.
Future<List<SetupStep>> setupStepsOf(List<SmfModule> modules) async {
  final harness = ContractHarness(ModuleRegistry(modules), render: false);
  final everyModule = [
    for (final contractCase in harness.casesOfAll())
      await harness.check(contractCase),
  ];
  final results = [...everyModule, ...await harness.checkAll()];
  final failed = [
    for (final result in results)
      if (result.errors.isNotEmpty)
        '${result.contractCase.name}: ${result.errors.join(' ')}',
  ];
  if (failed.isNotEmpty) {
    throw StateError(
      'The apps of the steps by hand have errors:\n${failed.join('\n')}',
    );
  }

  final steps = _StepsOfApps();
  for (final (index, result) in results.indexed) {
    steps.add(result, everyModule: index < everyModule.length);
  }
  return steps.inOrder();
}

/// The steps by hand that [setupStepsOf] collects from its apps, one app
/// after another, each step once by its id ([ManualStepId.wire]).
final class _StepsOfApps {
  /// Each step as the first app that has it gives it, with the name of
  /// that app.
  final _steps = <String, (ManualStep, String)>{};

  /// The modules that bring each step into an app, in any of the apps.
  final _neededBy = <String, Set<String>>{};

  /// The ids of the steps of the apps with every module, in the order in
  /// which those apps list them, those of the first app first.
  final _ordered = <String>[];

  /// The lines of the error about the steps that an app gives another
  /// title than the first app with the step gave them, by the id of the
  /// step and that title, each from the first app with that title.
  final _conflicts = <(String, String), String>{};

  /// Adds the steps of the app of [result], an app with every module if
  /// [everyModule].
  void add(ContractResult result, {required bool everyModule}) {
    for (final planned in result.manualSteps) {
      final step = planned.step;
      final wire = step.id.wire;
      final app = result.contractCase.name;
      if (_steps[wire] case (final first, final firstApp)) {
        if (first.title != step.title) {
          _conflicts.putIfAbsent(
            (wire, step.title),
            () => '$wire: "${first.title}" in $firstApp, "${step.title}" in '
                '$app',
          );
        }
      } else {
        _steps[wire] = (step, app);
        if (everyModule) _ordered.add(wire);
      }
      _neededBy
          .putIfAbsent(wire, () => {})
          .addAll(_neededByIn(planned, result));
    }
  }

  /// The steps in the order of the catalog, each with the modules that
  /// bring it into an app: those of the apps with every module in their
  /// order, then the others by id (see [setupStepsOf]).
  ///
  /// Throws a [StateError] when two apps gave one step two titles.
  List<SetupStep> inOrder() {
    if (_conflicts.isNotEmpty) {
      throw StateError(
        'Steps by hand have two titles, but the catalog has one for each '
        'step:\n${_conflicts.values.join('\n')}',
      );
    }
    final others = [
      for (final wire in _steps.keys)
        if (!_ordered.contains(wire)) wire,
    ]..sort();
    return List.unmodifiable([
      for (final wire in [..._ordered, ...others])
        _catalogStep(_steps[wire]!.$1, _neededBy[wire]!),
    ]);
  }

  /// The modules that bring [planned], a step of the app of [result], into
  /// that app: each module among its contributors, itself or in a variant,
  /// and for the template of a role among them, the modules that provide
  /// the role in the app.
  static List<String> _neededByIn(
    PlannedManualStep planned,
    ContractResult result,
  ) {
    final modules = <String>[];
    for (final origin in planned.contributors) {
      if (origin case ModuleOrigin(:final module)) modules.add('$module');
      if (origin case RoleTemplateOrigin(:final role)) {
        modules.addAll([
          for (final provider in result.resolution!.providersOf(role))
            '${provider.id}',
        ]);
      }
    }
    return modules;
  }
}

/// [step] as the catalog has it, with [neededBy], the modules that bring
/// it into an app.
SetupStep _catalogStep(ManualStep step, Set<String> neededBy) {
  final id = step.id;
  final role = id.role;
  return SetupStep(
    id: id.wire,
    title: step.title,
    owner: id.owner,
    ownerKind:
        role == null ? SetupStepOwnerKind.module : SetupStepOwnerKind.role,
    ownerName: role?.description ?? id.owner,
    neededBy: List.unmodifiable(neededBy.toList()..sort()),
  );
}
