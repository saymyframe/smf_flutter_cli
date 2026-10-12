import 'dart:convert';
import 'dart:io' show stderr, stdout;
import 'dart:math' show max;

import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Which apps with every module a run of the matrix takes, of those that
/// [everyModuleAppsOf] gives, one for each combination of the providers of
/// the roles that take one: a covering of the combinations
/// ([EveryModuleCombinations]), one app by its name
/// ([NamedEveryModuleApp]), or one app for each provider of a role
/// ([EveryModuleAppPerProvider]).
///
/// The combinations are the product of the numbers of providers of those
/// roles, so CI checks all of them only in memory, where the contract
/// harness renders every one, and generates, builds and starts only a
/// covering of them.
///
/// The apps with every module for the other values of the mode options of
/// the roles ([modeAppsOf]) are no such combination: a selection takes some
/// of them only next to a covering, for the runs that check the matrix (see
/// [selectModes]).
sealed class EveryModuleSelection {
  /// The apps of [apps], apps with every module of [modules] such as those
  /// of [everyModuleAppsOf], that the selection takes, in their order.
  List<MatrixApp> select(List<MatrixApp> apps, List<SmfModule> modules);

  /// The apps of [modes], the apps with every module of [modules] for the
  /// other values of the mode options of their roles ([modeAppsOf]), that
  /// the selection takes next to [selected], the apps that [select] took,
  /// in their order.
  List<MatrixApp> selectModes(
    List<MatrixApp> modes,
    List<MatrixApp> selected,
    List<SmfModule> modules,
  );

  /// The problems of [selected], the apps that [select] took: for a name,
  /// that no app has it.
  List<String> problemsOf(List<MatrixApp> selected);
}

/// A covering of the apps with every module: the apps that have, between
/// them, every tuple of [strength] providers of different roles that one
/// of the apps has, of the roles that take one and have several providers
/// among the apps, and every module that one of the apps has; all of the
/// apps without a [strength].
///
/// It takes only apps that the contract harness built, so it respects the
/// rules by which a module fits in an app: a tuple of providers that no app
/// has, such as a provider with one that its modules do not fit with, needs
/// no app, and a module that fits only one combination, such as one with a
/// variant for one provider that depends on a module with a variant for
/// another, gets the app of that combination. With fewer such roles than
/// [strength], the tuples have them all; with one, each of its providers
/// is in an app.
///
/// The covering is the same for the same apps. It takes, again and again,
/// the app that has the most tuples and modules that no app it took has,
/// breaking a tie either by the order of the apps or by the app whose
/// providers and modules are in the most of those not yet taken, then
/// leaves out each app whose tuples and modules the others have too, and
/// keeps the smaller of the two coverings, the first on a tie.
///
/// The value of a mode option of a role (see [RoleOption.mode]) is one
/// more thing that an app has, as the provider of a role is: the first
/// value in the apps of the covering, and another one in an app of
/// [modeAppsOf]. So a covering takes, next to its apps, a few of those
/// apps in the same way ([selectModes]): those that have, between them,
/// every tuple of [strength] providers of different roles and values of
/// different mode options that one of those apps has and no app of the
/// covering has, which are the tuples with a value other than the first.
/// A pairwise covering then has every value of a mode option with every
/// provider of a role that has several, and with every value of another
/// mode option. Without a [strength], it takes all of those apps.
enum EveryModuleCombinations implements EveryModuleSelection {
  /// Every pair of providers of two different roles in one of the apps: a
  /// few apps, which grow with the square of the number of providers of a
  /// role and hardly with the number of roles, such as at most 15 of the
  /// 243 apps of 5 roles of 3 providers.
  pairwise('pairwise', 2),

  /// Every triple of providers of three different roles in one of the apps,
  /// such as at most 60 of the 243 apps of 5 roles of 3 providers.
  threeWise('3-wise', 3),

  /// Every app: the product of the numbers of providers of the roles.
  all('all', null);

  const EveryModuleCombinations(this.option, this.strength);

