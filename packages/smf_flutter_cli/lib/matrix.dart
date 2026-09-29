/// The matrix of apps that the continuous integration of SMF generates
/// with `smf create` and analyzes with Flutter: every app that the contract
/// harness builds for a set of modules, and the apps with every module,
/// which CI also builds for Android and iOS and starts on devices; and the
/// versions of Flutter that its nightly run checks them with.
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
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

export 'src/flutter_versions.dart';

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
  /// other than the first registered provider of each, in the order of the
  /// roles, such as `[riverpod]` for the app with riverpod rather than
  /// bloc, and none for the app with the first provider of every role.
  /// `null` for any other app of the matrix.
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
/// module.
Future<({List<MatrixApp> apps, List<ContractResult> failed})> matrixOf(
  List<SmfModule> modules, {
  Map<String, String?> roleOptions = const {},
}) async {
  final harness = ContractHarness(
    ModuleRegistry(modules),
    roleOptions: roleOptions,
  );
  final apps = <MatrixApp>[];
  final failed = <ContractResult>[];
  for (final result in await harness.checkAll()) {
    switch (_appOf(result, roleOptions, harness.context)) {
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
  for (final app in everyModule.apps) {
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
      harness.context,
      everyModuleWith: _everyModuleWith(contractCase, names),
    );
    if (app == null) {
      failed.add(result);
      continue;
    }
    apps.add(app);
    if (withoutExternalSteps) {
      external.addAll(_withExternalSteps(result.collection!));
    }
  }
  return (apps: apps, failed: failed, external: external);
}

/// The providers that [contractCase], a case of an app with every module,
/// picks other than the first provider of their role in [names]; see
/// [MatrixApp.everyModuleWith].
List<ModuleId> _everyModuleWith(
  ContractCase contractCase,
  ModuleRegistry names,
) =>
    [
      ...{
        for (final MapEntry(key: role, value: provider)
            in contractCase.picks.entries)
          if (provider != names.providersOf(role).first.descriptor.id) provider,
      },
    ];

/// The app of the matrix that [result] built with the values of role
/// options [roleOptions], or `null` if the case has errors.
MatrixApp? _appOf(
  ContractResult result,
  Map<String, String?> roleOptions,
  ModuleContext context, {
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
    // In a case without errors, all data of the roles is of the type they
    // take and comes from modules that may give it, so it is the data that
    // the hooks of the roles got when the harness rendered the app.
    hook: RoleHookRequest(
      data: result.collection!.roleData,
      presentRoles: resolution.presentRoles,
      context: context,
      choices: result.choices!,
    ),
  );
}

/// The modules of [app], which tell it apart from the other apps of the
/// matrix: the variants of the modules follow from them.
String _keyOf(MatrixApp app) =>
    ([for (final module in app.modules) module.value]..sort()).join(',');

/// The modules whose steps after generation in the app of [collection]
/// need an external service, or have a follow-up that does.
Set<ModuleId> _withExternalSteps(Collection collection) => {
      for (final collected in collection.applying)
        if (collected
            case Collected(
              contribution: final PostGenStep step,
              origin: ModuleOrigin(:final module),
            ) when _isExternal(step))
          module,
    };

bool _isExternal(PostGenStep step) =>
    step.external || step.followUps.any(_isExternal);

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
///   to once those modules are taken out of their modules, with the same
///   name, role options and hook;
/// - `roleFunctionUses`, the uses, in its Dart files, of the functions of
///   the roles of [modules], the modules of the matrix, that an app can
///   have several providers of, each as the path of the file from the
///   directory and the function, such as `test/a_test.dart:
///   createCrashReporter() of lib/core/crash_reporting/crash_reporter.dart`.
///
/// The app tests that a package of modules keeps test its modules, so they
/// apply only to the apps that have one of them, whichever other modules
/// the matrix has: a check of the start of every app that the provider of
/// the app entry kept would reach no app with another provider. [apps]
/// gives the apps of the matrix, which it builds only when a test has
/// modules.
///
/// An app test runs in every app with its module, whatever else the app
/// has, so it uses no function of a role that reaches every provider of
/// the role, such as `createCrashReporter()`, whose reporter reports to all
/// of them: what another provider does, only the tests of its own module
/// know. Such functions are the public top-level functions of the files of
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
  final appTests = await _appTestsOf({...packages.values}, fileSystem);
  final functions = await _roleFunctionsOf(modules);
  List<MatrixApp>? all;
  final report = <Map<String, Object>>[];
  for (final test in tests) {
    final ids = {
      for (final MapEntry(key: id, value: package) in packages.entries)
        if (fileSystem.path.isWithin(appTests[package]!, test.directory)) id,
    };
    report.add({
      'directory': test.directory,
      'modules': [for (final id in ids) id.value],
      'appliesWithout': ids.isEmpty
          ? const <String>[]
          : _appliesWithout(test, ids, all ??= await apps()),
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
/// file in the app, in the Dart files of the tests in [directory], each as
/// the path of the file from [directory] and the use; none if [directory]
/// does not exist, which the checks of the repository find otherwise.
List<String> _roleFunctionUses(
  String directory,
  Map<String, Set<String>> functions,
  FileSystem fileSystem,
) {
  if (!fileSystem.directory(directory).existsSync()) return const [];
  final context = fileSystem.path;
  return [
    for (final (relative, file) in _filesOf(directory, fileSystem))
      if (context.split(relative).join('/') case final path
          when path.endsWith('.dart'))
        for (final use in _roleFunctionUsesIn(
          DartFileIndexer.index(path, file.readAsStringSync()),
          functions,
        ))
          '$path: $use',
  ];
}

/// The functions of the roles of [modules] that an app can have several
/// providers of, by the path in the app of the file of the role that
/// declares them, such as `lib/core/crash_reporting/crash_reporter.dart`:
/// the public top-level functions of the files of the interface of each
/// such role, in the app of each of its providers that the contract harness
/// renders first; see [appTestsReport].
Future<Map<String, Set<String>>> _roleFunctionsOf(
  List<SmfModule> modules,
) async {
  final harness = ContractHarness(ModuleRegistry(modules));
  final functions = <String, Set<String>>{};
  for (final module in modules) {
    final roles = [
      for (final role in module.descriptor.provides)
        if (role.cardinality.allowsMany) role,
    ];
    if (roles.isEmpty) continue;
    final id = module.descriptor.id;
    final result = await harness.check(harness.casesOfModule(id).first);
    final app = result.app;
    if (app == null) {
      throw StateError(
        'The contract harness renders no app of $id, which provides the '
        '${roles.join(', the ')}: ${result.errors.join('; ')}',
      );
    }
    for (final role in roles) {
      for (final path in role.interface.files) {
        final file = app.files[path];
        if (file == null) {
          throw StateError(
            'The app of $id that the contract harness renders has no $path '
            'of the $role.',
          );
        }
        (functions[path] ??= {}).addAll([
          for (final declaration
              in DartFileIndexer.index(path, file.text).declarations)
            if (declaration.kind == DeclarationKind.function &&
                !declaration.name.startsWith('_'))
              declaration.name,
        ]);
      }
    }
  }
  return functions;
}

/// The uses in [file], a Dart file of app tests, of the [functions] of
/// roles by the path of their file in the app: calls and tear-offs through
/// an import of that file as `package:{{app_name}}/...`, with a prefix or
/// without, each as `<function>() of <path>`.
List<String> _roleFunctionUsesIn(
  DartFileIndex file,
  Map<String, Set<String>> functions,
) {
  final uses = <String>[];
  for (final MapEntry(key: path, value: names) in functions.entries) {
    final uri = 'package:{{app_name}}/${path.substring('lib/'.length)}';
    final imports = [
      for (final import in file.imports)
        if (import.uri == uri) import,
    ];
    if (imports.isEmpty) continue;
    final unprefixed = imports.any((import) => import.prefix == null);
    final prefixes = {
      for (final import in imports)
        if (import.prefix case final prefix?) prefix,
    };
    bool through(String? target) =>
        target == null ? unprefixed : prefixes.contains(target);
    final used = {
      for (final call in file.invocations)
        if (names.contains(call.name) && through(call.target)) call.name,
      if (unprefixed)
        for (final reference in file.references)
          if (names.contains(reference.name)) reference.name,
      for (final access in file.memberAccesses)
        if (names.contains(access.name) && prefixes.contains(access.target))
          access.name,
    };
    uses.addAll([for (final name in used) '$name() of $path']);
  }
  return uses;
}

/// The directory `app_tests` of each of [packages], which are in the
/// configuration of the packages that loaded their modules.
Future<Map<String, String>> _appTestsOf(
  Set<String> packages,
  FileSystem fileSystem,
) async {
  final path = fileSystem.path;
  return {
    for (final package in packages)
      package: path.join(
        path.dirname(
          path.fromUri(
            await Isolate.resolvePackageUri(Uri.parse('package:$package/')),
          ),
        ),
        'app_tests',
      ),
  };
}

/// The names of [apps] that [test] applies to once the modules [ids] are
/// taken out of their modules, with the same name, role options and hook.
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
            hook: app.hook,
          ),
        ))
          app.name,
    ];

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
    this.roles = const {},
    this.mocks,
  });

  /// The directory of the files that go into an app, each at its path
  /// relative to the directory, such as `test/firebase_core_test.dart`,
  /// over the file of the app at that path, if the app has one.
  ///
  /// In the text of each file, `{{app_name}}` becomes the name of the
  /// package of the app, and `{{<key>}}` the value of each key of the
  /// [values] of the app. Hidden files stay out. The files of the tests of
  /// an app may use those of other tests that the app always has too, such
  /// as the tests of a module that another depends on.
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

  /// The roles whose contract the tests check, whichever module provides
  /// each, such as the router role, whose provider calls the listeners of
  /// the screen once for each screen the user sees.
  ///
  /// Such tests apply to the apps of every provider of each of the roles,
  /// which [appliesTo] selects by the role rather than by the modules that
  /// provide it; [runMatrix] fails when they apply to no app of one of
  /// them (see [MatrixAppTests]). Tests of what only one provider does name
  /// no role.
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
  final MatrixMocks? mocks;
}

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
  /// that applies to none of the apps of the module, and no test of a role
  /// of [testedRoles] at all.
  ///
  /// A provider of the role that the tests leave out, such as one that a
  /// module adds later, is a problem, since its apps would be generated and
  /// analyzed, but nothing would check at runtime that it keeps the
  /// contract of the role.
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
    return [
      for (final test in ofRole)
        if (!withModule.any(test.appliesTo)) _leftOut(test, role, id),
    ];
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
}

