/// The matrix of apps that the continuous integration of SMF generates
/// with `smf create` and analyzes with Flutter: every app that the contract
/// harness builds for a set of modules, and the apps with every module, of
/// which CI also builds a covering for Android and iOS and starts it on
/// devices, one app for each job of the plan of CI; the apps whose tests
/// must fail, which show that the tests can fail; and the versions of
/// Flutter that its nightly run checks them with.
///
/// It serves the repository of SMF, and its API may change in any release.
library;

import 'dart:convert';
import 'dart:io' show Platform, Process, stdout;
import 'dart:isolate' show Isolate;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/src/cli.dart';
import 'package:smf_flutter_cli/src/expected_failures.dart';
import 'package:smf_flutter_cli/src/matrix_plan.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

export 'src/expected_failures.dart';
export 'src/flutter_versions.dart';
export 'src/matrix_plan.dart';

/// An app of the matrix: the modules to ask for, which name every module of
/// the app so that no question is left, and the options of its roles.
final class MatrixApp {
  /// Creates the app that the contract harness built for [name].
  const MatrixApp(
    this.name,
    this.modules, {
    this.roleOptions = const {},
    this.everyModuleWith,
    this.hook,
  });

  /// The case of the contract harness that the app comes from.
  final String name;

  /// The modules of the app.
  final List<ModuleId> modules;

  /// The values of role options by name.
  final Map<String, String?> roleOptions;

  /// For an app with every module, one of those that the contract harness
  /// builds for each combination of the providers of the roles that take
  /// one (see [ContractHarness.casesOfAll]): the providers of its roles
  /// that take one other than the first registered provider of each, in
  /// the order of the roles, such as `[riverpod]` for the app with riverpod
  /// rather than bloc, and none for the app with the first provider of
  /// every role. The providers of a role that takes many, which every app
  /// with every module has, set no app apart. `null` for any other app of
  /// the matrix.
  ///
  /// Unlike the [name] of the case, which names the provider of every role
  /// that has several, they stay the same when another role gets a second
  /// provider.
  final List<ModuleId>? everyModuleWith;

  /// The name of the package of this app with every module among the apps
  /// generated as [base]: [base] and the ids of [everyModuleWith] after it,
  /// such as `start_app` and `start_app_riverpod`. So the app keeps its
  /// name when another role gets a second provider, and so do the ids that
  /// come from it, by which an external service may know the app.
  String packageName(String base) => [base, ...?everyModuleWith].join('_');

  /// The data and roles of the app, as for the hooks of its roles, with
  /// the choices that the roles made when the contract harness rendered
  /// it, which `smf create` makes the same with the [roleOptions]; `null`
  /// for an app that the harness did not build.
  ///
  /// A role reads what it chose for the app from the input that
  /// [Role.hookInput] builds of it, such as the route the app starts on,
  /// so a [MatrixAppTest] can expect what the app does without knowing
  /// its modules.
  final RoleHookRequest? hook;

  /// The arguments of `smf create` that generate the app as [appName] in
  /// [directory], as CI does: without questions, external setup or the
  /// full `dart fix`, and failing instead of leaving out a module.
  List<String> createArguments(String appName, String directory) => [
        'create',
        appName,
        '-m',
        modules.join(','),
        for (final MapEntry(:key, :value) in roleOptions.entries)
          if (value != null) '--$key=$value',
        '-o',
        directory,
        '--on-conflict',
        'replace',
        '--no-input',
        '--skip-external-setup',
        '--no-dart-fix',
        '--strict',
      ];

  @override
  String toString() => '$name (${modules.join(', ')})';
}

/// The apps of the matrix of [modules]: every app that the contract harness
/// builds for them, which covers every module and every provider with each
/// subset of the roles it uses, and the apps with every module, one for each
/// combination of the providers of roles that take one
/// (see [everyModuleAppsOf]).
///
/// Each app gets [roleOptions], the values of role options for every app,
/// the options of its case, and the answers of the harness to the
/// questions of the roles that they leave open (see
/// [ContractResult.answers]), such as `--start` with the first of several
/// screens that can start the app: `smf create` then makes the same
/// choices without a terminal. It gets the choices too, with the data and
/// roles of its case ([MatrixApp.hook]). The harness renders each app in
/// memory first, so a case that it finds errors in is among the `failed`
/// ones, since its app could not be generated.
///
/// An app with every module that another case built already is that app,
/// which then has the [MatrixApp.everyModuleWith] of the app with every
/// module. The apps with every module are those of [everyModuleApps], such
/// as a pairwise covering of them; the contract harness checks all of them
/// anyway, and those that fail are among the `failed` ones.
Future<({List<MatrixApp> apps, List<ContractResult> failed})> matrixOf(
  List<SmfModule> modules, {
  Map<String, String?> roleOptions = const {},
  EveryModuleSelection everyModuleApps = EveryModuleCombinations.all,
}) async {
  final harness = ContractHarness(
    ModuleRegistry(modules),
    roleOptions: roleOptions,
  );
  final apps = <MatrixApp>[];
  final failed = <ContractResult>[];
  for (final result in await harness.checkAll()) {
    switch (_appOf(result, roleOptions)) {
      case final app?:
        apps.add(app);
      case null:
        failed.add(result);
    }
  }
  final everyModule = await everyModuleAppsOf(
    modules,
    roleOptions: roleOptions,
  );
  failed.addAll(everyModule.failed);
  for (final app in everyModuleApps.select(everyModule.apps, modules)) {
    final index = apps.indexWhere((other) => _keyOf(other) == _keyOf(app));
    if (index < 0) {
      apps.add(app);
    } else {
      final other = apps[index];
      apps[index] = MatrixApp(
        other.name,
        other.modules,
        roleOptions: other.roleOptions,
        everyModuleWith: app.everyModuleWith,
        hook: other.hook,
      );
    }
  }
  return (apps: apps, failed: failed);
}

/// The apps with every module of [modules]: those that the contract
/// harness builds for each combination of the providers of the roles that
/// take one, each with as many modules as one app can have (see
/// [ContractHarness.casesOfAll]), with their [MatrixApp.everyModuleWith].
/// The apps and the options of their roles are those of [matrixOf].
///
/// With [withoutExternalSteps], they are the apps with every module that
/// needs nothing outside the app: without the modules whose steps after
/// generation need an external service, such as a network account
/// ([PostGenStep.external]), which a run that skips external setup leaves
/// for later, so that the app is complete once it is generated, and it
/// starts. The modules that depend on them, directly or not, and those
/// that are then left without a provider of a role they require, stay out
/// too, and each of the other roles gets one app for each of its
/// providers that are left.
Future<({List<MatrixApp> apps, List<ContractResult> failed})> everyModuleAppsOf(
  List<SmfModule> modules, {
  Map<String, String?> roleOptions = const {},
  bool withoutExternalSteps = false,
}) async {
  // The providers of each role in the order of all modules, which the
  // everyModuleWith of each app is relative to.
  final names = ModuleRegistry(modules);
  var registry = names;
  while (true) {
    final (:apps, :failed, :external) = await _everyModuleOf(
      ContractHarness(registry, roleOptions: roleOptions),
      names,
      roleOptions,
      withoutExternalSteps: withoutExternalSteps,
    );
    if (external.isEmpty) return (apps: apps, failed: failed);
    registry = ModuleRegistry(_without(registry.modules, external));
  }
}

/// The apps with every module of the registry of [harness], with their
/// [MatrixApp.everyModuleWith] relative to the providers of [names], and
/// the cases that failed. With [withoutExternalSteps], the modules of the
/// apps whose steps need an external service, which [everyModuleAppsOf]
/// then leaves out; otherwise none.
Future<
    ({
      List<MatrixApp> apps,
      List<ContractResult> failed,
      Set<ModuleId> external,
    })> _everyModuleOf(
  ContractHarness harness,
  ModuleRegistry names,
  Map<String, String?> roleOptions, {
  required bool withoutExternalSteps,
}) async {
  final apps = <MatrixApp>[];
  final failed = <ContractResult>[];
  final external = <ModuleId>{};
  for (final contractCase in harness.casesOfAll()) {
    final result = await harness.check(contractCase);
    final app = _appOf(
      result,
      roleOptions,
      everyModuleWith: _everyModuleWith(contractCase, names),
    );
    if (app == null) {
      failed.add(result);
      continue;
    }
    apps.add(app);
    if (withoutExternalSteps) {
      external.addAll(_withExternalSteps(result.validation!));
    }
  }
  return (apps: apps, failed: failed, external: external);
}

/// The providers that [contractCase], a case of an app with every module,
/// picks for the roles that take one other than the first provider of
/// their role in [names]; see [MatrixApp.everyModuleWith]. The pick of a
/// role that takes many is its first provider in the registry of the case,
/// which is another one when the apps without external steps leave the
/// first of [names] out, and the app has all of them anyway.
List<ModuleId> _everyModuleWith(
  ContractCase contractCase,
  ModuleRegistry names,
) =>
    [
      ...{
        for (final MapEntry(key: role, value: provider)
            in contractCase.picks.entries)
          if (!role.cardinality.allowsMany &&
              provider != names.providersOf(role).first.descriptor.id)
            provider,
      },
    ];