  /// The value of the option `--combinations` of the matrix tools that
  /// selects these apps.
  final String option;

  /// The number of providers of different roles, and of values of
  /// different mode options, of each tuple that one of the apps must have,
  /// or `null` for every app.
  final int? strength;

  /// The combinations that the value [option] of `--combinations` selects,
  /// or `null` for a value that selects none.
  static EveryModuleCombinations? parse(String option) {
    for (final combinations in values) {
      if (combinations.option == option) return combinations;
    }
    return null;
  }

  @override
  List<MatrixApp> select(List<MatrixApp> apps, List<SmfModule> modules) {
    final strength = this.strength;
    if (strength == null) return apps;
    return [
      for (final index in _Covering.of(apps, modules, strength).indices)
        apps[index],
    ];
  }

  @override
  List<MatrixApp> selectModes(
    List<MatrixApp> modes,
    List<MatrixApp> selected,
    List<SmfModule> modules,
  ) {
    final strength = this.strength;
    if (strength == null) return modes;
    final apps = [...selected, ...modes];
    final covering = _Covering.of(
      apps,
      modules,
      strength,
      taken: selected.length,
    );
    return [for (final index in covering.indices) apps[index]];
  }

  @override
  List<String> problemsOf(List<MatrixApp> selected) => const [];
}

/// The app with every module whose case of the contract harness is [name],
/// such as `every module (riverpod)`, as a job of CI takes its app of the
/// plan (see [matrixPlanOf]).
///
/// It is one of the apps of [everyModuleAppsOf], whose mode options have
/// their first value: the name of an app of [modeAppsOf] selects no app,
/// and the selection takes none of those apps next to its own.
final class NamedEveryModuleApp implements EveryModuleSelection {
  /// Creates the selection of the app with every module named [name].
  const NamedEveryModuleApp(this.name);

  /// The name of the case of the app, [MatrixApp.name].
  final String name;

  @override
  List<MatrixApp> select(List<MatrixApp> apps, List<SmfModule> modules) => [
        for (final app in apps)
          if (app.name == name) app,
      ];

  @override
  List<MatrixApp> selectModes(
    List<MatrixApp> modes,
    List<MatrixApp> selected,
    List<SmfModule> modules,
  ) =>
      const [];

  @override
  List<String> problemsOf(List<MatrixApp> selected) => [
        if (selected.isEmpty) 'No app with every module is $name.',
      ];
}

/// One app with every module for each provider of [role]: the first of the
/// apps that has it, which has the first providers of the other roles that
/// fit with it.
///
/// So CI configures an app with the external services of its modules and
/// starts it once for each provider of the app entry role, which owns the
/// native projects and their configuration, rather than for each
/// combination of the providers. It takes no app of [modeAppsOf]: those
/// apps differ from its own in their Dart code only.
final class EveryModuleAppPerProvider implements EveryModuleSelection {
  /// Creates the selection of one app for each provider of [role].
  const EveryModuleAppPerProvider(this.role);

  /// The role of whose providers each gets an app.
  final Role role;

  @override
  List<MatrixApp> select(List<MatrixApp> apps, List<SmfModule> modules) {
    bool has(MatrixApp app, SmfModule provider) =>
        app.modules.contains(provider.descriptor.id);
    final first = <int>{
      for (final module in modules)
        if (module.descriptor.provides.contains(role))
          if (apps.indexWhere((app) => has(app, module)) case final index
              when index >= 0)
            index,
    };
    return [
      for (final (index, app) in apps.indexed)
        if (first.contains(index)) app,
    ];
  }

  @override
  List<MatrixApp> selectModes(
    List<MatrixApp> modes,
    List<MatrixApp> selected,
    List<SmfModule> modules,
  ) =>
      const [];

  @override
  List<String> problemsOf(List<MatrixApp> selected) => const [];
}

/// A covering of apps with every module; see [EveryModuleCombinations].
final class _Covering {
  _Covering._(this.items, this.taken);