/// Copies the files of [tests] into the app of the matrix [app], generated
/// in [directory] with the package [packageName], with the placeholders
/// of the files filled, and returns the paths of the files in the app; see
/// [MatrixAppTest.directory].
///
/// Without [app], for an app that `smf create` generated outside the
/// matrix, only `{{app_name}}` is filled: the [MatrixAppTest.values] come
/// from an app of the matrix.
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
/// Throws a [MatrixAppTestException], before it copies anything, if a file
/// keeps a placeholder that no value fills, if two of the [tests] have a
/// file at the same path, if the mocks of a test are in no file of it in
/// `test/`, or if a test has a file at the path of the configuration that
/// the matrix writes for the mocks.
List<String> addAppTests(
  List<MatrixAppTest> tests, {
  required String directory,
  required String packageName,
  MatrixApp? app,
  FileSystem fileSystem = const LocalFileSystem(),
}) {
  final context = fileSystem.path;
  final texts = <String, String>{};
  final owners = <String, String>{};
  for (final test in tests) {
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
  }
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
  for (final MapEntry(key: path, value: text) in texts.entries) {
    fileSystem.file(context.join(directory, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  return [...texts.keys];
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

/// Adds [tests] to [generated], an app that `smf create` generated outside
/// the matrix, such as one that CI starts on a device: copies their files
/// with [addAppTests], which fills only `{{app_name}}` in them, and adds
/// their dev dependencies with `flutter pub add` through [flutter], if they
/// have any. It runs neither the analysis nor the tests, which the caller
/// runs where it needs them.
///
/// Returns 0 and the output, or the exit code of `flutter pub add` and the
/// output if it fails. A problem of the files of the tests is a failure
/// too, with the exit code 1, such as a placeholder that only an app of the
/// matrix fills.
Future<(int, String)> addAppTestsTo(
  GeneratedApp generated,
  List<MatrixAppTest> tests, {
  MatrixFlutter flutter = _flutter,
  FileSystem fileSystem = const LocalFileSystem(),
}) =>
    _addAndRun(
      generated,
      null,
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
/// With [only], it checks only the apps of the matrix with those names,
/// such as `flutter_core (flutter_core)`, and runs the [appTests] that
/// apply to them; a name that no app of the matrix has is a problem too.
/// With [everyModule], it checks only the apps with every module, one for
/// each combination of the providers of the roles that take one (see
/// [everyModuleAppsOf]), which CI selects so rather than by their names:
/// the name of such an app names the provider of every role that has
/// several, so it changes when another role gets a second provider.
///
/// The apps stay in [directory], with the tests. [commands] run for each
/// app, and their log gets what happens.
Future<int> runMatrix(
  List<SmfModule> modules, {
  required String directory,
  Map<String, String?> roleOptions = const {},
  MatrixAppTests appTests = const MatrixAppTests([]),
  Set<String>? only,
  bool everyModule = false,
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
  final (:apps, :failed) = await matrixOf(modules, roleOptions: roleOptions);
  final problems = [
    for (final result in failed)
      '${result.contractCase}: ${result.errors.join('; ')}',
    for (final name in only ?? const <String>{})
      if (!apps.any((app) => app.name == name))
        'No app of the matrix is $name.',
  ];
  final checked = <MatrixApp>[];
  for (final (index, app) in apps.indexed) {
    if (only != null && !only.contains(app.name)) continue;
    if (everyModule && app.everyModuleWith == null) continue;
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
/// [roleOptions], or those without the modules whose steps need an
/// external service with [withoutExternalSteps] (see [everyModuleAppsOf]),
/// for CI to build them for Android and iOS and to start them on devices:
/// each as the [MatrixApp.packageName] of [name], such as `start_app` and
/// `start_app_riverpod`, with the options of CI and then [options], such as
/// `--org com.example`. It analyzes and tests none of them, which
/// [runMatrix] does.
///
/// With `--explain` among the [options], `smf create` only prints for each
/// app what it would generate and whether the machine is ready.
///
/// Returns the exit code: 0 if every app was generated with every module
/// and every step that the options of CI do not leave for later, 1
/// otherwise. The log of [commands] gets what happens, and their create
/// generates each app; they analyze and test nothing here.
Future<int> createEveryModuleApps(
  List<SmfModule> modules, {
  required String directory,
  required String name,
  bool withoutExternalSteps = false,
  List<String> options = const [],
  Map<String, String?> roleOptions = const {},
  MatrixCommands commands = const MatrixCommands(),
}) async {
  // coverage:ignore-start
  // The defaults print to the terminal and create the apps with smf, as CI
  // does; the tests give their own.
  final say = commands.log ?? _print;
  final generate = commands.create ?? _smfCreate(modules);
  // coverage:ignore-end
  final (:apps, :failed) = await everyModuleAppsOf(
    modules,
    roleOptions: roleOptions,
    withoutExternalSteps: withoutExternalSteps,
  );
  final problems = [
    for (final result in failed)
      '${result.contractCase}: ${result.errors.join('; ')}',
  ];
  for (final app in apps) {
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