/// The app of the matrix that [result] built with the values of role
/// options [roleOptions], or `null` if the case has errors. The harness of
/// the matrix renders every app, so a case without errors has the request
/// that the hooks of the roles got ([ContractResult.hook]).
MatrixApp? _appOf(
  ContractResult result,
  Map<String, String?> roleOptions, {
  List<ModuleId>? everyModuleWith,
}) {
  final resolution = result.resolution;
  if (result.errors.isNotEmpty || resolution == null) return null;
  return MatrixApp(
    '${result.contractCase}',
    [for (final module in resolution.modules) module.id],
    roleOptions: {
      ...roleOptions,
      ...result.contractCase.roleOptions,
      ...result.answers,
    },
    everyModuleWith: everyModuleWith,
    hook: result.hook,
  );
}

/// The modules of [app], which tell it apart from the other apps of the
/// matrix: the variants of the modules follow from them.
String _keyOf(MatrixApp app) =>
    ([for (final module in app.modules) module.value]..sort()).join(',');

/// The modules whose steps after generation in the app that [validation]
/// checked need an external service ([PostGenStep.external]). A step that
/// continues a step of another module (see [PostGenStep.followUpOf]) is a
/// step of the module that contributes it.
Set<ModuleId> _withExternalSteps(ValidationResult validation) => {
      for (final collected in validation.postGenOrder.contributions)
        if (collected
            case Collected(
              contribution: PostGenStep(external: true),
              origin: ModuleOrigin(:final module),
            ))
          module,
    };

/// [modules] without those of [removed], without those that depend on one
/// of them, directly or not, and without those that are then left without a
/// provider of a role they require.
List<SmfModule> _without(List<SmfModule> modules, Set<ModuleId> removed) {
  final gone = {...removed};
  var kept = modules;
  while (true) {
    kept = [
      for (final module in kept)
        if (!gone.contains(module.descriptor.id)) module,
    ];
    final lost = _lostOf(kept, gone);
    if (lost.isEmpty) return kept;
    gone.addAll(lost);
  }
}

/// The modules of [kept] that depend on a module of [gone], or require a
/// role that no module of [kept] provides.
Set<ModuleId> _lostOf(List<SmfModule> kept, Set<ModuleId> gone) {
  final provided = {for (final module in kept) ...module.descriptor.provides};
  return {
    for (final module in kept)
      if (module.descriptor.dependsOn.any(gone.contains) ||
          !provided.containsAll(module.descriptor.effectiveRequires))
        module.descriptor.id,
  };
}