  /// The covering of [apps], apps with every module of [modules], of
  /// [strength], which has the first [taken] of them already and takes of
  /// the others.
  factory _Covering.of(
    List<MatrixApp> apps,
    List<SmfModule> modules,
    int strength, {
    int taken = 0,
  }) {
    final providersOf = _providersOf(modules);
    final providers = [
      for (final app in apps) _providersIn(app, providersOf),
    ];
    // The roles with several providers among the apps.
    final roles = [
      for (final role in providersOf.keys)
        if ({for (final byRole in providers) byRole[role]}.nonNulls.length > 1)
          role,
    ];
    final modesOf = _modesOf(modules);
    final modes = [for (final app in apps) _modesIn(app, modesOf)];
    // The mode options with several values among the apps.
    final options = [
      for (final option in modesOf.keys)
        if ({for (final byOption in modes) byOption[option]}.nonNulls.length >
            1)
          option,
    ];
    final parts = roles.length + options.length;
    final size = strength < parts ? strength : parts;
    return _Covering._(
      [
        for (final (index, app) in apps.indexed)
          _itemsOf(
            app,
            [
              for (final role in roles)
                if (providers[index][role] case final provider?)
                  '${role.id}=$provider',
              for (final option in options)
                if (modes[index][option] case final value?) '--$option=$value',
            ],
            size,
          ),
      ],
      taken,
    );
  }

  /// The providers of each role that takes one, in the order in which
  /// [modules] provide the roles.
  static Map<Role, Set<ModuleId>> _providersOf(List<SmfModule> modules) {
    final providersOf = <Role, Set<ModuleId>>{};
    for (final module in modules) {
      for (final role in module.descriptor.provides) {
        if (role.cardinality.allowsMany) continue;
        providersOf.putIfAbsent(role, () => {}).add(module.descriptor.id);
      }
    }
    return providersOf;
  }

  /// The provider that [app] has of each role of [providersOf], the
  /// providers of each role.
  static Map<Role, ModuleId> _providersIn(
    MatrixApp app,
    Map<Role, Set<ModuleId>> providersOf,
  ) =>
      {
        for (final MapEntry(key: role, value: ids) in providersOf.entries)
          if (app.modules.where(ids.contains).firstOrNull case final id?)
            role: id,
      };

  /// The mode options of the roles that [modules] provide, by their names,
  /// which no two roles of a registry share, in the order in which the
  /// modules provide the roles: the first value of each, and the modules
  /// that provide its role.
  static Map<String, _Mode> _modesOf(List<SmfModule> modules) {
    final modesOf = <String, _Mode>{};
    for (final module in modules) {
      for (final role in module.descriptor.provides) {
        for (final option in role.options) {
          if (!option.isMode) continue;
          modesOf
              .putIfAbsent(
                option.name,
                () => (first: option.allowed!.first, providers: {}),
              )
              .providers
              .add(module.descriptor.id);
        }
      }
    }
    return modesOf;
  }

  /// The value that [app] has of each mode option of [modesOf], by the name
  /// of the option: the one of its [MatrixApp.modes], or the first value of
  /// the option; none for an option whose role the app lacks.
  static Map<String, String> _modesIn(
    MatrixApp app,
    Map<String, _Mode> modesOf,
  ) =>
      {
        for (final MapEntry(key: name, value: (:first, :providers))
            in modesOf.entries)
          if (app.modules.any(providers.contains))
            name: app.modes[name] ?? first,
      };

  /// What [app] has that a covering must have: the tuples of [size] of its
  /// [parts], its providers of the roles that have several and its values
  /// of the mode options that have several among the apps, and its modules.
  ///
  /// An app with fewer parts than [size] has one tuple, of all of them: an
  /// app lacks the value of an option whose role it lacks, and what it has
  /// with the others sets it apart all the same.
  static Set<String> _itemsOf(MatrixApp app, List<String> parts, int size) => {
        for (final tuple
            in _subsets(parts, size < parts.length ? size : parts.length))
          if (tuple.isNotEmpty) tuple.join('+'),
        for (final module in app.modules) 'module:$module',
      };

  /// What each app has that the covering must have: its tuples of
  /// providers and of values of mode options, such as
  /// `router=go_router+di=get_it` and `di=get_it+--clock-hours=12`, and its
  /// modules, such as `module:home`.
  final List<Set<String>> items;

  /// The number of the first apps that the covering has already: it takes
  /// of the apps after them, for what none of them has.
  final int taken;

  /// The positions of the apps that the covering takes, in their order.
  /// Every app with every module has modules, so every app has items.
  List<int> get indices {
    final byOrder = _prune(_greedy(byParts: false));
    final byParts = _prune(_greedy(byParts: true));
    return byParts.length < byOrder.length ? byParts : byOrder;
  }

  /// The positions of the apps that the greedy covering takes, in the order
  /// it takes them: again and again the app with the most items that no
  /// app it has or took has, on a tie the first, or, [byParts], the one
  /// whose providers and modules are in the most such items, and then the
  /// first. An app that the covering has already has no such item, so it
  /// takes none of them again.
  List<int> _greedy({required bool byParts}) {
    final left = {for (final app in items) ...app};
    items.take(taken).forEach(left.removeAll);
    final added = <int>[];
    while (left.isNotEmpty) {
      final best = _bestOf(left, byParts ? _partsOf(left) : null);
      added.add(best);
      left.removeAll(items[best]);
    }
    return added;
  }

  /// The number of the items of [left] that each of their parts, a provider
  /// or a module, is in.
  static Map<String, int> _partsOf(Set<String> left) {
    final parts = <String, int>{};
    for (final item in left) {
      for (final part in item.split('+')) {
        parts[part] = (parts[part] ?? 0) + 1;
      }
    }
    return parts;
  }

  /// The position of the app with the most items of [left], which is not
  /// empty: on a tie the first, or, with [parts], the number of the items
  /// of [left] that each part is in, the one whose parts are in the most
  /// of them, and then the first.
  int _bestOf(Set<String> left, Map<String, int>? parts) {
    var best = -1;
    var bestNew = 0;
    var bestParts = 0;
    for (final (index, app) in items.indexed) {
      final fresh = app.where(left.contains).length;
      if (fresh == 0 || fresh < bestNew) continue;
      final inParts = parts == null
          ? 0
          : {for (final item in app) ...item.split('+')}
              .map((part) => parts[part] ?? 0)
              .fold(0, (sum, count) => sum + count);
      if (fresh > bestNew || inParts > bestParts) {
        best = index;
        bestNew = fresh;
        bestParts = inParts;
      }
    }
    return best;
  }

  /// [added], the apps that the greedy covering took, without each app
  /// whose items the others and the apps that the covering has already have
  /// too, the last taken first, in the order of the apps.
  List<int> _prune(List<int> added) {
    final counts = <String, int>{};
    for (final app in [
      ...items.take(taken),
      for (final index in added) items[index],
    ]) {
      for (final item in app) {
        counts[item] = (counts[item] ?? 0) + 1;
      }
    }
    final kept = [...added];
    for (final index in added.reversed) {
      if (items[index].every((item) => counts[item]! > 1)) {
        kept.remove(index);
        for (final item in items[index]) {
          counts[item] = counts[item]! - 1;
        }
      }
    }
    return kept..sort();
  }
}

/// A mode option of a role in a covering: its first value, which an app
/// has unless its [MatrixApp.modes] say otherwise, and the modules that
/// provide its role.
typedef _Mode = ({String first, Set<ModuleId> providers});

/// The subsets of [size] of [values], in their order.
List<List<String>> _subsets(List<String> values, int size) {
  final subsets = <List<String>>[];
  void add(int start, List<String> chosen) {
    if (chosen.length == size) {
      subsets.add(chosen);
      return;
    }
    for (var index = start; index < values.length; index++) {
      add(index + 1, [...chosen, values[index]]);
    }
  }

  add(0, const []);
  return subsets;
}