/// What the checks of the repository need to know of each of [tests], as
/// JSON, which the matrix tools print with `--app-tests --json`
/// (`tools/app_tests_test.dart`):
/// - `directory`, the directory of its files;
/// - `modules`, the ids of the modules of the matrix that the package whose
///   `app_tests` holds the directory declares, by [packages], the package
///   of each module of the matrix, such as `smf_home_flutter` for `home`;
/// - `appliesWithout`, the names of the apps of the matrix that it applies
///   to once those modules are taken out of their modules, and out of their
///   [MatrixApp.everyModuleWith], with the same name, role options and
///   hook;
/// - `uses`, the modules of the matrix whose ids it uses: those that, with
///   another id in their place in an app of the matrix, change whether it
///   applies to the app, the values of its files there or the files it
///   generates there. Each has the id of the module (`module`), its
///   package (`package`) and the names of those apps (`apps`), in the
///   order of the apps;
/// - `roles`, the ids of the roles whose contract it checks
///   ([MatrixAppTest.roles]), such as `router`;
/// - `roleFunctionUses`, the uses, in its Dart files, of the functions of
///   the roles of [modules], the modules of the matrix, that an app can
///   have several providers of. Each has the path of the file from the
///   directory and the function (`use`), such as `test/a_test.dart:
///   createCrashReporter() of lib/core/crash_reporting/crash_reporter.dart`,
///   and the id of the role of the function (`role`), such as
///   `crash_reporting`.
///
/// The app tests that a package of modules keeps test its modules, so they
/// apply only to the apps that have one of them, whichever other modules
/// the matrix has: a check of the start of every app that the provider of
/// the app entry kept would reach no app with another provider. And what
/// they depend on of the other modules of an app comes from its roles
/// ([MatrixApp.hook]), not from the ids of its modules: the screen that an
/// app starts on is the choice of the router role, which a second feature
/// that can start the app, or `--start`, changes while the app keeps the
/// modules it had. [apps] gives the apps of the matrix, which it builds
/// once, if there are [tests].
///
/// An app test of a module runs in every app with its module, whatever else
/// the app has, so it uses no function of a role that reaches every
/// provider of the role, such as `createCrashReporter()`, whose reporter
/// reports to all of them: what another provider does, only the tests of
/// its own module know. A test of the contract of such a role calls them,
/// since what the role does with every provider is its contract, and looks
/// only at what reaches the providers that it knows; the checks of the
/// repository tell it from the others by its `roles` and the role of each
/// use. Such functions are the public top-level functions of the files of
/// the interface of each role that an app can have several providers of,
/// in the app of each of its providers that the contract harness renders
/// first, and a use is a call or a tear-off through an import of their
/// file as `package:{{app_name}}/...`, with a prefix or without. Throws a
/// [StateError] if the harness renders no such app, or one without a file
/// of the interface of the role.
Future<List<Map<String, Object>>> appTestsReport(
  List<MatrixAppTest> tests, {
  required List<SmfModule> modules,
  required Map<ModuleId, String> packages,
  required Future<List<MatrixApp>> Function() apps,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final path = const LocalFileSystem().path;
  final appTests = {
    for (final package in {...packages.values})
      package: await appTestsDirectoryOf(package),
  };
  final functions = await _roleFunctionsOf(modules);
  List<MatrixApp>? all;
  final report = <Map<String, Object>>[];
  for (final test in tests) {
    final matrix = all ??= await apps();
    final ids = {
      for (final MapEntry(key: id, value: package) in packages.entries)
        if (path.isWithin(appTests[package]!, test.directory)) id,
    };
    report.add({
      'directory': test.directory,
      'modules': [for (final id in ids) id.value],
      'appliesWithout':
          ids.isEmpty ? const <String>[] : _appliesWithout(test, ids, matrix),
      'uses': [
        for (final MapEntry(key: id, value: names)
            in _usesOf(test, matrix).entries)
          {'module': id.value, 'package': packages[id]!, 'apps': names},
      ],
      'roles': [for (final role in test.roles) role.id],
      'roleFunctionUses': _roleFunctionUses(
        test.directory,
        functions,
        fileSystem,
      ),
    });
  }
  return report;
}

/// The uses of [functions], the functions of roles by the path of their
/// file in the app, in the Dart files of the tests in [directory], each
/// with the path of the file from [directory] and the use, and the id of
/// the role; none if [directory] does not exist, which the checks of the
/// repository find otherwise.
List<Map<String, String>> _roleFunctionUses(
  String directory,
  Map<String, _RoleFunctions> functions,
  FileSystem fileSystem,
) {
  if (!fileSystem.directory(directory).existsSync()) return const [];
  final context = fileSystem.path;
  return [
    for (final (relative, file) in _filesOf(directory, fileSystem))
      if (context.split(relative).join('/') case final path
          when path.endsWith('.dart'))
        for (final (:use, :role) in _roleFunctionUsesIn(
          DartFileIndexer.index(path, file.readAsStringSync()),
          functions,
        ))
          {'use': '$path: $use', 'role': role.id},
  ];
}

/// A role and the names of its functions in one file of its interface.
typedef _RoleFunctions = ({Role role, Set<String> names});

/// The functions of the roles of [modules] that an app can have several
/// providers of, by the path in the app of the file of the role that
/// declares them, such as `lib/core/crash_reporting/crash_reporter.dart`:
/// the public top-level functions of the files of the interface of each
/// such role, in the app of each of its providers that the contract harness
/// renders first; see [appTestsReport].
Future<Map<String, _RoleFunctions>> _roleFunctionsOf(
  List<SmfModule> modules,
) async {
  final harness = ContractHarness(ModuleRegistry(modules));
  final functions = <String, _RoleFunctions>{};
  for (final module in modules) {
    final roles = [
      for (final role in module.descriptor.provides)
        if (role.cardinality.allowsMany) role,
    ];
    if (roles.isEmpty) continue;
    final id = module.descriptor.id;
    final app = await _firstAppOf(harness, id, roles);
    for (final role in roles) {
      for (final path in role.interface.files) {
        (functions[path] ??= (role: role, names: {}))
            .names
            .addAll(_publicFunctionsOf(app, id, role, path));
      }
    }
  }
  return functions;
}

/// The app of the module [id] that the contract [harness] renders first, in
/// which the module provides [roles].
Future<RenderedApp> _firstAppOf(
  ContractHarness harness,
  ModuleId id,
  List<Role> roles,
) async {
  final result = await harness.check(harness.casesOfModule(id).first);
  final app = result.app;
  if (app == null) {
    throw StateError(
      'The contract harness renders no app of $id, which provides the '
      '${roles.join(', the ')}: ${result.errors.join('; ')}',
    );
  }
  return app;
}

/// The names of the public top-level functions of [path], a file of the
/// interface of [role], in [app], the app of the module [id].
List<String> _publicFunctionsOf(
  RenderedApp app,
  ModuleId id,
  Role role,
  String path,
) {
  final file = app.files[path];
  if (file == null) {
    throw StateError(
      'The app of $id that the contract harness renders has no $path '
      'of the $role.',
    );
  }
  return [
    for (final declaration
        in DartFileIndexer.index(path, file.text).declarations)
      if (declaration.kind == DeclarationKind.function &&
          !declaration.name.startsWith('_'))
        declaration.name,
  ];
}

/// The uses in [file], a Dart file of app tests, of the [functions] of
/// roles by the path of their file in the app: calls and tear-offs through
/// an import of that file as `package:{{app_name}}/...`, with a prefix or
/// without, each as `<function>() of <path>`, with the role of the
/// function.
List<({String use, Role role})> _roleFunctionUsesIn(
  DartFileIndex file,
  Map<String, _RoleFunctions> functions,
) =>
    [
      for (final MapEntry(key: path, value: (:role, :names))
          in functions.entries)
        for (final name in _usedThrough(
          _importsOf(
            file,
            'package:{{app_name}}/${path.substring('lib/'.length)}',
          ),
          file,
          names,
        ))
          (use: '$name() of $path', role: role),
    ];

/// How a Dart file imports a library: without a prefix, and with which
/// prefixes; neither if it does not import the library.
typedef _Imports = ({bool unprefixed, Set<String> prefixes});

/// How [file] imports the library [uri].
_Imports _importsOf(DartFileIndex file, String uri) {
  final imports = [
    for (final import in file.imports)
      if (import.uri == uri) import,
  ];
  return (
    unprefixed: imports.any((import) => import.prefix == null),
    prefixes: {
      for (final import in imports)
        if (import.prefix case final prefix?) prefix,
    },
  );
}

/// The [names] of a library that [file] calls or tears off through its
/// [imports] of the library.
Set<String> _usedThrough(
  _Imports imports,
  DartFileIndex file,
  Set<String> names,
) {
  final (:unprefixed, :prefixes) = imports;
  bool through(String? target) =>
      target == null ? unprefixed : prefixes.contains(target);
  return {
    for (final call in file.invocations)
      if (names.contains(call.name) && through(call.target)) call.name,
    if (unprefixed)
      ...file.references
          .map((reference) => reference.name)
          .where(names.contains),
    for (final access in file.memberAccesses)
      if (names.contains(access.name) && prefixes.contains(access.target))
        access.name,
  };
}

/// The directory `app_tests` of the package [package], next to its `lib/`
/// in the configuration of the packages of this program: the directory of
/// the files of the [MatrixAppTest]s that the package keeps, each in a
/// directory of its own.
Future<String> appTestsDirectoryOf(String package) async {
  final path = const LocalFileSystem().path;
  return path.join(
    path.dirname(
      path.fromUri(
        await Isolate.resolvePackageUri(Uri.parse('package:$package/')),
      ),
    ),
    'app_tests',
  );
}

/// The names of [apps] that [test] applies to once the modules [ids] are
/// taken out of their modules and their [MatrixApp.everyModuleWith], with
/// the same name, role options and hook.
List<String> _appliesWithout(
  MatrixAppTest test,
  Set<ModuleId> ids,
  List<MatrixApp> apps,
) =>
    [
      for (final app in apps)
        if (test.appliesTo(
          MatrixApp(
            app.name,
            [
              for (final id in app.modules)
                if (!ids.contains(id)) id,
            ],
            roleOptions: app.roleOptions,
            everyModuleWith:
                app.everyModuleWith?.where((id) => !ids.contains(id)).toList(),
            hook: app.hook,
          ),
        ))
          app.name,
    ];

/// The modules of [apps] whose ids [test] uses, each with the names of the
/// apps where another id in its place changes whether [test] applies, the
/// values of its files or the files it generates; in the order of the apps
/// and of their modules.
Map<ModuleId, List<String>> _usesOf(
  MatrixAppTest test,
  List<MatrixApp> apps,
) {
  final uses = <ModuleId, List<String>>{};
  for (final app in apps) {
    for (final id in app.modules) {
      if (_usesId(test, app, id)) (uses[id] ??= []).add(app.name);
    }
  }
  return uses;
}

/// Whether [test] uses the id of the module [id] of [app]: whether it
/// applies to [app] with another id in place of [id] other than to [app],
/// or fills the values of its files, or generates files, there otherwise,
/// or throws there, as a test that looks the module up by its id does.
bool _usesId(MatrixAppTest test, MatrixApp app, ModuleId id) {
  final selection = _selectionOf(test, app);
  try {
    return _selectionOf(test, _renamed(app, id)) != selection;
  } on Object {
    return true;
  }
}

/// Whether [test] applies to [app] and, if it does, the values of its
/// files and the files it generates there, as text.
String _selectionOf(MatrixAppTest test, MatrixApp app) => test.appliesTo(app)
    ? jsonEncode([
        test.values?.call(app) ?? const <String, String>{},
        test.generatedFiles?.call(app, _packageOfUses) ??
            const <String, String>{},
      ])
    : '';

/// The name of the package that [_selectionOf] gives the apps whose files
/// a test generates: the same for every app, so that only what the app is
/// changes the files.
const _packageOfUses = 'matrix_app';

/// [app] with another id in place of the module [id], in its modules, its
/// [MatrixApp.everyModuleWith] and its name, as if another module took the
/// place of the module: with the same roles, role options and hook.
MatrixApp _renamed(MatrixApp app, ModuleId id) {
  ModuleId rename(ModuleId module) => module == id ? _otherModule : module;
  return MatrixApp(
    app.name.replaceAll(
      RegExp('\\b${RegExp.escape(id.value)}\\b'),
      _otherModule.value,
    ),
    [for (final module in app.modules) rename(module)],
    roleOptions: app.roleOptions,
    everyModuleWith: app.everyModuleWith?.map(rename).toList(),
    hook: app.hook,
  );
}

/// The id that [_renamed] puts in place of the id of a module.
const _otherModule = ModuleId('other_module');

/// Tests that the matrix adds to the apps it generates and runs with
/// `flutter test`: the files of a [directory] for the apps that
/// [appliesTo] accepts.
///
/// They check what only a running app shows, such as that the start-up of
/// the app works with the platform side of its plugins mocked, and a
/// package keeps them, such as the package of the module they test. They
/// are not part of the apps that `smf create` generates.
final class MatrixAppTest {
  /// Creates the tests of the files in [directory] for the apps that
  /// [appliesTo] accepts.
  const MatrixAppTest(
    this.directory, {
    required this.appliesTo,
    this.devDependencies = const [],
    this.values,
    this.generatedFiles,
    this.roles = const {},
    this.mocks,
    this.startProbe,
    this.readsStartProbes = false,
  });

  /// The directory of the files that go into an app, each at its path
  /// relative to the directory, such as `test/firebase_core_test.dart`,
  /// over the file of the app at that path, if the app has one.
  ///
  /// In the text of each file, `{{app_name}}` becomes the name of the
  /// package of the app, and `{{<key>}}` the value of each key of the
  /// [values] of the app. Hidden files stay out. The files of the tests of
  /// an app may use those of other tests that the app always has too, such
  /// as the tests of a module that another depends on, and those that the
  /// tests generate for the app ([generatedFiles]).
  final String directory;

  /// Whether the tests run in an app of the matrix.
  final bool Function(MatrixApp app) appliesTo;

  /// The packages that the tests use besides those of the app, which the
  /// matrix adds to the app as dev dependencies, such as the mocks of the
  /// platform side of a plugin.
  ///
  /// Each is a package as `flutter pub add` takes it after `dev:`: a
  /// hosted package by its name, or a package with its descriptor after
  /// `@`, such as `integration_test@{sdk: flutter}` for a package of the
  /// Flutter SDK.
  final List<String> devDependencies;

  /// The values of the placeholders of the files in an app of the matrix,
  /// besides `app_name`.
  final Map<String, String> Function(MatrixApp app)? values;

  /// The files that the matrix generates for the tests in an app of the
  /// matrix, next to the files of [directory], or `null` if they need none:
  /// the text of each by its path in the app, such as
  /// `integration_test/di_role/registered_services.dart`, for the app and
  /// the name of its package, which the imports of the files of the app
  /// take, as `package:<name>/...`. The matrix writes them as they are, with
  /// no placeholder filled.
  ///
  /// A test of a role needs to know what the modules of an app give the
  /// role, such as the services that they register in the DI container,
  /// and the files of [directory], the same in every app, cannot say it.
  /// The function writes it from the data of the roles of the app
  /// ([MatrixApp.hook]), such as the registrations of
  /// `diRole.graphOf(diRole.hookInput(app.hook!))`, and the files of
  /// [directory] import what it writes. So it takes what it needs of the
  /// modules of the app from their roles, as [values] do.
  final Map<String, String> Function(MatrixApp app, String packageName)?
      generatedFiles;

  /// The roles whose contract the tests check, whichever module provides
  /// each, such as the router role, whose provider calls the listeners of
  /// the screen once for each screen the user sees.
  ///
  /// Such tests apply to the apps of every provider of each of the roles,
  /// which [appliesTo] selects by the role, through the roles of the app
  /// ([MatrixApp.hook]), rather than by the ids of the modules that provide
  /// it; [runMatrix] fails when they apply to no app of one of them, or
  /// when they select their apps, take their [values] or generate their
  /// [generatedFiles] by the id of one of them (see [MatrixAppTests]).
  /// Tests of what only one provider does name no role.
  final Set<Role> roles;

  /// The mocks of the platform side of what the module of the tests runs in
  /// an app, such as its part of the start-up of the app and its services,
  /// or `null` if it needs none.
  ///
  /// An app runs the start-up and the services of all of its modules, and
  /// a test of any of them may run them, as a test that starts the app with
  /// `main()` does, while only the tests of each module know its platform
  /// side. So the matrix sets up the mocks of all the tests that apply to
  /// an app before the tests of each test file of the app, whichever module
  /// the file tests (see [addAppTests]), and the tests that apply to every
  /// app with a module declare the mocks of the module. A test file may set
  /// up mocks of its own after them, in its `setUpAll`, its `setUp` or its
  /// tests rather than while its `main()` declares them, such as mocks that
  /// record what reaches the platform side of its module.
  ///
  /// The mocks also put the app into the state that the tests of the other
  /// modules expect when they start it. So a module with a guard of the
  /// routes, which keeps the user from the screens of the app until a
  /// condition holds, opens the guard there: the tests of the other modules
  /// expect those screens, and the test of the walk of the routes fails on
  /// each guard that does not allow, by its name. A test of the module that
  /// needs the guard closed closes it again itself.
  final MatrixMocks? mocks;

  /// The probe of the tests for a check that runs on a device, such as the
  /// start check, or `null` if they have none: a function that goes through
  /// what the tests check in the running app, without a test framework, and
  /// returns what is wrong, such as the walk of the routes of the app.
  ///
  /// The matrix lists the probes of the tests that it adds to an app with a
  /// test that runs them ([readsStartProbes]); see [addAppTests].
  ///
  /// A probe depends on no other probe. It holds whichever probes ran
  /// before it, on whatever screen they left the app, and whichever guards
  /// of the routes allow on the device, where no mocks open one: the walk of
  /// the routes expects the target of a guard in place of each location
  /// that the guard keeps the user from.
  final MatrixStartProbe? startProbe;

  /// Whether the tests run the probes of the tests of the app
  /// ([startProbe]), as the start check does once the first screen of the
  /// app settled: with such tests, the matrix writes the list of the probes
  /// of the tests that it adds to the app, [startProbesFile], which they
  /// import.
  final bool readsStartProbes;
}

/// A function among the files of a [MatrixAppTest], in their directory
/// `integration_test/`, that a check on a device runs once the first screen
/// of the app settled (see [MatrixAppTest.startProbe]).
final class MatrixStartProbe {
  /// Creates the probe that the function [function] of the file at [path]
  /// is.
  const MatrixStartProbe(this.path, this.function);

  /// The path of the Dart file with the function among the files of the
  /// tests or those that they generate, in their directory
  /// `integration_test/`, such as `integration_test/router_walk/walk.dart`.
  final String path;

  /// The name of the top-level function of the file, of the type
  /// `Future<List<String>> Function(Future<void> Function() settle)`, such
  /// as `probeRoutes`. The check calls it with a function that waits until
  /// the screen settles, and adds the problems that it returns to its own.
  final String function;
}

/// The path in an app of the list of the probes of its tests, which
/// [addAppTests] writes for the tests that run them
/// ([MatrixAppTest.readsStartProbes]): `startProbes`, the name of the tests
/// of each probe and the probe, in the order of the tests.
const startProbesFile = 'integration_test/start_probes.dart';

/// A function among the files of a [MatrixAppTest] that sets up the mocks of
/// the platform side of what the module of the tests runs in an app (see
/// [MatrixAppTest.mocks]).
final class MatrixMocks {
  /// Creates the mocks that the function [function] of the file at [path]
  /// sets up.
  const MatrixMocks(this.path, this.function);

  /// The path of the Dart file with the function among the files of the
  /// tests, in their directory `test/`, such as
  /// `test/firebase_core_mocks.dart`.
  final String path;

  /// The name of the top-level function of the file that sets up the
  /// mocks, such as `mockFirebaseCore`. The matrix calls it without
  /// arguments once the binding of the tests is initialized, and leaves
  /// out what it returns, so it sets up the mocks before it returns.
  final String function;
}

/// The tests that a matrix adds to its apps, and the roles whose contract
/// they must check with every provider.
final class MatrixAppTests {
  /// Creates the [tests] of the apps, which must check the contract of
  /// each of [testedRoles].
  const MatrixAppTests(this.tests, {this.testedRoles = const {}});

  /// The tests of the apps.
  final List<MatrixAppTest> tests;

  /// The roles whose contract some of the [tests] must check with every
  /// provider of each, such as the router role (see [MatrixAppTest.roles]).
  final Set<Role> testedRoles;

  /// The problems of the tests of roles in the matrix of [modules], whose
  /// apps are [apps]: for each role of the [tests] and of [testedRoles],
  /// and each module that provides it and is in [apps], a test of the role
  /// that applies to none of the apps of the module, or that selects its
  /// apps, takes its values or generates its files by the id of the
  /// module, and no test of a role of [testedRoles] at all.
  ///
  /// A provider of the role that the tests leave out, such as one that a
  /// module adds later, is a problem, since its apps would be generated and
  /// analyzed, but nothing would check at runtime that it keeps the
  /// contract of the role. So is a test that tells the providers apart by
  /// their ids, which a new provider would not have: with another id in
  /// place of that of a provider in one of its apps, it must apply to the
  /// app, fill its values and generate its files as before.
  List<String> roleProblems(List<SmfModule> modules, List<MatrixApp> apps) {
    final roles = {...testedRoles, for (final test in tests) ...test.roles};
    return [
      for (final role in roles) ..._problemsOfRole(role, modules, apps),
    ];
  }

  /// The problems of the tests of [role] with the modules of [modules] that
  /// provide it, in the matrix whose apps are [apps].
  List<String> _problemsOfRole(
    Role role,
    List<SmfModule> modules,
    List<MatrixApp> apps,
  ) {
    final ofRole = [
      for (final test in tests)
        if (test.roles.contains(role)) test,
    ];
    return [
      for (final module in modules)
        if (module.descriptor.provides.contains(role))
          ..._problemsOfProvider(role, module.descriptor.id, ofRole, apps),
    ];
  }

  /// The problems of [ofRole], the tests of [role], with the module [id],
  /// which provides it, in the matrix whose apps are [apps]: none if the
  /// matrix has no app of the module, whose cases failed.
  static List<String> _problemsOfProvider(
    Role role,
    ModuleId id,
    List<MatrixAppTest> ofRole,
    List<MatrixApp> apps,
  ) {
    final withModule = [
      for (final app in apps)
        if (app.modules.contains(id)) app,
    ];
    if (withModule.isEmpty) return const [];
    if (ofRole.isEmpty) return [_untested(role, id)];
    final problems = <String>[];
    for (final test in ofRole) {
      final using = [
        for (final app in withModule)
          if (_usesId(test, app, id)) app.name,
      ];
      if (!withModule.any(test.appliesTo)) {
        problems.add(_leftOut(test, role, id));
      } else if (using.isNotEmpty) {
        problems.add(_byId(test, role, id, using));
      }
    }
    return problems;
  }

  /// The problem that no test checks [role], which the module [id]
  /// provides.
  static String _untested(Role role, ModuleId id) =>
      'No test of the $role applies to an app with $id, which provides it: '
      'nothing checks at runtime that $id keeps the contract of the role.';

  /// The problem that [test], a test of [role], leaves out the module
  /// [id], which provides it.
  static String _leftOut(MatrixAppTest test, Role role, ModuleId id) =>
      'The tests of ${test.directory} check the $role, but apply to no app '
      'with $id, which provides it: a test of a role applies to the apps of '
      'every provider of the role, which it selects by the role.';

  /// The problem that [test], a test of [role], selects its apps, takes its
  /// values or generates its files by the id of the module [id], which
  /// provides it, in the apps [using].
  static String _byId(
    MatrixAppTest test,
    Role role,
    ModuleId id,
    List<String> using,
  ) =>
      'The tests of ${test.directory} check the $role, but select their apps, '
      'take the values of their files or generate files by the id of $id, '
      'which provides it: with another module in its place, they would apply '
      'otherwise, or get other values or files, in these apps of the matrix: '
      '${using.join(', ')}. A test of a role takes what it needs of the '
      'providers of the role from the roles of the app (MatrixApp.hook), such '
      'as whether the app has the role (presentRoles), so that a new provider '
      'of the role gets the test as it is.';
}

/// Copies the files of [tests] into the app of the matrix [app], generated
/// in [directory] with the package [packageName], with the placeholders
/// of the files filled, writes the files that the tests generate for the
/// app next to them, and returns the paths of the files in the app; see
/// [MatrixAppTest.directory] and [MatrixAppTest.generatedFiles].
///
/// Without [app], for an app that `smf create` generated outside the
/// matrix, only `{{app_name}}` is filled: the [MatrixAppTest.values] come
/// from an app of the matrix, and so do the files that the tests generate.
///
/// If some of the [tests] declare [MatrixAppTest.mocks], it also writes the
/// configuration of the tests of the app, `test/flutter_test_config.dart`,
/// with which `flutter test` runs each test file in `test/`: in a
/// `setUpAll` that runs before those of the file, it initializes the
/// binding of the tests and calls the function of the mocks of each of
/// those tests, in the order of the [tests]. So the mocks of every module
/// of an app are set up for the tests of each module, which the tests of
/// the matrix and the tests added to an app outside it get alike.
///
/// If some of the [tests] run the probes of the tests of the app
/// ([MatrixAppTest.readsStartProbes]), such as the start check, it also
/// writes the list of the probes of the [tests], [startProbesFile], in the
/// order of the [tests], each named after the directory of its tests. So
/// the start check that the matrix analyzes in its apps and the one that CI
/// starts on a device run the probes of the tests that go into the app.
///
/// Throws a [MatrixAppTestException], before it copies anything, if a test
/// generates files without [app], if a file keeps a placeholder that no
/// value fills, if two of the [tests] have a file at the same path, the
/// files they generate included, if a test generates a file at a path that
/// is no relative path in the app, if the mocks of a test are in no file
/// of it in `test/`, if its probe is in no file of it in
/// `integration_test/`, or if a test has a file at the path of the
/// configuration of the mocks or of the list of the probes, which the
/// matrix writes.
List<String> addAppTests(
  List<MatrixAppTest> tests, {
  required String directory,
  required String packageName,
  MatrixApp? app,
  FileSystem fileSystem = const LocalFileSystem(),
}) {
  final context = fileSystem.path;
  final (:texts, :owners) = _filesOfTests(
    tests,
    packageName: packageName,
    app: app,
    fileSystem: fileSystem,
  );
  final mocks = _mocksOf(tests, owners, fileSystem);
  if (mocks.isNotEmpty) {
    final config = context.joinAll(_testConfig.split('/'));
    if (owners[config] case final other?) {
      throw MatrixAppTestException(
        'The tests of $other have $_testConfig, which the matrix writes for '
        'the mocks of the tests.',
      );
    }
    texts[config] = _testConfigOf(mocks);
  }
  final probes = _probesOf(tests, owners, fileSystem);
  if (tests.any((test) => test.readsStartProbes)) {
    final list = context.joinAll(startProbesFile.split('/'));
    if (owners[list] case final other?) {
      throw MatrixAppTestException(
        'The tests of $other have $startProbesFile, which the matrix writes '
        'for the probes of the tests.',
      );
    }
    texts[list] = _startProbesOf(probes);
  }
  for (final MapEntry(key: path, value: text) in texts.entries) {
    fileSystem.file(context.join(directory, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  return [...texts.keys];
}

/// The files that [tests] put into the app [app] with the package
/// [packageName], see [addAppTests]: the `texts` of the files of their
/// directories, with their values filled, and of the files that they
/// generate, by the path of each in the app, and the `owners` of the files,
/// the directory of the test of each.
({Map<String, String> texts, Map<String, String> owners}) _filesOfTests(
  List<MatrixAppTest> tests, {
  required String packageName,
  required MatrixApp? app,
  required FileSystem fileSystem,
}) {
  final texts = <String, String>{};
  final owners = <String, String>{};
  for (final test in tests) {
    final files = _generatedFilesOf(test, app, packageName);
    final values = {
      'app_name': packageName,
      if (app != null) ...?test.values?.call(app),
    };
    for (final (path, file) in _filesOf(test.directory, fileSystem)) {
      if (owners[path] case final other?) {
        throw MatrixAppTestException(
          'The tests of $other and ${test.directory} both have $path.',
        );
      }
      owners[path] = test.directory;
      texts[path] = _filled(file.readAsStringSync(), values, test, path);
    }
    for (final MapEntry(key: generated, value: text) in files.entries) {
      final path = _generatedPath(generated, test, fileSystem);
      if (owners[path] case final other?) {
        throw MatrixAppTestException(
          'The tests of ${test.directory} generate $generated, which the '
          'tests of $other have too.',
        );
      }
      owners[path] = test.directory;
      texts[path] = text;
    }
  }
  return (texts: texts, owners: owners);
}

/// The files that [test] generates for [app] with the package
/// [packageName], by the path of each in the app; a test that generates
/// files needs the app.
Map<String, String> _generatedFilesOf(
  MatrixAppTest test,
  MatrixApp? app,
  String packageName,
) =>
    switch ((test.generatedFiles, app)) {
      (null, _) => const <String, String>{},
      (final generate?, final app?) => generate(app, packageName),
      (_, null) => throw MatrixAppTestException(
          'The tests of ${test.directory} generate files for an app of the '
          'matrix, but the app is none.',
        ),
    };

/// The path in [fileSystem] of [generated], the path in the app of a file
/// that [test] generates, which has to be one.
String _generatedPath(
  String generated,
  MatrixAppTest test,
  FileSystem fileSystem,
) {
  if (!_isPathInApp(generated)) {
    throw MatrixAppTestException(
      'The tests of ${test.directory} generate a file at "$generated", '
      'which is no path in the app, such as test/services.dart: names '
      r'separated by /, none of them empty, . or .., and none with \ or '
      ':.',
    );
  }
  return fileSystem.path.joinAll(generated.split('/'));
}

/// The mocks that [tests] declare, in their order, each in a file of its
/// test in `test/`, as the [owners] of the files tell.
List<MatrixMocks> _mocksOf(
  List<MatrixAppTest> tests,
  Map<String, String> owners,
  FileSystem fileSystem,
) {
  final context = fileSystem.path;
  final mocks = <MatrixMocks>[];
  for (final test in tests) {
    final declared = test.mocks;
    if (declared == null) continue;
    final path = context.joinAll(declared.path.split('/'));
    if (!declared.path.startsWith('test/') || owners[path] != test.directory) {
      throw MatrixAppTestException(
        'The tests of ${test.directory} declare their mocks in '
        '${declared.path}, which is no file of theirs in test/.',
      );
    }
    mocks.add(declared);
  }
  return mocks;
}

/// The probes that [tests] declare, in their order, each with the name of
/// the directory of its test and in a file of its test in
/// `integration_test/`, as the [owners] of the files tell.
List<(String, MatrixStartProbe)> _probesOf(
  List<MatrixAppTest> tests,
  Map<String, String> owners,
  FileSystem fileSystem,
) {
  final context = fileSystem.path;
  final probes = <(String, MatrixStartProbe)>[];
  for (final test in tests) {
    final probe = test.startProbe;
    if (probe == null) continue;
    final path = context.joinAll(probe.path.split('/'));
    if (!probe.path.startsWith(_integrationTest) ||
        owners[path] != test.directory) {
      throw MatrixAppTestException(
        'The tests of ${test.directory} declare their probe in '
        '${probe.path}, which is no file of theirs in $_integrationTest.',
      );
    }
    probes.add((context.basename(test.directory), probe));
  }
  return probes;
}

/// The directory of an app with the checks that run on a device, such as
/// the start check, as the paths of the files of a [MatrixAppTest] start.
const _integrationTest = 'integration_test/';

/// The list of the probes of the tests of an app, [startProbesFile], with
/// [probes], each with the name of its tests; see [addAppTests].
String _startProbesOf(List<(String, MatrixStartProbe)> probes) {
  final imports = StringBuffer();
  final entries = StringBuffer();
  for (final (index, (name, probe)) in probes.indexed) {
    final uri = probe.path.substring(_integrationTest.length);
    imports.writeln("import '$uri' as probe$index;");
    entries.writeln(
      '  (${SmfNames.dartString(name)}, probe$index.${probe.function}),',
    );
  }
  return '''
// The probes of the tests of the app, which the matrix of SMF writes for
// the check that runs them on a device, such as the start check
// (MatrixAppTest.startProbe): each goes through the running app and
// returns what is wrong.
$imports
/// The probes of the tests of the app, each with the name of its tests: a
/// function that goes through the running app, with the function that
/// waits until the screen settles, and returns the problems that it finds.
const List<(String, Future<List<String>> Function(Future<void> Function()))>
    startProbes = [
$entries];
''';
}

/// The files in the directory [directory] and in its directories, each
/// with its path from [directory], sorted by it, but the hidden ones: those
/// whose path from [directory] has a name that starts with `.`.
List<(String, File)> _filesOf(String directory, FileSystem fileSystem) {
  final context = fileSystem.path;
  final root = fileSystem.directory(directory);
  return [
    for (final entity in root.listSync(recursive: true))
      if (entity is File)
        if (context.relative(entity.path, from: root.path) case final path
            when !context.split(path).any((part) => part.startsWith('.')))
          (path, entity),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
}

/// Whether [path], the path of a file that a [MatrixAppTest] generates, is a
/// path in the app, relative to its root: names separated by `/`, none of
/// them empty, `.` or `..`, which would lead out of the app, and none with
/// `\` or `:`, which would make it another path on Windows.
bool _isPathInApp(String path) => path.split('/').every(
      (name) =>
          name.isNotEmpty &&
          name != '.' &&
          name != '..' &&
          !name.contains(RegExp(r'[\\:]')),
    );

/// The path in an app of the configuration of its tests, which
/// [addAppTests] writes for the [MatrixAppTest.mocks] of the tests.
const _testConfig = 'test/flutter_test_config.dart';

/// The configuration of the tests of an app that sets up [mocks] before
/// the tests of each test file; see [addAppTests].
String _testConfigOf(List<MatrixMocks> mocks) {
  final text = StringBuffer()
    ..writeln('// The configuration of the tests of the app, which the matrix')
    ..writeln('// of SMF writes for the mocks that the tests of its modules')
    ..writeln('// declare (MatrixAppTest.mocks): flutter test runs each test')
    ..writeln('// file in test/ with it, and it sets up the mocks of every')
    ..writeln('// module of the app before the tests of the file.')
    ..writeln("import 'dart:async';")
    ..writeln()
    ..writeln("import 'package:flutter_test/flutter_test.dart';")
    ..writeln();
  for (final (index, mock) in mocks.indexed) {
    text.writeln(
      "import '${mock.path.substring('test/'.length)}' as mocks$index;",
    );
  }
  text
    ..writeln()
    ..writeln(
      'Future<void> testExecutable(FutureOr<void> Function() testMain) '
      'async {',
    )
    ..writeln('  setUpAll(() {')
    ..writeln('    TestWidgetsFlutterBinding.ensureInitialized();');
  for (final (index, mock) in mocks.indexed) {
    text.writeln('    mocks$index.${mock.function}();');
  }
  text
    ..writeln('  });')
    ..writeln('  await testMain();')
    ..writeln('}');
  return '$text';
}

/// [text], the file at [path] of [test], with the placeholders of [values]
/// filled; throws a [MatrixAppTestException] if it keeps another.
String _filled(
  String text,
  Map<String, String> values,
  MatrixAppTest test,
  String path,
) {
  var filled = text;
  for (final MapEntry(:key, :value) in values.entries) {
    filled = filled.replaceAll('{{$key}}', value);
  }
  if (_placeholder.firstMatch(filled) case final match?) {
    throw MatrixAppTestException(
      'The tests of ${test.directory} keep ${match[0]} in $path: no value '
      'fills it.',
    );
  }
  return filled;
}

/// A problem of the files of [MatrixAppTest]s, which [addAppTests] finds
/// before it copies them into an app.
final class MatrixAppTestException implements Exception {
  /// Creates the exception with [message].
  const MatrixAppTestException(this.message);

  /// What is wrong with the files.
  final String message;

  @override
  String toString() => message;
}

/// A placeholder of the files of a [MatrixAppTest], such as `{{app_name}}`.
final _placeholder = RegExp(r'\{\{\s*[A-Za-z_]\w*\s*\}\}');

/// The `flutter` commands that run [tests] in an app once their files are
/// in it: `flutter pub add` of their dev dependencies, if they have any;
/// `flutter analyze`, since the tests follow the rules of the analysis of
/// the app too; and `flutter test`, which runs every test of the app.
List<List<String>> appTestCommands(List<MatrixAppTest> tests) => [
      ..._pubAdd(tests),
      const ['analyze'],
      const ['test'],
    ];

/// `flutter pub add` of the dev dependencies of [tests], if they have any.
List<List<String>> _pubAdd(List<MatrixAppTest> tests) {
  final devDependencies = {for (final test in tests) ...test.devDependencies};
  return [
    if (devDependencies.isNotEmpty)
      ['pub', 'add', for (final package in devDependencies) 'dev:$package'],
  ];
}

/// Runs `flutter` with [arguments] in [directory] and returns the exit code
/// and the output.
typedef MatrixFlutter = Future<(int, String)> Function(
  List<String> arguments,
  String directory,
);

/// Adds [tests] to [generated], the app of the matrix [app], with
/// [addAppTests], and runs the [appTestCommands] with [flutter] until one
/// fails; returns its exit code and the output up to it, which says which
/// command failed, or 0 and the output of all. A problem of the files of
/// the tests is a failure too, with the exit code 1.
Future<(int, String)> runAppTests(
  GeneratedApp generated,
  MatrixApp app,
  List<MatrixAppTest> tests, {
  MatrixFlutter flutter = _flutter,
  FileSystem fileSystem = const LocalFileSystem(),
}) =>
    _addAndRun(
      generated,
      app,
      tests,
      appTestCommands(tests),
      flutter: flutter,
      fileSystem: fileSystem,
    );

/// The tests of [all] to add to [app], an app of the matrix that
/// `smf create` generated outside it, such as one that CI starts on a
/// device, for the tests [named]: those, and, if one of them runs the
/// probes of the tests of the app ([MatrixAppTest.readsStartProbes]), such
/// as the start check, each other test of [all] with a probe
/// ([MatrixAppTest.startProbe]) that applies to [app], in the order of
/// [all]. So the start check goes through the roles of the app, whichever
/// they are, without the caller naming the tests of the roles.
///
/// Throws a [MatrixAppTestException] if a test of [named] does not apply to
/// [app]: its files would not fit the app.
List<MatrixAppTest> appTestsFor(
  MatrixApp app,
  List<MatrixAppTest> named,
  List<MatrixAppTest> all,
) {
  for (final test in named) {
    if (!test.appliesTo(app)) {
      throw MatrixAppTestException(
        'The tests of ${test.directory} do not apply to ${app.name}.',
      );
    }
  }
  return [
    ...named,
    if (named.any((test) => test.readsStartProbes))
      for (final test in all)
        if (test.startProbe != null &&
            !named.contains(test) &&
            test.appliesTo(app))
          test,
  ];
}

/// Adds [tests] to [generated], an app that `smf create` generated outside
/// the matrix, such as one that CI starts on a device: copies their files
/// with [addAppTests], which fills only `{{app_name}}` in them, and adds
/// their dev dependencies with `flutter pub add` through [flutter], if they
/// have any. It runs neither the analysis nor the tests, which the caller
/// runs where it needs them.
///
/// With [app], the app of the matrix that [generated] was generated as,
/// such as an app with every module of the plan of CI that the matrix tool
/// of the CLI generates with `--create --app`, it fills the values of the
/// tests too, and writes the files that they generate for [app] (see
/// [MatrixAppTest.generatedFiles]), as for an app of the matrix.
///
/// Returns 0 and the output, or the exit code of `flutter pub add` and the
/// output if it fails. A problem of the files of the tests is a failure
/// too, with the exit code 1, such as a placeholder that only an app of the
/// matrix fills, or files that tests generate, without [app].
Future<(int, String)> addAppTestsTo(
  GeneratedApp generated,
  List<MatrixAppTest> tests, {
  MatrixApp? app,
  MatrixFlutter flutter = _flutter,
  FileSystem fileSystem = const LocalFileSystem(),
}) =>
    _addAndRun(
      generated,
      app,
      tests,
      _pubAdd(tests),
      flutter: flutter,
      fileSystem: fileSystem,
    );

/// Adds [tests] to [generated], for the app of the matrix [app] if it is
/// one, and runs [commands] with [flutter] until one fails; returns its
/// exit code and the output up to it, or 0 and the output of all.
Future<(int, String)> _addAndRun(
  GeneratedApp generated,
  MatrixApp? app,
  List<MatrixAppTest> tests,
  List<List<String>> commands, {
  required MatrixFlutter flutter,
  required FileSystem fileSystem,
}) async {
  final List<String> added;
  try {
    added = addAppTests(
      tests,
      app: app,
      directory: generated.path,
      packageName: generated.name,
      fileSystem: fileSystem,
    );
  } on MatrixAppTestException catch (error) {
    return (1, error.message);
  }
  final output = StringBuffer('Added the tests ${added.join(', ')}.\n');
  for (final arguments in commands) {
    final (code, text) = await flutter(arguments, generated.path);
    output.write(text);
    if (code != 0) {
      output.write('\nflutter ${arguments.join(' ')} exited with $code.');
      return (code, '$output');
    }
  }
  return (0, '$output');
}

/// Generates the app of `smf create` with [arguments] and gives it to
/// [onCreated]; returns the exit code.
typedef MatrixCreate = Future<int> Function(
  List<String> arguments,
  void Function(GeneratedApp app) onCreated,
);

/// Analyzes the app in [directory] and returns the exit code and output of
/// the analyzer.
typedef MatrixAnalyze = Future<(int, String)> Function(String directory);

/// Adds [tests] to [generated], the app of the matrix [app], and runs them
/// with `flutter test`; returns the exit code of the first command that
/// fails and the output up to it, or 0 and the output of all.
typedef MatrixTest = Future<(int, String)> Function(
  GeneratedApp generated,
  MatrixApp app,
  List<MatrixAppTest> tests,
);

/// The commands that [runMatrix] and [createEveryModuleApps] run for each
/// app, and where they write what happens, which tests of the matrix may
/// replace; each left `null` is the real one.
final class MatrixCommands {
  /// Creates the commands, with the real one for each left `null`.
  const MatrixCommands({this.log, this.create, this.analyze, this.test});

  /// Gets what happens, line by line: by default the standard output.
  final void Function(String line)? log;

  /// Generates an app: by default `smf create` of this CLI with the modules
  /// of the matrix.
  final MatrixCreate? create;

  /// Analyzes an app: by default `flutter analyze`.
  final MatrixAnalyze? analyze;

  /// Adds the tests that apply to an app and runs them: by default
  /// [runAppTests].
  final MatrixTest? test;
}

/// Generates every app of the [matrixOf] of [modules] with [roleOptions] in
/// [directory], with the options of CI, analyzes each with
/// `flutter analyze`, and, in an app that some of the tests of [appTests]
/// apply to, adds them and runs every test of the app with `flutter test`.
/// Returns the exit code: 0 if every app was generated with every module
/// and every step that the options of CI do not leave for later, has no
/// issue and passes its tests, each of the tests applies to some app, and
/// they check the contract of their roles with every provider (see
/// [MatrixAppTests.roleProblems]); 1 otherwise.
///
/// It checks the apps of [selection], every app of the matrix by default,
/// such as those with some names, only the apps with every module, or a
/// share of them (see [MatrixSelection]), and runs the [appTests] that
/// apply to them. A problem of the selection, such as a name that no app of
/// the matrix has, is a problem of the run too. The apps keep their numbers
/// in the matrix when only some are checked.
///
/// The apps stay in [directory], with the tests. [commands] run for each
/// app, and their log gets what happens.
Future<int> runMatrix(
  List<SmfModule> modules, {
  required String directory,
  Map<String, String?> roleOptions = const {},
  MatrixAppTests appTests = const MatrixAppTests([]),
  MatrixSelection selection = const MatrixSelection(),
  MatrixCommands commands = const MatrixCommands(),
}) async {
  final run = _MatrixRun(
    directory: directory,
    appTests: appTests.tests,
    // coverage:ignore-start
    // The defaults print to the terminal, create the apps with smf and
    // analyze them with Flutter, as the runs of the matrix in CI do; the
    // tests give their own.
    say: commands.log ?? _print,
    create: commands.create ?? _smfCreate(modules),
    analyze:
        commands.analyze ?? (directory) => _flutter(['analyze'], directory),
    // coverage:ignore-end
    test: commands.test ?? runAppTests,
  );
  final (:apps, :failed) = await matrixOf(
    modules,
    roleOptions: roleOptions,
    everyModuleApps: selection.everyModuleApps,
  );
  final problems = [
    for (final result in failed)
      '${result.contractCase}: ${result.errors.join('; ')}',
    ...selection.problemsOf(apps),
  ];
  final checked = <MatrixApp>[];
  for (final (index, app) in selection.of(apps)) {
    checked.add(app);
    // An app keeps its number in the matrix when only some are checked.
    problems.addAll(await run.check(app, 'app_${index + 1}'));
  }
  // Tests that apply to no app would leave CI without saying so. Those of
  // the apps that are not checked run where the whole matrix is.
  for (final test in appTests.tests) {
    if (!apps.any(test.appliesTo)) {
      problems.add('The tests of ${test.directory} apply to no app.');
    }
  }
  problems.addAll(appTests.roleProblems(modules, apps));
  run.say('\n${checked.length} apps generated in $directory.');
  return _exitCode(problems, run.say);
}

/// Generates in [directory] the apps with every module of [modules] with
/// [roleOptions], for CI to build them for Android and iOS and to start
/// them on devices: each as the [MatrixApp.packageName] of [name], such as
/// `start_app` and `start_app_riverpod`, with the options of CI and then
/// [options], such as `--org com.example`. It analyzes and tests none of
/// them, which [runMatrix] does.
///
/// With `--explain` among the [options], `smf create` only prints for each
/// app what it would generate and whether the machine is ready.
///
/// The apps are those of [apps], each app with every module by default,
/// such as a pairwise covering of them, one by the name that the plan of CI
/// gives a job, whose absence is a problem, or those without the modules
/// whose steps need an external service (see [EveryModuleApps]).
///
/// Returns the exit code: 0 if every app was generated with every module
/// and every step that the options of CI do not leave for later, 1
/// otherwise, and 64, without generating an app, when [name] starts with
/// `-`, which `smf create` would take for an option. The log of [commands]
/// gets what happens, and their create generates each app; they analyze
/// and test nothing here.
Future<int> createEveryModuleApps(
  List<SmfModule> modules, {
  required String directory,
  required String name,
  List<String> options = const [],
  Map<String, String?> roleOptions = const {},
  EveryModuleApps apps = const EveryModuleApps(),
  MatrixCommands commands = const MatrixCommands(),
}) async {
  // coverage:ignore-start
  // The defaults print to the terminal and create the apps with smf, as CI
  // does; the tests give their own.
  final say = commands.log ?? _print;
  final generate = commands.create ?? _smfCreate(modules);
  // coverage:ignore-end
  if (name.startsWith('-')) {
    say(
      'The name of the apps, $name, starts with -, so smf create would take '
      'it for an option: give the name right after the directory, and the '
      'options of smf create after it.',
    );
    return 64;
  }
  final (apps: every, :failed) = await everyModuleAppsOf(
    modules,
    roleOptions: roleOptions,
    withoutExternalSteps: apps.withoutExternalSteps,
  );
  final selected = apps.selection.select(every, modules);
  final problems = [
    for (final result in failed)
      '${result.contractCase}: ${result.errors.join('; ')}',
    ...apps.selection.problemsOf(selected),
  ];
  for (final app in selected) {
    final packageName = app.packageName(name);
    say('\n=== $packageName: $app');
    final (_, appProblems) = await _generate(
      generate,
      app,
      packageName,
      directory,
      options,
    );
    problems.addAll(appProblems);
  }
  return _exitCode(problems, say);
}

/// An app whose tests must fail, and how: of the apps with every module of
/// the registry [modules], one for each combination of the providers of the
/// roles that take one, the one with the [providers], such as an app with a
/// provider of a role that has a known bug and the modules that the tests
/// of the role need, whose tests of the role must fail as [failures]
/// expect, and whose other tests must pass; see [runFailingApps].
///
/// Being an app with every module of its registry, it gets the tests that a
/// matrix runs only in such apps too ([MatrixApp.everyModuleWith]).
final class MatrixFailingApp {
  /// Creates the app [name] with every module of [modules] and [providers],
  /// whose tests must fail as [failures] expect.
  const MatrixFailingApp(
    this.name, {
    required this.modules,
    required this.failures,
    this.providers = const [],
  });

  /// The name of the app, such as that of the provider with a bug.
  final String name;

  /// The registry of the app, which `smf create` generates it from: the
  /// modules of the app, and the other providers of its roles that its
  /// modules need in a registry, such as those that a module has variants
  /// for.
  final List<SmfModule> modules;

  /// The providers that the app has of the roles that take one and have
  /// several in [modules], such as the state manager of the variant of a
  /// feature; among other modules, as any module of the app may be named.
  final List<ModuleId> providers;

  /// The tests of the app that must fail, each with the reason of its first
  /// failure.
  final List<MatrixExpectedFailure> failures;

  /// The app of the matrix, the app with every module of [modules] that has
  /// the [providers], as the contract harness builds and renders it, with
  /// the data and roles of its case ([MatrixApp.hook]), under [name]; or
  /// `null` and the problems when not one app with every module has them:
  /// the errors of the cases of the apps that the harness found errors in,
  /// and the number of the apps that have them.
  Future<({MatrixApp? app, List<String> problems})> check() async {
    final (:apps, :failed) = await everyModuleAppsOf(modules);
    final withProviders = [
      for (final app in apps)
        if (providers.every(app.modules.contains)) app,
    ];
    if (withProviders case [final app]) {
      return (
        app: MatrixApp(
          name,
          app.modules,
          roleOptions: app.roleOptions,
          everyModuleWith: app.everyModuleWith,
          hook: app.hook,
        ),
        problems: const <String>[],
      );
    }
    final named = providers.isEmpty ? 'its modules' : providers.join(', ');
    final count = '${withProviders.length} apps with every module of the '
        'registry of $name have $named, rather than one.';
    return (
      app: null,
      problems: [
        for (final result in failed)
          '${result.contractCase}: ${result.errors.join('; ')}',
        count,
      ],
    );
  }
}

/// Adds [tests] to [generated], the app of the matrix [app], with their dev
/// dependencies, and runs them with `flutter test --reporter json` through
/// [flutter] once the app with the tests passes `flutter analyze`: the tests
/// of [failures] must fail as they expect, and the other tests of the app
/// must pass (see [expectedFailureProblems]).
///
/// Returns the problems, and the output with a line for each test that ran
/// (see [testRunSummary]). When a command before the tests fails, or the
/// files of the tests have a problem, the problem is the last line of the
/// output, and no test runs.
Future<(List<String>, String)> runFailingAppTests(
  GeneratedApp generated,
  MatrixApp app,
  List<MatrixAppTest> tests,
  List<MatrixExpectedFailure> failures, {
  MatrixFlutter flutter = _flutter,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final (code, output) = await _addAndRun(
    generated,
    app,
    tests,
    [
      ..._pubAdd(tests),
      const ['analyze'],
    ],
    flutter: flutter,
    fileSystem: fileSystem,
  );
  if (code != 0) return ([output.trim().split('\n').last], output);
  final (_, report) = await flutter(
    const ['test', '--reporter', 'json'],
    generated.path,
  );
  final summary = testRunSummary(report, directory: generated.path);
  return (
    expectedFailureProblems(report, failures, directory: generated.path),
    [output, ...summary].join('\n'),
  );
}

/// Generates each of [apps] in [directory], with the options of CI, adds
/// to it the tests of [appTests] that apply to it, and runs them: its
/// expected failures must fail as they expect, and its other tests must
/// pass; see [runFailingAppTests]. Returns the exit code: 0 if the contract
/// harness builds each app without errors ([MatrixFailingApp.check]),
/// `smf create` generates it with every module and every step that the
/// options of CI do not leave for later, the app with its tests has no
/// issue, and its tests fail as expected; 1 otherwise.
///
/// So the tests of the apps of the matrix show that they can fail: the app
/// of a provider of a role that has a known bug must fail the tests of the
/// role on that bug, and on nothing else.
///
/// The apps stay in [directory], with the tests. The log of [commands] gets
/// what happens, and their create generates each app, by default from the
/// registry of the app; [flutter] runs the commands of the tests on the
/// files of [fileSystem]. The analyze and the test of [commands] do not
/// run.
Future<int> runFailingApps(
  List<MatrixFailingApp> apps, {
  required String directory,
  MatrixAppTests appTests = const MatrixAppTests([]),
  MatrixCommands commands = const MatrixCommands(),
  MatrixFlutter flutter = _flutter,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  // coverage:ignore-start
  // The default prints to the terminal, as the runs in CI do; the tests
  // give their own.
  final say = commands.log ?? _print;
  // coverage:ignore-end
  final problems = <String>[];
  var count = 0;
  for (final (index, failing) in apps.indexed) {
    final (:app, problems: checked) = await failing.check();
    if (app == null) {
      problems.addAll([
        for (final problem in checked) '${failing.name}: $problem',
      ]);
      continue;
    }
    final name = 'app_${index + 1}';
    say('\n=== $name: $app');
    final (generated, appProblems) = await _generate(
      // coverage:ignore-start
      // The default creates the app with smf, as CI does; the tests give
      // their own.
      commands.create ?? _smfCreate(failing.modules),
      // coverage:ignore-end
      app,
      name,
      directory,
    );
    problems.addAll(appProblems);
    if (generated == null) continue;
    count++;
    final (testProblems, output) = await runFailingAppTests(
      generated,
      app,
      [
        for (final test in appTests.tests)
          if (test.appliesTo(app)) test,
      ],
      failing.failures,
      flutter: flutter,
      fileSystem: fileSystem,
    );
    say(output.trim());
    problems.addAll([
      for (final problem in testProblems) '$name ($app): $problem',
    ]);
  }
  say('\n$count apps generated in $directory.');
  return _exitCode(problems, say);
}

/// 0 without [problems]; otherwise 1, once [say] got them.
int _exitCode(List<String> problems, void Function(String line) say) {
  if (problems.isEmpty) return 0;
  say('Problems:');
  problems.forEach(say);
  return 1;
}

/// Generates [app] as [name] in [directory] with [create], with the
/// options of CI and then [options]. Returns the app and the problems
/// found, or `null` and the problem when the app cannot be checked:
/// `smf create` failed or left out a module. With `--explain` among the
/// [options], `smf create` generates nothing, so a run that succeeds
/// returns `null` and no problem.
Future<(GeneratedApp?, List<String>)> _generate(
  MatrixCreate create,
  MatrixApp app,
  String name,
  String directory, [
  List<String> options = const [],
]) async {
  GeneratedApp? created;
  final code = await create(
    [...app.createArguments(name, directory), ...options],
    (generated) => created = generated,
  );
  final generated = created;
  if (code == SmfExitCodes.success && options.contains('--explain')) {
    return (null, const <String>[]);
  }
  if (code != SmfExitCodes.success || generated == null) {
    return (null, ['$name ($app): smf create exited with $code.']);
  }
  if (generated.leftOut.isNotEmpty) {
    final leftOut = generated.leftOut.map((leftOut) => leftOut.module);
    return (
      null,
      ['$name ($app): smf create left out ${leftOut.join(', ')}.'],
    );
  }
  return (
    generated,
    [
      for (final step in generated.skippedSteps)
        if (step.failed) '$name ($app): the step $step.',
    ],
  );
}

/// A run of [runMatrix], which checks one app after another.
final class _MatrixRun {
  _MatrixRun({
    required this.directory,
    required this.appTests,
    required this.say,
    required this.create,
    required this.analyze,
    required this.test,
  });

  final String directory;
  final List<MatrixAppTest> appTests;
  final void Function(String line) say;
  final MatrixCreate create;
  final MatrixAnalyze analyze;
  final MatrixTest test;

  /// Generates [app] as [name] in the directory, analyzes it and runs its
  /// tests, and returns the problems found.
  Future<List<String>> check(MatrixApp app, String name) async {
    say('\n=== $name: $app');
    final (generated, problems) = await _generate(
      create,
      app,
      name,
      directory,
    );
    if (generated == null) return problems;
    final (analyzed, output) = await analyze(generated.path);
    say(output.trim());
    if (analyzed != 0) {
      return problems
        ..add('$name ($app): flutter analyze exited with $analyzed.');
    }
    final tests = [
      for (final test in appTests)
        if (test.appliesTo(app)) test,
    ];
    if (tests.isEmpty) return problems;
    final (tested, testOutput) = await test(generated, app, tests);
    say(testOutput.trim());
    if (tested != 0) {
      problems
          .add('$name ($app): its tests failed with the exit code $tested.');
    }
    return problems;
  }
}

/// The command that the matrix runs for `flutter` with [arguments] in
/// [directory]: `flutter` with them, but for `flutter analyze` in a
/// directory whose path has letters beyond ASCII, where `flutter analyze`
/// of Flutter 3.44 and 3.47 fails on every system
/// (https://github.com/flutter/flutter/pull/191377). There it is
/// `dart analyze --fatal-infos`, which reports the same issues.
List<String> matrixCommand(List<String> arguments, String directory) =>
    arguments.length == 1 &&
            arguments.single == 'analyze' &&
            directory.runes.any((rune) => rune > 0x7F)
        ? const ['dart', 'analyze', '--fatal-infos']
        : ['flutter', ...arguments];

// Tests have no Flutter SDK, and they give their own log.
// coverage:ignore-start
void _print(String line) => stdout.writeln(line);

/// Generates an app with `smf create` of this CLI with [modules].
MatrixCreate _smfCreate(List<SmfModule> modules) =>
    (arguments, onCreated) => runCli(
          arguments,
          modules: modules,
          banner: false,
          onCreated: onCreated,
        );

Future<(int, String)> _flutter(List<String> arguments, String directory) async {
  final [executable, ...rest] = matrixCommand(arguments, directory);
  final result = await Process.run(
    executable,
    rest,
    workingDirectory: directory,
    runInShell: Platform.isWindows,
    // Flutter writes UTF-8, on Windows too; cmd.exe, which runs it there,
    // may write a message of its own in another encoding.
    stdoutEncoding: const Utf8Codec(allowMalformed: true),
    stderrEncoding: const Utf8Codec(allowMalformed: true),
  );
  final instead = executable == 'flutter'
      ? ''
      : '${[executable, ...rest].join(' ')} in place of flutter '
          '${arguments.join(' ')}, which fails in this directory:\n';
  return (result.exitCode, '$instead${result.stdout}${result.stderr}');
}
// coverage:ignore-end