/// One of the [count] shares of the apps of a run of the matrix that jobs
/// of CI check side by side, the one numbered [index], from 1: the apps at
/// the positions whose remainder after division by [count] is `index - 1`,
/// so each app is in exactly one share and the apps of a share keep their
/// order.
final class MatrixShard {
  /// Creates the share [index] of [count].
  const MatrixShard(this.index, this.count);

  /// The shard of [text], `<index>/<count>` such as `2/3`, or `null` if it
  /// is none: an index from 1 to the count.
  static MatrixShard? parse(String text) {
    final match = RegExp(r'^(\d+)/(\d+)$').firstMatch(text);
    final index = int.tryParse(match?[1] ?? '');
    final count = int.tryParse(match?[2] ?? '');
    if (index == null || count == null || index < 1 || index > count) {
      return null;
    }
    return MatrixShard(index, count);
  }

  /// The shards 1 to [count] of [count].
  static List<MatrixShard> allOf(int count) => [
        for (var index = 1; index <= count; index++) MatrixShard(index, count),
      ];

  /// The number of the shard, from 1.
  final int index;

  /// The number of the shards.
  final int count;

  /// The items of [items] that the shard takes, in their order.
  List<T> of<T>(List<T> items) => [
        for (final (position, item) in items.indexed)
          if (position % count == index - 1) item,
      ];

  @override
  String toString() => '$index/$count';
}

/// The apps of a matrix that a run of [runMatrix] checks: every app of the
/// matrix, with each of its apps with every module and each of those for
/// the other values of the mode options of its roles ([modeAppsOf]), unless
/// told otherwise.
final class MatrixSelection {
  /// Creates the selection of the apps named in [only], of only the apps
  /// with every module with [everyModule], those of [everyModuleApps], and
  /// of the share [shard] of them.
  const MatrixSelection({
    this.only,
    this.everyModule = false,
    this.everyModuleApps = EveryModuleCombinations.all,
    this.shard,
  });

  /// The names of the apps of the matrix that the run checks, such as
  /// `go_router with layout`, or `null` for all of them. A name that no app
  /// of the matrix has is a problem.
  final Set<String>? only;

  /// Whether the run checks only the apps with every module, one for each
  /// combination of the providers of the roles that take one (see
  /// [everyModuleAppsOf]), which CI selects so rather than by their names:
  /// the name of such an app names the provider of every role that has
  /// several, so it changes when another role gets a second provider.
  ///
  /// The apps with every module for the other values of the mode options
  /// ([modeAppsOf], those with [MatrixApp.modes]) are not among them: a run
  /// of the whole matrix checks them, once.
  final bool everyModule;

  /// The apps with every module of the matrix, such as a pairwise covering
  /// of them, with the apps for the other values of the mode options that
  /// it takes next to them, or one by the name of the plan of CI (see
  /// [matrixPlanOf]), whose absence is a problem.
  final EveryModuleSelection everyModuleApps;

  /// The share of the apps that the run would check otherwise, so that jobs
  /// of CI check the matrix side by side, or `null` for all of them.
  final MatrixShard? shard;

  /// The apps of [apps], the apps of the matrix, that the run checks, each
  /// with its position in the matrix, from 0, which it keeps when only some
  /// are checked.
  List<(int, MatrixApp)> of(List<MatrixApp> apps) {
    final only = this.only;
    final selected = [
      for (final (index, app) in apps.indexed)
        if ((only == null || only.contains(app.name)) &&
            (!everyModule ||
                (app.everyModuleWith != null && app.modes.isEmpty)))
          (index, app),
    ];
    return shard?.of(selected) ?? selected;
  }

  /// The problems of the selection with [apps], the apps of the matrix: a
  /// name of [only] that none of them has, and those of [everyModuleApps]
  /// with the apps with every module among them.
  List<String> problemsOf(List<MatrixApp> apps) => [
        for (final name in only ?? const <String>{})
          if (!apps.any((app) => app.name == name))
            'No app of the matrix is $name.',
        ...everyModuleApps.problemsOf([
          for (final app in apps)
            if (app.everyModuleWith != null) app,
        ]),
      ];
}

/// The apps with every module that [createEveryModuleApps] generates: those
/// of [selection], each of them by default, among the apps with every
/// module, or, with [withoutExternalSteps], among those without the modules
/// whose steps need an external service (see [everyModuleAppsOf]).
final class EveryModuleApps {
  /// Creates the apps of [selection], with the modules whose steps need an
  /// external service unless [withoutExternalSteps].
  const EveryModuleApps({
    this.selection = EveryModuleCombinations.all,
    this.withoutExternalSteps = false,
  });

  /// The apps to take, such as a pairwise covering of the apps with every
  /// module, or one by the name that the plan of CI gives a job (see
  /// [matrixPlanOf]), whose absence is a problem.
  final EveryModuleSelection selection;

  /// Whether the apps leave out the modules whose steps need an external
  /// service, so that they start as they are generated.
  final bool withoutExternalSteps;
}

/// The options of a matrix tool that choose the apps of its run, which come
/// before its directory: `--combinations <pairwise|3-wise|all>`, the apps
/// with every module that a run checks or generates, a pairwise covering
/// by default; `--app <name>`, only the app with every module of that name,
/// with `--every-module` or `--create`, or the app that `--add-app-tests`
/// adds tests to, which was generated as that app; and
/// `--shard <index>/<count>`, a share of the apps that a run checks.
final class MatrixToolOptions {
  const MatrixToolOptions._(
    this.arguments,
    this.selection,
    this.shard,
    this.problem,
  );

  /// Takes the options out of [arguments], the arguments of a matrix tool;
  /// the others stay, with those after the directory, which may be options
  /// of `smf create`.
  factory MatrixToolOptions.parse(List<String> arguments) {
    final (:rest, :flags, :values, :problems) = _leadingOptionsOf(arguments);
    final combinations = switch (values[_combinationsOption]) {
      final value? => EveryModuleCombinations.parse(value),
      null => EveryModuleCombinations.pairwise,
    };
    if (combinations == null) {
      problems.add(
        '--combinations takes pairwise, 3-wise or all, not '
        '${values[_combinationsOption]}.',
      );
    }
    final shard = switch (values[_shardOption]) {
      final value? => MatrixShard.parse(value),
      null => null,
    };
    if (values[_shardOption] case final value? when shard == null) {
      problems.add(
        '--shard takes <index>/<count>, such as 1/2, with an index from 1 to '
        'the count, not $value.',
      );
    }
    problems.addAll(_misusesOf(flags, values));
    final app = values[_appOption];
    return MatrixToolOptions._(
      rest,
      app != null
          ? NamedEveryModuleApp(app)
          : combinations ?? EveryModuleCombinations.pairwise,
      shard,
      problems.isEmpty ? null : problems.join(' '),
    );
  }

  static const _combinationsOption = '--combinations';
  static const _appOption = '--app';
  static const _shardOption = '--shard';

  /// The options at the start of [arguments], before the directory of the
  /// tool: the `values` of those that take one, by their names, with a
  /// problem for one without its value or given more than once; the others,
  /// its `flags`; and `rest`, the arguments without the options that take a
  /// value.
  static ({
    List<String> rest,
    Set<String> flags,
    Map<String, String> values,
    List<String> problems,
  }) _leadingOptionsOf(List<String> arguments) {
    final rest = <String>[];
    final values = <String, String>{};
    final problems = <String>[];
    var index = 0;
    while (index < arguments.length && arguments[index].startsWith('-')) {
      final option = arguments[index];
      if (!const {_combinationsOption, _appOption, _shardOption}
          .contains(option)) {
        rest.add(option);
        index++;
      } else if (index + 1 == arguments.length) {
        problems.add('$option needs a value.');
        index++;
      } else {
        if (values.containsKey(option)) {
          problems.add('$option is given more than once.');
        }
        values[option] = arguments[index + 1];
        index += 2;
      }
    }
    final flags = {...rest};
    rest.addAll(arguments.skip(index));
    return (rest: rest, flags: flags, values: values, problems: problems);
  }

  /// The problems of the options with [values] that do not go with the
  /// [flags] of the tool or with each other.
  static List<String> _misusesOf(
    Set<String> flags,
    Map<String, String> values,
  ) {
    final problems = <String>[];
    if (values.containsKey(_appOption)) {
      if (!flags.contains('--every-module') &&
          !flags.contains('--create') &&
          !flags.contains('--add-app-tests')) {
        problems.add(
          '--app takes an app with every module, with --every-module, '
          '--create or --add-app-tests.',
        );
      }
      if (values.containsKey(_combinationsOption)) {
        problems.add('--app takes one app, so it goes without --combinations.');
      }
    }
    if (flags.contains('--create') && values.containsKey(_shardOption)) {
      problems.add(
        '--shard takes a share of the apps that a run checks, not of those '
        'that --create generates.',
      );
    }
    return problems;
  }

  /// The arguments of the tool without these options.
  final List<String> arguments;

  /// The apps with every module that the run takes: the one of `--app`, or
  /// those of `--combinations`, a pairwise covering by default.
  final EveryModuleSelection selection;

  /// The share of the apps that the run checks, or `null` for all of them.
  final MatrixShard? shard;

  /// What is wrong with the options, or `null`.
  final String? problem;
}

/// The number of apps that a job of CI checks at most in a shard of a
/// matrix: about 20 minutes, as generating, analyzing and testing an app
/// with Flutter takes 45 to 50 seconds on Linux.
const appsPerShard = 24;

/// The number of the apps with every module, one for each combination of
/// the providers of the roles that take one, and one more for each such
/// combination and each combination of the other values of the mode
/// options ([modeAppsOf]), that a plan with every combination checks all
/// of, rather than a 3-wise covering of them.
const maxEveryCombination = 100;

/// The plan of the jobs of CI that check the matrix of [modules] with
/// [roleOptions], which the matrix tools print with `--plan`, or its
/// problems: the cases of the contract harness that failed, which leave the
/// plan empty. The plan has, as JSON:
/// - `combinations`: the apps with every module that the jobs of the
///   matrix check, as the value of `--combinations`: `pairwise`, or, with
///   [everyCombination], `all` when there are at most [maxEveryCombination],
///   those for the other values of the mode options included, and `3-wise`
///   when there are more;
/// - `shards`: the shards of the matrix, `1/<count>` to
///   `<count>/<count>`, one for each job of the matrix: as many as it takes
///   for each to check at most [appsPerShard] apps, the apps of the matrix
///   and its apps with every module, which the jobs check once more in a
///   directory whose name has letters beyond ASCII. The apps with every
///   module for the other values of the mode options are apps of the
///   matrix, and count once: the jobs do not check them a second time;
/// and, with the role [native], the app entry role, whose provider owns the
/// native projects of an app, the names of the apps with every module that
/// CI generates one for each job:
/// - `apps`: a pairwise covering of them, which CI builds for Android and
///   iOS;
/// - `start`: a pairwise covering of those without the modules whose steps
///   need an external service (see [everyModuleAppsOf]), which CI starts on
///   devices;
/// - `entries`: one app for each provider of [native] (see
///   [EveryModuleAppPerProvider]), which CI archives, and configures with
///   the external services of its modules to start it.
///
/// The apps of these three lists are apps of [everyModuleAppsOf]. None is
/// an app for another value of a mode option, so a role that gets such an
/// option, or such an option that gets another value, changes only the
/// shards: what CI builds for a platform and starts on a device has the
/// first value of every mode option, the one of an app that got none.
///
/// So a new provider or module changes the plan, not the jobs of CI, and a
/// job that takes its app or shard from the plan does not take longer as the
/// apps get more: only the number of jobs grows, with a pairwise or 3-wise
/// covering rather than with every combination.
Future<({Map<String, Object> plan, List<String> problems})> matrixPlanOf(
  List<SmfModule> modules, {
  bool everyCombination = false,
  Role? native,
  Map<String, String?> roleOptions = const {},
}) async {
  // In the order found, once each.
  final problems = <String>{};
  final every = await everyModuleAppsOf(modules, roleOptions: roleOptions);
  final modes = await modeAppsOf(modules, roleOptions: roleOptions);
  final combinations = switch (everyCombination) {
    false => EveryModuleCombinations.pairwise,
    true when every.apps.length + modes.apps.length > maxEveryCombination =>
      EveryModuleCombinations.threeWise,
    true => EveryModuleCombinations.all,
  };
  final matrix = await matrixOf(
    modules,
    roleOptions: roleOptions,
    everyModuleApps: combinations,
  );
  final start = native == null
      ? null
      : await everyModuleAppsOf(
          modules,
          roleOptions: roleOptions,
          withoutExternalSteps: true,
        );
  for (final result in [
    ...matrix.failed,
    ...every.failed,
    ...?start?.failed,
  ]) {
    problems.add('${result.contractCase}: ${result.errors.join('; ')}');
  }
  if (problems.isNotEmpty) {
    return (plan: const <String, Object>{}, problems: [...problems]);
  }

  // The apps with every module for the other values of the mode options
  // are among the apps of the matrix; the second directory has none.
  final checked =
      matrix.apps.length + combinations.select(every.apps, modules).length;
  List<String> names(List<MatrixApp> apps) =>
      [for (final app in apps) app.name];
  return (
    plan: <String, Object>{
      'combinations': combinations.option,
      'shards': [
        for (final shard in MatrixShard.allOf(
          max(1, (checked + appsPerShard - 1) ~/ appsPerShard),
        ))
          '$shard',
      ],
      if (native != null) ...{
        'apps': names(
          EveryModuleCombinations.pairwise.select(every.apps, modules),
        ),
        'start': names(
          EveryModuleCombinations.pairwise.select(start!.apps, modules),
        ),
        'entries': names(
          EveryModuleAppPerProvider(native).select(every.apps, modules),
        ),
      },
    },
    problems: const <String>[],
  );
}

/// Prints the plan of [modules] (see [matrixPlanOf]) as one line of JSON,
/// for `--plan` of a matrix tool with [options], which may be
/// `--every-combination`, and returns the exit code: 0; 1, when the cases
/// of the contract harness failed, with their problems instead; and 64,
/// with the usage, for other options. [out] gets the plan, by default the
/// standard output, and [err] the problems and the usage, by default the
/// standard error.
Future<int> printMatrixPlan(
  List<SmfModule> modules,
  List<String> options, {
  Role? native,
  void Function(String line)? out,
  void Function(String line)? err,
}) async {
  // coverage:ignore-start
  // The defaults print to the terminal, as the jobs of CI read it; the
  // tests give their own.
  final printOut = out ?? _stdout;
  final printErr = err ?? _stderr;
  // coverage:ignore-end
  final everyCombination = switch (options) {
    [] => false,
    ['--every-combination'] => true,
    _ => null,
  };
  if (everyCombination == null) {
    printErr(
      'Usage: dart run tool/matrix.dart --plan [--every-combination]\n'
      'Prints, as one line of JSON, the plan of the jobs of CI that check '
      'the matrix: a pairwise covering of the apps with every module, or, '
      'with --every-combination, all of them up to $maxEveryCombination and '
      'a 3-wise covering of more.',
    );
    return 64;
  }
  final (:plan, :problems) = await matrixPlanOf(
    modules,
    everyCombination: everyCombination,
    native: native,
  );
  if (problems.isNotEmpty) {
    printErr('Problems:');
    problems.forEach(printErr);
    return 1;
  }
  printOut(jsonEncode(plan));
  return 0;
}

// The tests give their own output.
// coverage:ignore-start
void _stdout(String line) => stdout.writeln(line);

void _stderr(String line) => stderr.writeln(line);
// coverage:ignore-end
