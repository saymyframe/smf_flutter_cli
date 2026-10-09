import 'package:file/memory.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/access.dart';
import 'package:smf_pipeline/src/choices.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/identity.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/render.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/templates.dart';
import 'package:smf_pipeline/src/testing/file_indexer.dart';
import 'package:smf_pipeline/src/validation.dart';
import 'package:yaml/yaml.dart';

/// One app the harness builds to check a module or a role: the modules
/// asked for and the provider picked for each role.
final class ContractCase {
  /// Creates the case [name].
  const ContractCase(
    this.name, {
    required this.requested,
    this.picks = const {},
    this.roleOptions = const {},
  });

  /// What the case checks, such as `home (bloc) with analytics`.
  final String name;

  /// The modules asked for.
  final List<ModuleId> requested;

  /// The provider of each role that has several in the registry.
  final Map<Role, ModuleId> picks;

  /// Values of role options by name, as `--start /home` on the command
  /// line, for the choices of the roles when the app of the case is
  /// rendered. A case that the harness builds for a value of a mode option
  /// has that value here (see [ContractHarness.casesOfRole]).
  final Map<String, String?> roleOptions;

  @override
  String toString() => name;
}

/// What the harness found in one [ContractCase].
final class ContractResult {
  /// Creates the result.
  const ContractResult(
    this.contractCase,
    this.issues, {
    this.resolution,
    this.collection,
    this.validation,
    this.choices,
    this.answers = const {},
    this.app,
    this.hook,
  });

  /// The case.
  final ContractCase contractCase;

  /// The errors and warnings found.
  final List<SmfIssue> issues;

  /// The modules of the app, if the case resolved.
  final Resolution? resolution;

  /// The contributions of the app, if the case resolved.
  final Collection? collection;

  /// The result of stage 5, with the order of every socket and the merged
  /// pubspec, if the case resolved.
  final ValidationResult? validation;

  /// The results of the roles' choices, if the harness rendered the app.
  final Map<Role, Object?>? choices;

  /// The values of role options by name that make the choices of the roles
  /// whose questions the harness answered, as a user who presses Enter,
  /// without asking, such as `--start` for the first of several screens
  /// that can start the app; see [RoleTemplate.optionsOf].
  ///
  /// With the options of the case, they make a run without a terminal
  /// generate the app that the harness rendered: the harness makes the
  /// choices again without a terminal with them, and a role whose answer
  /// they do not reproduce is an error of the case.
  final Map<String, String> answers;

  /// The rendered app, if the harness rendered it: when it renders apps and
  /// the stages before found no error.
  final RenderedApp? app;

  /// The data and the roles of the [app], as the hooks of its roles got
  /// them when the harness rendered it: the data of the roles that
  /// applies, the present roles, the context of the harness and the
  /// [choices] of the roles; `null` without an [app].
  ///
  /// A role builds the input of its hooks from it with [Role.hookInput],
  /// so a test reads what the modules gave a role, and what the role
  /// chose, as every provider of the role gets it, whichever module
  /// provides it.
  final RoleHookRequest? hook;

  /// This result with [more] issues, and with the [choices], the
  /// [answers], the [app] and the [hook] if they are given.
  ContractResult _with(
    List<SmfIssue> more, {
    Map<Role, Object?>? choices,
    Map<String, String>? answers,
    RenderedApp? app,
    RoleHookRequest? hook,
  }) =>
      ContractResult(
        contractCase,
        [...issues, ...more],
        resolution: resolution,
        collection: collection,
        validation: validation,
        choices: choices ?? this.choices,
        answers: answers ?? this.answers,
        app: app ?? this.app,
        hook: hook ?? this.hook,
      );

  /// The errors among [issues].
  List<SmfIssue> get errors => [
        for (final issue in issues)
          if (issue.isError) issue,
      ];

  /// The modules of the app with their variants, and the values that the
  /// case gives the options of the roles, each as `--<name>=<value>` in the
  /// order of the names, which tell apart the apps of different cases, or
  /// `null` if the case did not resolve.
  ///
  /// It has what the case asks for, not what the roles chose, so a harness
  /// that does not render tells the apps apart too.
  String? get appKey {
    final resolution = this.resolution;
    if (resolution == null) return null;
    final modules = [
      for (final module in resolution.modules)
        '${module.id}(${module.variant ?? ''})',
    ]..sort();
    final options = [
      for (final MapEntry(:key, :value) in contractCase.roleOptions.entries)
        if (value != null) '--$key=$value',
    ]..sort();
    return [modules.join(','), ...options].join(' ');
  }
}

/// The contract test harness: checks that the modules and roles of a
/// registry follow the rules of the module model, the way the pipeline would
/// generate them in every combination that matters.
///
/// For a module it builds an app for every provider of the role of its
/// variants, every provider of each role it requires, each subset of the
/// roles it only uses with every provider of each of them, and every
/// provider of a role whose package it contributes. For a role it builds an
/// app for each of its providers, with every provider of each role the
/// provider requires, and each subset of the roles the role uses with every
/// provider of each of them. It leaves out a combination of providers that
/// would give an app two providers of a role that takes one, unless every
/// combination would, so that the cases report why. [uncheckedProviders]
/// lists each provider of a role of a module that none of the apps of the
/// module has. For a role with a mode option (see [RoleOption.mode]), it
/// builds one more app of each provider of the role for each value of the
/// option after the first, and [casesOfModes] has the apps with every
/// module once more for those values.
/// Each app goes through the stages 3 to 5 of the pipeline, in a run
/// without a terminal that skips external setup, as the Flutter job
/// generates apps; stage 5 includes [checkTemplateTags], and the
/// harness adds [missingTemplateTags] and reports templates with `{{`
/// that mason would copy as they are. Unless [render] is off, the harness
/// then makes the roles' choices (stage 7) with the options of the case,
/// renders the app in memory (stage 8) and checks the rendered code with
/// [checkRendered]. A question of a role that the options leave open, such
/// as the start screen of an app with several, gets the answer of a user
/// who presses Enter: the default, or the first choice. The result has the
/// options that make the same choice without asking
/// ([ContractResult.answers]). A mode option needs no answer. Its role
/// chooses the first value without it, in a terminal and in a run without
/// one, and the value that a case gives it otherwise: the harness reports
/// a role that does not (see [check]).
///
/// It depends on no test framework, so the tests of any package can use it.
final class ContractHarness {
  /// Creates the harness for [registry], generating apps described by
  /// [context], and rendering them unless [render] is `false`, with the
  /// [roleOptions] of every case.
  ContractHarness(
    this.registry, {
    this.context = defaultContext,
    this.render = true,
    this.roleOptions = const {},
  });

  /// The context of the apps the harness builds, with the platforms that the
  /// pipeline gives every app.
  static const defaultContext = ModuleContext(
    appName: 'contract_app',
    orgName: 'com.example',
    appIdentity: AppIdentity(
      platforms: AppNames.platforms,
      androidApplicationId: 'com.example.contract_app',
      iosBundleId: 'com.example.contract-app',
      androidNamespace: 'com.example.contract_app',
    ),
  );

  /// The modules and roles to check.
  final ModuleRegistry registry;

  /// The context of the apps the harness builds.
  final ModuleContext context;

  /// Whether the harness renders the app of every case that has no errors
  /// and checks the rendered code.
  final bool render;

  /// Values of role options by name for every case; the options of a case
  /// override them.
  ///
  /// A question of a role that no option answers gets the answer of a user
  /// who presses Enter; see [ContractResult.answers]. A mode option with a
  /// value here has that value in every app, so the harness builds no case
  /// for its other values.
  final Map<String, String?> roleOptions;

  /// The cases of the module [id]:
  /// - for each subset of the roles the module only uses, the largest
  ///   first, one case for each combination of a provider of the role of
  ///   its variants, of each role it requires and of each role of the
  ///   subset, as `<module> (<providers>) with <roles of the subset>`,
  ///   which names the providers of the roles that have several in the
  ///   registry, such as `home (bloc, firebase_analytics) with analytics`.
  ///   The providers of the role of its variants include those the module
  ///   has no variant for, whose app the pipeline rejects. A combination is
  ///   left out when two of its providers, or one of them and the module,
  ///   with the modules they depend on, provide a role that takes one
  ///   provider, as another router does for a module that depends on
  ///   go_router: they cannot be in one app. When no combination of the
  ///   subset can be in an app with the module, none is left out, so that
  ///   its cases report why, such as when the module and the modules it
  ///   depends on provide such a role twice by themselves, or when every
  ///   provider of a role it requires brings another provider of a role
  ///   that the module has through a module it depends on;
  /// - every provider of a role in the registry whose package the module
  ///   contributes, itself or in a variant, and that can be in an app with
  ///   the module, as `<module> with <provider>`, such as `banner with
  ///   bloc` for a module without a role that contributes `flutter_bloc`.
  ///   The case requests the provider, so its roles need no pick. With a
  ///   provider of a role other than that of the variants of the module,
  ///   there is a case for each variant that contributes the package, as
  ///   `<module> (<provider of the variant>) with <provider>`, or for the
  ///   first variant if only the module itself contributes it.
  ///
  /// A package is a provider's when the provider contributes it itself, not
  /// in a variant, with a constraint of its own rather than `any`, and no
  /// module that the provider depends on, directly or not, contributes it
  /// so too. Another module takes such a package only in its variant for the
  /// provider, or for a provider that depends on it, or when it depends on
  /// the provider, and the pipeline checks that only in an app with the
  /// provider, which the last cases build. A provider can be in an app with
  /// the module when neither they nor the modules they depend on, directly
  /// or not, provide a role that takes one provider twice, and each of them
  /// that has variants has one for the provider of the role of its variants
  /// among them.
  ///
  /// A role left out of a subset is still present when a module of the case
  /// brings it, such as a provider of several roles or a module that
  /// requires it. [checkAll] then leaves out the case, since the case of a
  /// larger subset built its app already and names the roles it has; so it
  /// does with a case with a provider whose app another case built.
  List<ContractCase> casesOfModule(ModuleId id) {
    final module = registry[id];
    if (module == null) throw ArgumentError.value(id, 'id', 'Not registered');
    final descriptor = module.descriptor;
    final used = [
      for (final role in descriptor.effectiveUses)
        if (registry.providersOf(role).isNotEmpty) role,
    ];
    final withDependencies = _withDependencies(module);
    return [
      for (final subset in _subsets(used))
        for (final picks in _fittingPicks(
          withDependencies,
          _picksOf([
            if (descriptor.variants case final variants?) variants.role,
            ...descriptor.effectiveRequires,
            ...subset,
          ]),
        ))
          _case(
            _caseName(id.value, picks, subset),
            [id],
            picks: picks,
            present: subset,
          ),
      ..._casesWithOwners(module),
    ];
  }

  /// The cases of [module] with the providers that own a package it
  /// contributes; see [casesOfModule].
  List<ContractCase> _casesWithOwners(SmfModule module) {
    final id = module.descriptor.id;
    return [
      for (final owner in _ownersOfPackagesOf(module))
        for (final picks in _variantPicksWith(module, owner))
          _case(
            '${_caseName(id.value, picks, const [])} with '
            '${owner.descriptor.id}',
            [id, owner.descriptor.id],
            picks: {
              ...picks,
              for (final role in owner.descriptor.provides)
                role: owner.descriptor.id,
            },
            present: const [],
          ),
    ];
  }

  /// The providers of roles in the registry, besides [module], that own a
  /// hosted package that [module] contributes, itself or in any of its
  /// variants, and can be in an app with [module]; see [casesOfModule].
  List<SmfModule> _ownersOfPackagesOf(SmfModule module) {
    final taken = _packagesTakenBy(module);
    if (taken.isEmpty) return const [];
    return [
      for (final other in registry.modules)
        if (other.descriptor.id != module.descriptor.id &&
            other.descriptor.provides.isNotEmpty &&
            _ownsOneOf(other, taken) &&
            _fit([..._withDependencies(module), ..._withDependencies(other)]))
          other,
    ];
  }

  /// Whether [modules] can be in one app: no two of them provide a role
  /// that takes one provider, and each that has variants has one for the
  /// provider among them of the role of its variants.
  static bool _fit(List<SmfModule> modules) {
    final providers = _singleProviders(modules);
    return providers != null &&
        modules.every((module) {
          final variants = module.descriptor.variants;
          final provider = providers[variants?.role];
          return provider == null || variants!.byProvider.containsKey(provider);
        });
  }

  /// The provider among [modules] of each role that takes one provider, or
  /// `null` if two of them provide such a role.
  static Map<Role, ModuleId>? _singleProviders(List<SmfModule> modules) {
    final providers = <Role, ModuleId>{};
    for (final module in modules) {
      final id = module.descriptor.id;
      for (final role in module.descriptor.provides) {
        if (!role.cardinality.allowsMany &&
            providers.putIfAbsent(role, () => id) != id) {
          return null;
        }
      }
    }
    return providers;
  }

  /// Those of the [combinations] of providers that can be in one app with
  /// [modules], a module or the provider of a role with the modules it
  /// depends on: no role that takes one provider has two among [modules]
  /// and the picked providers with the modules they depend on. The variants
  /// of the modules do not count, so a provider of the role of the variants
  /// of a module that the module has no variant for fits still.
  ///
  /// When none fits, such as when [modules] have two providers of such a
  /// role by themselves, it keeps all of the [combinations], so that the
  /// cases report why none can be in an app.
  List<Map<Role, ModuleId>> _fittingPicks(
    List<SmfModule> modules,
    List<Map<Role, ModuleId>> combinations,
  ) {
    bool fits(Map<Role, ModuleId> picks) {
      final picked = [
        for (final id in picks.values) ..._withDependencies(registry[id]!),
      ];
      return _singleProviders([...modules, ...picked]) != null;
    }

    final fitting = combinations.where(fits).toList();
    return fitting.isEmpty ? combinations : fitting;
  }

  /// The provider of the role of the variants of [module] for each case of
  /// [module] with [owner]: none if [module] has no variants, or it or
  /// [owner] brings a provider of the role; else each provider whose
  /// variant contributes a package of [owner], or, if only [module] itself
  /// does, the first provider with a variant. A provider whose modules do
  /// not fit in the app of the case has none.
  List<Map<Role, ModuleId>> _variantPicksWith(
    SmfModule module,
    SmfModule owner,
  ) {
    final modules = [..._withDependencies(module), ..._withDependencies(owner)];
    final variants = module.descriptor.variants;
    if (variants == null) return const [{}];
    final role = variants.role;
    if (modules.any((other) => other.descriptor.provides.contains(role))) {
      return const [{}];
    }
    final owned = _packagesOwnedBy(owner);
    bool takes(List<Contribution> Function(ModuleContext context) contribute) =>
        _hostedPackagesOf(contribute).any(owned.contains);
    final fitting = [
      for (final provider in registry.providersOf(role))
        if (variants.byProvider[provider.descriptor.id] case final variant?
            when _fit([...modules, ..._withDependencies(provider)]))
          (id: provider.descriptor.id, takes: takes(variant)),
    ];
    final taking = [
      for (final provider in fitting)
        if (provider.takes) provider.id,
    ];
    if (taking.isEmpty && fitting.isNotEmpty && takes(module.contribute)) {
      taking.add(fitting.first.id);
    }
    return [
      for (final provider in taking) {role: provider},
    ];
  }

  /// Whether [provider] owns one of [packages]; see [_packagesOwnedBy].
  bool _ownsOneOf(SmfModule provider, Set<String> packages) =>
      _packagesOwnedBy(provider).any(packages.contains);

  /// The packages that [provider] owns: it brings them, and no module it
  /// depends on, directly or not, brings them too.
  Set<String> _packagesOwnedBy(SmfModule provider) =>
      _packagesBroughtBy(provider).difference({
        for (final dependency in _withDependencies(provider).skip(1))
          ..._packagesBroughtBy(dependency),
      });

  /// The hosted packages that [module] contributes itself, not in a
  /// variant, with a constraint of its own ([bringsPackage]).
  Set<String> _packagesBroughtBy(SmfModule module) => {
        for (final contribution in _contributionsOf(module.contribute))
          if (contribution case final PubspecDependency dependency
              when bringsPackage(dependency))
            dependency.package,
      };

  /// The hosted packages that [module] contributes, itself or in any of its
  /// variants, with any constraint.
  Set<String> _packagesTakenBy(SmfModule module) => {
        for (final contribute in [
          module.contribute,
          ...?module.descriptor.variants?.byProvider.values,
        ])
          ..._hostedPackagesOf(contribute),
      };

  /// The hosted packages that [contribute] contributes, with any
  /// constraint.
  Set<String> _hostedPackagesOf(
    List<Contribution> Function(ModuleContext context) contribute,
  ) =>
      {
        for (final contribution in _contributionsOf(contribute))
          if (contribution
              case PubspecDependency(
                source: PubspecSource.hosted,
                :final package,
              ))
            package,
      };

  /// What [contribute] contributes to the app of [context], or nothing if it
  /// throws: the cases of its module report that.
  List<Contribution> _contributionsOf(
    List<Contribution> Function(ModuleContext context) contribute,
  ) {
    try {
      return contribute(context);
    } on Object {
      return const [];
    }
  }

  /// The cases of [role]: for each of its providers and each subset of the
  /// roles the role uses, the largest first, one case for each combination
  /// of a provider of each role the provider requires and of each role of
  /// the subset, named as the cases of [casesOfModule] are, such as
  /// `analytics by firebase_analytics (get_it) with di`. As for a module, a
  /// combination whose providers cannot be in one app with the provider is
  /// left out, such as another provider of a role that the provider
  /// provides too, unless no combination of the subset can.
  ///
  /// After them come the cases of the mode options of [role] (see
  /// [RoleOption.mode]): for each provider and each value of such an option
  /// after the first, the first case of the provider, which has every role
  /// that the role uses, once more with that value among its
  /// [ContractCase.roleOptions], named `<case> --<option>=<value>`, such as
  /// `clock by sundial --clock-hours=12`. The cases before them leave the
  /// option out, so their apps have its first value. A role with two such
  /// options gets a case for each value of each, not for each pair of
  /// them. An option that [roleOptions] give a value has no such cases.
  List<ContractCase> casesOfRole(Role role) {
    final used = [
      for (final other in role.uses)
        if (registry.providersOf(other).isNotEmpty) other,
    ];
    final byProvider = [
      for (final provider in registry.providersOf(role))
        [
          for (final subset in _subsets(used))
            for (final picks in _fittingPicks(
              _withDependencies(provider),
              _picksOf([...provider.descriptor.effectiveRequires, ...subset]),
            ))
              _case(
                _caseName(
                  '${role.id} by ${provider.descriptor.id}',
                  picks,
                  subset,
                ),
                [provider.descriptor.id],
                picks: {...picks, role: provider.descriptor.id},
                present: subset,
              ),
        ],
    ];
    final modes = _openModesOf([role]);
    return [
      for (final cases in byProvider) ...cases,
      // The subsets come the largest first, so the first case of a provider
      // has every role that the role uses.
      for (final cases in byProvider)
        for (final option in modes)
          for (final value in option.allowed!.skip(1))
            _withModes(cases.first, {option.name: value}),
    ];
  }

  /// The mode options of [roles] that [roleOptions] give no value, so that
  /// their values set the apps of the cases apart.
  List<RoleOption> _openModesOf(Iterable<Role> roles) => [
        for (final role in roles)
          for (final option in role.options)
            if (option.isMode && roleOptions[option.name] == null) option,
      ];

  /// [contractCase] with [modes], values of mode options by name, among
  /// its options and after its name, each as `--<name>=<value>`.
  static ContractCase _withModes(
    ContractCase contractCase,
    Map<String, String> modes,
  ) =>
      ContractCase(
        [
          contractCase.name,
          for (final MapEntry(:key, :value) in modes.entries) '--$key=$value',
        ].join(' '),
        requested: contractCase.requested,
        picks: contractCase.picks,
        roleOptions: {...contractCase.roleOptions, ...modes},
      );

  /// The name of a case of [subject], such as `home` or `analytics by
  /// firebase_analytics`, with the providers it [picks] and the [subset] of
  /// the roles it uses.
  static String _caseName(
    String subject,
    Map<Role, ModuleId> picks,
    List<Role> subset,
  ) =>
      [
        subject,
        if (picks.isNotEmpty) '(${picks.values.join(', ')})',
        if (subset.isNotEmpty)
          'with ${subset.map((role) => role.id).join(', ')}',
      ].join(' ');

  /// The cases of the apps with as many modules as one app can have, one
  /// for every combination of providers of the roles that take at most one
  /// and have several.
  ///
  /// Each has the provider of the combination of those roles, the first
  /// registered provider of every other role that takes one, every provider
  /// of a role that takes many, and every other module that fits: neither it
  /// nor a module it depends on provides a role that takes one and has
  /// another provider in the app, and each has a variant for the provider
  /// of the role of its variants. A combination whose provider does not fit
  /// has no case.
  List<ContractCase> casesOfAll() => [
        for (final picked in _picksOf([
          for (final role in registry.roles)
            if (!role.cardinality.allowsMany) role,
        ]))
          if (_caseOfAll(picked) case final contractCase?) contractCase,
      ];

  ContractCase? _caseOfAll(Map<Role, ModuleId> picked) {
    final providers = {
      for (final role in registry.roles)
        if (registry.providersOf(role) case [final first, ...])
          role: picked[role] ?? first.descriptor.id,
    };
    bool fits(SmfModule module) {
      final descriptor = module.descriptor;
      final variants = descriptor.variants;
      return descriptor.provides.every(
            (role) =>
                role.cardinality.allowsMany || providers[role] == descriptor.id,
          ) &&
          (variants == null ||
              variants.byProvider.containsKey(providers[variants.role]));
    }

    final requested = [
      for (final module in registry.modules)
        if (_withDependencies(module).every(fits)) module.descriptor.id,
    ];
    if (!picked.values.every(requested.contains)) return null;
    return ContractCase(
      picked.isEmpty
          ? 'every module'
          : 'every module (${picked.values.join(', ')})',
      requested: requested,
      picks: providers,
    );
  }

  /// The cases of the apps with every module for the other values of the
  /// mode options (see [RoleOption.mode]): each case of [casesOfAll] once
  /// more for every combination of the values of the mode options of the
  /// roles of its app, but the combination of the first value of each,
  /// which is the app of [casesOfAll] itself.
  ///
  /// Each has the values of its combination other than the first of their
  /// options among its [ContractCase.roleOptions] and after its name, such
  /// as `every module (riverpod) --clock-hours=12`; an option with its
  /// first value is left out, as in [casesOfAll]. An option of a role that
  /// the app lacks has no cases, nor has one that [roleOptions] give a
  /// value.
  List<ContractCase> casesOfModes() => [
        for (final contractCase in casesOfAll())
          for (final modes in _modeCombinations(
            _openModesOf(_rolesOf(contractCase)),
          ).skip(1))
            _withModes(contractCase, modes),
      ];

  /// The roles of the app of [contractCase], a case of [casesOfAll], which
  /// asks for every module of its app: those that its modules provide, in
  /// the order of the registry.
  List<Role> _rolesOf(ContractCase contractCase) {
    final provided = {
      for (final id in contractCase.requested)
        ...registry[id]!.descriptor.provides,
    };
    return [
      for (final role in registry.roles)
        if (provided.contains(role)) role,
    ];
  }

  /// Every combination of the values of [options], mode options: each has
  /// the values other than the first of their options, by the name of the
  /// option. The first combination, of the first value of each option, has
  /// none.
  static List<Map<String, String>> _modeCombinations(
    List<RoleOption> options,
  ) {
    var combinations = <Map<String, String>>[{}];
    for (final option in options) {
      final values = option.allowed!;
      combinations = [
        for (final combination in combinations)
          for (final value in values)
            {...combination, if (value != values.first) option.name: value},
      ];
    }
    return combinations;
  }

  /// [module] and the registered modules it depends on, directly or not.
  List<SmfModule> _withDependencies(SmfModule module) {
    final found = <ModuleId, SmfModule>{module.descriptor.id: module};
    final pending = [module];
    while (pending.isNotEmpty) {
      for (final id in pending.removeLast().descriptor.dependsOn) {
        final dependency = registry[id];
        if (dependency != null && found[id] == null) {
          found[id] = dependency;
          pending.add(dependency);
        }
      }
    }
    return [...found.values];
  }

  /// Every combination of providers of those [roles] that have several in
  /// the registry.
  List<Map<Role, ModuleId>> _picksOf(List<Role> roles) {
    var combinations = <Map<Role, ModuleId>>[{}];
    for (final role in {...roles}) {
      final providers = registry.providersOf(role);
      if (providers.length < 2) continue;
      combinations = [
        for (final combination in combinations)
          for (final provider in providers)
            {...combination, role: provider.descriptor.id},
      ];
    }
    return combinations;
  }

  ContractCase _case(
    String name,
    List<ModuleId> requested, {
    required Map<Role, ModuleId> picks,
    required List<Role> present,
  }) {
    final all = {...picks};
    for (final role in registry.roles) {
      final providers = registry.providersOf(role);
      if (providers.isNotEmpty) {
        all.putIfAbsent(role, () => providers.first.descriptor.id);
      }
    }
    return ContractCase(
      name,
      requested: [
        ...requested,
        for (final role in present)
          if (!requested.contains(all[role])) all[role]!,
      ],
      picks: all,
    );
  }

  /// Runs the stages 3 to 5 of the pipeline and [missingTemplateTags] for
  /// [contractCase], then, if [render] is on and they found no error, the
  /// stages 7 and 8 and [checkRendered].
  ///
  /// Before the stage 7, it reports a value that the case or [roleOptions]
  /// give an option that does not take it (see [RoleOption.allowed]), as
  /// the command line would refuse it, and makes no choice with it.
  ///
  /// Between the stages 7 and 8, it holds the choice of each role of the
  /// app with a mode option to what the option states (see
  /// [RoleOption.mode]). For that it makes the choices of the app a second
  /// time, without a terminal, as `smf create --no-input` makes them when
  /// the matrices generate the app. The value of a choice is what
  /// [RoleTemplate.optionsOf] gives the option for it:
  /// - with a value of the option, from the case or from [roleOptions], the
  ///   choice has that value in both runs, so a template that does not
  ///   read the option, or not without a terminal, is an error;
  /// - without one, the choice has the first value of the option in both
  ///   runs, also when the role asks and the harness answers as a user who
  ///   presses Enter;
  /// - no role fails or asks in the run without a terminal, which gets no
  ///   value for a mode option that the case leaves out;
  /// - the two choices of the role are equal, so that the run without a
  ///   terminal generates the app that the harness renders.
  ///
  /// An app with such an error is not rendered.
  Future<ContractResult> check(ContractCase contractCase) async {
    final environment = PipelineEnvironment(
      _silentHost,
      interactive: false,
      skipExternalSetup: true,
    );
    final ResolverResult resolved;
    try {
      resolved = await resolve(
        requested: contractCase.requested,
        registry: registry,
        environment: environment,
        answers: {...contractCase.picks},
      );
    } on SmfUsageException catch (error) {
      return ContractResult(contractCase, [SmfIssue(error.message)]);
    }
    final resolution = resolved.resolution;
    if (resolution == null) {
      return ContractResult(contractCase, resolved.issues);
    }
    final collection = collect(resolution, context);
    final validation = validate(
      registry: registry,
      resolution: resolution,
      collection: collection,
      context: context,
      interactive: environment.interactive,
      skipExternalSetup: environment.skipExternalSetup,
    );
    final checked = ContractResult(
      contractCase,
      [
        ...resolved.issues,
        ...validation.issues,
        ...missingTemplateTags(
          registry: registry,
          resolution: resolution,
          collection: collection,
        ),
        ..._copiedTemplateIssues(collection),
      ],
      resolution: resolution,
      collection: collection,
      validation: validation,
    );
    if (!render || checked.errors.isNotEmpty) return checked;

    final options = {...roleOptions, ...contractCase.roleOptions};
    final refused = _refusedValues(options);
    if (refused.isNotEmpty) return checked._with(refused);
    final Map<Role, Object?> choices;
    final RenderedApp app;
    final answering = _EnterPrompter();
    // The choices of the roles that asked, which the harness answered.
    final answered = <Role, Object?>{};
    final Map<String, String> answers;
    try {
      choices = await chooseRoles(
        registry: registry,
        resolution: resolution,
        collection: collection,
        optionValues: options,
        environment: PipelineEnvironment(
          _answeringHost(answering),
          interactive: true,
          skipExternalSetup: true,
        ),
        context: context,
        onChoice: (role, choice) {
          if (!answering.asked) return;
          answering.asked = false;
          answered[role] = choice;
        },
      );
      final (options: given, :problems) = await _answersOf(
        answered,
        resolution: resolution,
        collection: collection,
        options: options,
      );
      if (problems.isNotEmpty) {
        return checked._with(problems, choices: choices);
      }
      final ofModes = await _modeProblems(
        choices,
        asked: {...answered.keys},
        resolution: resolution,
        collection: collection,
        options: options,
        answers: given,
      );
      if (ofModes.isNotEmpty) {
        return checked._with(ofModes, choices: choices);
      }
      answers = given;
      app = renderApp(
        registry: registry,
        resolution: resolution,
        collection: collection,
        context: context,
        choices: choices,
        pubspec: validation.pubspec,
      );
    } on SmfUsageException catch (error) {
      return checked._with([SmfIssue(error.message)]);
    } on GenerationFailedException catch (error) {
      return checked._with([
        if (error.issues.isEmpty) SmfIssue(error.message),
        ...error.issues,
      ]);
    }
    final rendered = checked._with(
      const [],
      choices: choices,
      answers: answers,
      app: app,
      hook: hookRequest(
        registry: registry,
        resolution: resolution,
        collection: collection,
        context: context,
        choices: choices,
      ),
    );
    return rendered._with(checkRendered(rendered, app));
  }

  /// The values among [options], the values of role options of a case by
  /// name, that their options do not take: a value outside the allowed
  /// ones of an option of a role of the registry (see [RoleOption.allowed]),
  /// such as one that is not among the values of a mode option. The
  /// command line refuses such a value in every app, also in one without
  /// the role, so the app of the case could not be generated with it.
  List<SmfIssue> _refusedValues(Map<String, String?> options) => [
        for (final role in registry.roles)
          for (final option in role.options)
            if ((option.allowed, options[option.name])
                case (final allowed?, final value?)
                when !allowed.contains(value))
              SmfIssue(
                '--${option.name}=$value is not a value of the option of '
                'the $role, which takes ${allowed.join(', ')}: the command '
                'line refuses it.',
                hint: 'Give the option one of its values, or leave it out.',
              ),
      ];

  /// The options that the templates of the roles in [answered] give for the
  /// choices that the harness answered, and the problems of those options:
  /// a role that gives none, or one that it does not declare, and options
  /// with which a run without a terminal, with [options] too, fails or
  /// makes another choice.
  Future<({Map<String, String> options, List<SmfIssue> problems})> _answersOf(
    Map<Role, Object?> answered, {
    required Resolution resolution,
    required Collection collection,
    required Map<String, String?> options,
  }) async {
    final (options: given, :problems) = _optionsOfAnswers(answered);
    if (answered.isEmpty || problems.isNotEmpty) {
      return (options: given, problems: problems);
    }

    // A run without a terminal has to make the same choices with them.
    final shown = [
      for (final MapEntry(:key, :value) in given.entries) '--$key $value',
    ].join(' ');
    final Map<Role, Object?> again;
    try {
      again = await chooseRoles(
        registry: registry,
        resolution: resolution,
        collection: collection,
        optionValues: {...options, ...given},
        environment: PipelineEnvironment(
          _silentHost,
          interactive: false,
          skipExternalSetup: true,
        ),
        context: context,
      );
    } on SmfUsageException catch (error) {
      return (
        options: given,
        problems: [
          SmfIssue(
            'A run without a terminal cannot make the choices that the '
            'harness answered with $shown: ${error.message}',
          ),
        ],
      );
    }
    for (final MapEntry(key: role, value: choice) in answered.entries) {
      if (again[role] != choice) {
        problems.add(
          SmfIssue(
            'With $shown, the $role makes the choice ${again[role]} in a '
            'run without a terminal, not $choice, which the harness answered.',
            origin: RoleTemplateOrigin(role),
          ),
        );
      }
    }
    return (options: given, problems: problems);
  }

  /// The options that the templates of the roles in [answered] give for
  /// the choices that the harness answered, and the problems: a role that
  /// gives none for its choice, or one that it does not declare.
  ({Map<String, String> options, List<SmfIssue> problems}) _optionsOfAnswers(
    Map<Role, Object?> answered,
  ) {
    final given = <String, String>{};
    final problems = <SmfIssue>[];
    for (final MapEntry(key: role, value: choice) in answered.entries) {
      final origin = RoleTemplateOrigin(role);
      final ofChoice = role.template!.optionsOf(choice);
      if (ofChoice.isEmpty) {
        problems.add(
          SmfIssue(
            'The $role asks a question, but its template gives no '
            'option for the answer, $choice, so a run without a terminal '
            'cannot make the choice.',
            hint: 'Give the options of the answer from optionsOf() of the '
                'template.',
            origin: origin,
          ),
        );
      }
      final declared = {for (final option in role.options) option.name};
      for (final name in ofChoice.keys) {
        if (!declared.contains(name)) {
          problems.add(
            SmfIssue(
              'The template of the $role gives --$name for an answer, '
              'but the $role has no such option.',
              origin: origin,
            ),
          );
        }
      }
      given.addAll(ofChoice);
    }
    return (options: given, problems: problems);
  }

  /// The problems of the mode options of the roles of an app (see
  /// [RoleOption.mode]), whose roles made [choices] in a terminal with
  /// [options], where the harness answered the questions of the roles in
  /// [asked] as a user who presses Enter; see [check]. [answers] are the
  /// options that make the choices that the harness answered.
  ///
  /// It makes the choices again without a terminal, as the matrices
  /// generate every app, with [options] and [answers] but no answer for a
  /// mode option: one that [options] give has that value, and no run needs
  /// the others. Then it holds each role with a mode option to the option
  /// in both runs, and the two choices of the role to one another:
  /// - The value of a choice is what [RoleTemplate.optionsOf] gives the
  ///   option for it, so a template that gives none is reported too. It is
  ///   the value that [options] give, or the first value of the option.
  ///   Both runs with the same other value are one problem.
  /// - The choices of the two runs are equal. A role that asks is held to
  ///   that by its answers already; this holds one that asks nothing, or
  ///   that gets every answer from [options].
  /// - A role that fails or asks in the run without a terminal is a
  ///   problem of that role, also when it has no mode option: the apps of
  ///   the case cannot be generated without a terminal. The roles that
  ///   chose before it are still checked.
  Future<List<SmfIssue>> _modeProblems(
    Map<Role, Object?> choices, {
    required Set<Role> asked,
    required Resolution resolution,
    required Collection collection,
    required Map<String, String?> options,
    required Map<String, String> answers,
  }) async {
    final modes = <Role, List<RoleOption>>{};
    for (final role in resolution.presentRoles) {
      for (final option in role.options) {
        if (option.isMode) modes.putIfAbsent(role, () => []).add(option);
      }
    }
    if (modes.isEmpty) return const [];
    final names = {
      for (final ofRole in modes.values)
        for (final option in ofRole) option.name,
    };

    // The choices of the run without a terminal, of the roles that made
    // one before a role failed.
    final again = <Role, Object?>{};
    String? failure;
    try {
      await chooseRoles(
        registry: registry,
        resolution: resolution,
        collection: collection,
        optionValues: {
          ...options,
          for (final MapEntry(:key, :value) in answers.entries)
            if (!names.contains(key)) key: value,
        },
        environment: PipelineEnvironment(
          _silentHost,
          interactive: false,
          skipExternalSetup: true,
        ),
        context: context,
        onChoice: (role, choice) => again[role] = choice,
      );
    } on SmfUsageException catch (error) {
      failure = error.message;
    } on GenerationFailedException catch (error) {
      // As when the template asks, which the harness cannot answer there.
      failure = error.message;
    }
    return [
      if (failure != null)
        _failedWithoutTerminal(
          failure,
          // The roles choose in the order of the present roles, so the
          // first role with a template that has not chosen is the one
          // that failed.
          resolution.presentRoles.firstWhere(
            (role) => role.template != null && !again.containsKey(role),
          ),
          modes: modes,
          options: options,
        ),
      for (final MapEntry(key: role, value: ofRole) in modes.entries)
        ..._choiceProblems(
          role,
          ofRole,
          options: options,
          inTerminal: choices[role],
          asked: asked.contains(role),
          choseAgain: again.containsKey(role),
          again: again[role],
        ),
    ];
  }

  /// The problem of [role], which failed with [failure] to choose in the
  /// run without a terminal: it names the mode options of [role] among
  /// [modes] that [options] give no value, which the role must not need.
  static SmfIssue _failedWithoutTerminal(
    String failure,
    Role role, {
    required Map<Role, List<RoleOption>> modes,
    required Map<String, String?> options,
  }) {
    final open = [
      for (final option in modes[role] ?? const <RoleOption>[])
        if (options[option.name] == null) '--${option.name}',
    ];
    return SmfIssue(
      'The $role cannot choose in a run without a terminal'
      '${open.isEmpty ? '' : ' and without ${open.join(', ')}'}: $failure',
      hint: open.isEmpty
          ? null
          : 'A mode option has a default, its first value, so no run needs '
              'it: without a terminal, choose() of the template chooses '
              'that value and asks nothing.',
      origin: RoleTemplateOrigin(role),
    );
  }

  /// The problems of the choices of [role], a role with the mode options
  /// [modes], with [options]: [inTerminal], where the harness answered a
  /// question of the role if it [asked], and [again], in the run without a
  /// terminal, if the role chose there ([choseAgain]); see [_modeProblems].
  static List<SmfIssue> _choiceProblems(
    Role role,
    List<RoleOption> modes, {
    required Map<String, String?> options,
    required Object? inTerminal,
    required bool asked,
    required bool choseAgain,
    required Object? again,
  }) {
    // The registry takes no role with an option and no template.
    final template = role.template!;
    final terminal =
        asked ? 'when the user presses Enter at its question' : 'in a terminal';
    const script = 'in a run without a terminal';
    final problems = <SmfIssue>[];
    var sameValues = true;
    for (final option in modes) {
      final name = option.name;
      final given = options[name];
      final expected = given ?? option.allowed!.first;
      final first = template.optionsOf(inTerminal)[name];
      final second = choseAgain ? template.optionsOf(again)[name] : first;

      /// The problem of [choice], whose option has [value], not [expected].
      SmfIssue problem(Object? choice, String? value, String where) {
        final gives = value == null ? 'no --$name' : '--$name $value';
        final run = given == null ? 'Without --$name' : 'With --$name $given';
        final rule = given == null
            ? 'the first value of a mode option is its default'
            : 'the choice of a mode option is its value';
        return SmfIssue(
          '$run, the $role makes the choice $choice $where, for which its '
          'template gives $gives, not --$name $expected: $rule.',
          hint: 'In choose() of the template, read the option, and choose '
              'its first value without it, which a question offers first. '
              'In optionsOf(), give the option for every choice.',
          origin: RoleTemplateOrigin(role),
        );
      }

      if (first != expected) {
        // One problem when both runs have the same other value.
        final both = choseAgain && second == first;
        problems.add(
          problem(inTerminal, first, both ? '$terminal and $script' : terminal),
        );
      }
      if (second != first) {
        sameValues = false;
        if (second != expected) problems.add(problem(again, second, script));
      }
    }
    // Choices with different values of a mode option are reported above.
    if (choseAgain && sameValues && again != inTerminal) {
      problems.add(
        SmfIssue(
          'The $role makes the choice $again $script, not $inTerminal, its '
          'choice in a terminal with the same options: a run without a '
          'terminal would generate another app than the harness renders.',
          hint: 'The choices of a role with a mode option compare by value, '
              'and are the same with a terminal and without one.',
          origin: RoleTemplateOrigin(role),
        ),
      );
    }
    return problems;
  }

  /// Checks every case of every module and every role of the registry, and
  /// returns the results of the cases whose app no case before built. A
  /// case with a value of a role option builds an app of its own, as the
  /// cases of the mode options do (see [casesOfRole]).
  Future<List<ContractResult>> checkAll() async {
    final results = <ContractResult>[];
    final apps = <String>{};
    for (final contractCase in [
      for (final module in registry.modules)
        ...casesOfModule(module.descriptor.id),
      for (final role in registry.roles) ...casesOfRole(role),
    ]) {
      final result = await check(contractCase);
      final key = result.appKey;
      if (key == null || apps.add(key)) results.add(result);
    }
    return results;
  }

  /// The providers that the harness checks no module with, though the
  /// module requires or uses their role, one line for each: a provider of a
  /// role that a module of the registry requires or uses, which can be in
  /// an app with the module (see [casesOfModule]) but provides the role in
  /// no app of the cases of the module. Either no case asks for the
  /// provider, or the apps of those that do fail to resolve, such as when
  /// no module of the registry provides a role that the provider requires.
  ///
  /// The tests of a registry expect none, so that the harness checks each
  /// module with every provider of its roles, also when a role gets another
  /// provider.
  Future<List<String>> uncheckedProviders() async => [
        for (final module in registry.modules)
          ..._uncheckedProvidersOf(module, await _resolvedAppsOf(module)),
      ];

  /// The modules of the app of each case of [module] that resolves.
  Future<List<Resolution>> _resolvedAppsOf(SmfModule module) async => [
        for (final contractCase in casesOfModule(module.descriptor.id))
          if (await _resolutionOf(contractCase) case final resolution?)
            resolution,
      ];

  /// The providers of the roles that [module] requires or uses which can be
  /// in an app with it but provide the role in none of [apps], the apps of
  /// its cases, one line for each; see [uncheckedProviders].
  List<String> _uncheckedProvidersOf(SmfModule module, List<Resolution> apps) {
    final descriptor = module.descriptor;
    bool checks(Role role, ModuleId provider) => apps.any(
          (app) => app.providersOf(role).any((other) => other.id == provider),
        );
    final unchecked = <String>[];
    for (final (roles, verb) in [
      (descriptor.effectiveRequires, 'requires'),
      (descriptor.effectiveUses, 'uses'),
    ]) {
      for (final role in roles) {
        for (final provider in registry.providersOf(role)) {
          final id = provider.descriptor.id;
          if (_fit([
                ..._withDependencies(module),
                ..._withDependencies(provider),
              ]) &&
              !checks(role, id)) {
            unchecked.add(
              'No case of ${descriptor.id} builds an app in which $id '
              'provides the $role, which ${descriptor.id} $verb.',
            );
          }
        }
      }
    }
    return unchecked;
  }

  /// The modules of the app of [contractCase], or `null` if it does not
  /// resolve.
  Future<Resolution?> _resolutionOf(ContractCase contractCase) async {
    try {
      final resolved = await resolve(
        requested: contractCase.requested,
        registry: registry,
        environment: PipelineEnvironment(
          _silentHost,
          interactive: false,
          skipExternalSetup: true,
        ),
        answers: {...contractCase.picks},
      );
      return resolved.resolution;
    } on SmfUsageException {
      return null;
    }
  }

  /// Indexes the Dart files among [files], the text files of the rendered
  /// app of [result] by path, runs the structural rules of its present roles
  /// with the data it collected and the texts, and checks the symbols of
  /// their interfaces.
  ///
  /// [owners] names who generated each file; the rules of the roles check
  /// only files with an owner.
  ///
  /// Throws an [ArgumentError] if the case of [result] did not resolve.
  List<SmfIssue> checkStructure(
    ContractResult result, {
    required Map<String, String> files,
    required Map<String, ContributionOrigin> owners,
  }) {
    final (:indexes, :issues) = _index(files, owners);
    return [...issues, ..._structureIssues(result, indexes, files, owners)];
  }

  /// Checks [app], the rendered app of [result], the files that its render
  /// hooks generated like those of its bricks:
  /// - the structural rules and symbols of the roles, see [checkStructure];
  /// - every import or export of a file of the app finds the file, or a
  ///   file that code generation or Flutter's localizations generate;
  /// - no brick and no render hook generates a file where code generation
  ///   or Flutter's localizations write theirs once the app is rendered;
  /// - `l10n.yaml`, when the pubspec has Flutter generate the
  ///   localizations, is what `flutter pub get` can read: YAML with a map
  ///   of options, each of the type that Flutter reads it as, and without
  ///   `synthetic-package: true`;
  /// - every imported or exported package is a dependency of the app, a
  ///   regular one for the code in `lib/` and `bin/`;
  /// - a module imports or exports the package of a provider of a role in
  ///   the app, in a template or for a fragment, only when it contributes
  ///   the package too, itself or in its variant, so that the pipeline
  ///   checks that it may take the package (see [casesOfModule]); a
  ///   provider of a role may import it for a fragment, or in a file that
  ///   its render hook generates, when a module that gives the role data
  ///   contributes it, as the data may need it;
  /// - a file imports and exports only files that its owner may use, and
  ///   the pipeline added only imports that the contributors of the
  ///   fragments may use: their own files, the files of the modules they
  ///   depend on directly, the files of the roles they provide,
  ///   require or use (the files of each role's template and the files of
  ///   its required symbols). The template and the providers of a role
  ///   render the data that its hooks read, so the code that a render hook
  ///   of theirs gives may also import the files of those who contribute
  ///   data to the role or to a role that it requires or uses: an import
  ///   that the pipeline added for a fragment of the hook, one of
  ///   [RoleOutput.fragments] or a fragment variable, and one in a file
  ///   that the hook generated. No other import of theirs reaches a file
  ///   through the data: not one that the template of a brick has itself,
  ///   and not one for a fragment of their contributions, a socket
  ///   contribution or the code of a [RoleVar], which are the same whatever
  ///   the modules give the role. The bound is who gave the import, not the
  ///   files that the data names: a render hook that names a file of a
  ///   module itself passes in an app with the module, and the cases of its
  ///   owner without that module report the import, which the app then
  ///   cannot resolve. The cases the harness builds have one provider of
  ///   each role, so there a provider cannot reach the files of another
  ///   through the data.
  ///
  /// Throws an [ArgumentError] if the case of [result] did not resolve.
  List<SmfIssue> checkRendered(ContractResult result, RenderedApp app) {
    final owners = app.owners;
    final texts = app.texts;
    final (:indexes, :issues) = _index(texts, owners);
    issues
      ..addAll(_structureIssues(result, indexes, texts, owners))
      ..addAll(_importIssues(result, app, indexes));
    return issues;
  }

  /// The templates among [collection]'s bricks that have `{{` but no tag
  /// that mason renders, so mason copies them with the braces as they are.
  List<SmfIssue> _copiedTemplateIssues(Collection collection) => [
        for (final collected in collection.applyingOf<BrickContribution>())
          for (final MapEntry(key: path, value: text) in templateFilesOf(
            collected.contribution as BrickContribution,
          ).entries)
            if (text.contains('{{') && !masonTag.hasMatch(text))
              SmfIssue(
                'The template $path of ${collected.origin} has "{{" but no '
                'tag that mason renders, one without ",", ";" or "=", so '
                'mason copies it with the braces as they are.',
                hint: 'Write a literal brace as {{__LEFT_CURLY_BRACKET__}}.',
                origin: collected.origin,
                path: path,
              ),
      ];

  /// The indexes of the Dart files among [files], and a problem for every
  /// file that does not parse.
  ({Map<String, DartFileIndex> indexes, List<SmfIssue> issues}) _index(
    Map<String, String> files,
    Map<String, ContributionOrigin> owners,
  ) {
    final issues = <SmfIssue>[];
    final indexes = <String, DartFileIndex>{};
    for (final MapEntry(key: path, value: text) in files.entries) {
      if (!path.endsWith('.dart')) continue;
      final (:index, :errors) = DartFileIndexer.parse(path, text);
      indexes[path] = index;
      for (final error in errors) {
        issues.add(
          SmfIssue(
            '$path does not parse: $error',
            path: path,
            origin: owners[path],
          ),
        );
      }
    }
    return (indexes: indexes, issues: issues);
  }

  List<SmfIssue> _structureIssues(
    ContractResult result,
    Map<String, DartFileIndex> indexes,
    Map<String, String> texts,
    Map<String, ContributionOrigin> owners,
  ) {
    final (:resolution, :collection) = _resolved(result);
    final request = StructuralRuleRequest(
      hook: hookRequest(
        registry: registry,
        resolution: resolution,
        collection: collection,
        context: context,
        choices: result.choices ?? const {},
      ),
      files: indexes,
      texts: texts,
      owners: owners,
      modules: [for (final module in resolution.modules) module.descriptor],
    );
    return [
      for (final role in resolution.presentRoles) ...[
        ...role.checkStructure(request),
        ...role.interface.checkSymbols(indexes),
      ],
    ];
  }

  ({Resolution resolution, Collection collection}) _resolved(
    ContractResult result,
  ) {
    final resolution = result.resolution;
    final collection = result.collection;
    if (resolution == null || collection == null) {
      throw ArgumentError.value(
        result,
        'result',
        'The case ${result.contractCase} did not resolve',
      );
    }
    return (resolution: resolution, collection: collection);
  }

  /// The problems of the imports of the Dart files of [app]; see
  /// [checkRendered].
  List<SmfIssue> _importIssues(
    ContractResult result,
    RenderedApp app,
    Map<String, DartFileIndex> indexes,
  ) {
    final (:resolution, :collection) = _resolved(result);
    final pubspec = result.validation?.pubspec;
    final localizations = _localizationsOf(app, pubspec);
    final check = _ImportCheck(
      registry: registry,
      resolution: resolution,
      collection: collection,
      app: app,
      appName: context.appName,
      pubspec: pubspec,
      localizations: localizations.outputs,
    );
    return [
      ...localizations.issues,
      ...check.overwrittenIssues(),
      for (final MapEntry(key: path, value: index) in indexes.entries)
        if (app.files[path] case final file?)
          ...check.issuesOf(path, file, index),
    ];
  }
}

/// A Dart file of an app whose imports [_ImportCheck] checks: its path, the
/// file, the packages it may use, and the imports that the pipeline added
/// to it, by URI and prefix: who needed each, and whether every fragment of
/// theirs that needs it is one that their render hook gave.
typedef _CheckedFile = ({
  String path,
  RenderedFile file,
  Set<String> packages,
  Map<String, Map<ContributionOrigin, bool>> added,
});

/// Who uses an import or export of a file: the contributors of the
/// fragments that need it, when the pipeline added it, or the owner of the
/// file, in the template of a brick or in a file that its render hook
/// generated. Those in `ofHook` use it only in what a render hook of theirs
/// gave: for its fragments alone, or in a file that it generated.
typedef _Users = ({
  Set<ContributionOrigin> users,
  bool byPipeline,
  bool inHookFile,
  Set<ContributionOrigin> ofHook,
});

/// The checks of the imports and exports of the Dart files of a rendered
/// app; see [ContractHarness.checkRendered].
final class _ImportCheck {
  _ImportCheck({
    required this.registry,
    required this.resolution,
    required Collection collection,
    required this.app,
    required this.appName,
    required MergedPubspec? pubspec,
    required Set<String> localizations,
  })  : dependencies = {appName, ...?pubspec?.dependencies.keys},
        devDependencies = {...?pubspec?.devDependencies.keys},
        dataContributors = _dataContributorsOf(collection),
        generated = {
          for (final output in localizations)
            output: 'flutter pub get, which generates the localizations of '
                'l10n.yaml,',
          for (final collected in collection.applyingOf<CodegenRequest>())
            for (final output
                in (collected.contribution as CodegenRequest).outputs)
              output: 'the code generation that ${collected.origin} asks for',
        },
        packageOwners = providerPackages(resolution, collection),
        contributed = _contributedPackagesOf(collection);

  final ModuleRegistry registry;
  final Resolution resolution;
  final RenderedApp app;
  final String appName;

  /// The packages that the code of the app itself may use; tests and tools
  /// may use its [devDependencies] too, as depend_on_referenced_packages
  /// has it.
  final Set<String> dependencies;

  final Set<String> devDependencies;

  /// The owners of the files of those who contribute data to each role.
  final Map<Role, Set<ContributionOrigin>> dataContributors;

  /// The files of the app that code generation or Flutter generate, each
  /// with who writes it, as the subject of a sentence.
  final Map<String, String> generated;

  /// The packages of the providers of roles in the app, each with the
  /// providers it belongs to; see [providerPackages].
  final Map<String, List<ResolvedModule>> packageOwners;

  /// The packages that each module of the app contributes, itself or in
  /// its variant, whether the contribution applies or not.
  final Map<ModuleId, Set<String>> contributed;

  static Map<ModuleId, Set<String>> _contributedPackagesOf(
    Collection collection,
  ) {
    final packages = <ModuleId, Set<String>>{};
    for (final collected in collection.all) {
      if ((collected.origin, collected.contribution)
          case (
            ModuleOrigin(:final module),
            PubspecDependency(:final package),
          )) {
        packages.putIfAbsent(module, () => {}).add(package);
      }
    }
    return packages;
  }

  /// Who contributes data to each role, as the owner of their files. The
  /// template and the providers of a role render the data that its hooks
  /// read; see [_rendersDataOf].
  static Map<Role, Set<ContributionOrigin>> _dataContributorsOf(
    Collection collection,
  ) {
    final contributors = <Role, Set<ContributionOrigin>>{};
    for (final data in collection.roleData) {
      if (data.origin case final origin?) {
        contributors.putIfAbsent(data.role, () => {}).add(ownerOf(origin));
      }
    }
    return contributors;
  }

  /// The files of the app, of a brick or of a render hook, at a path where
  /// code generation or Flutter write a file once the app is rendered, so
  /// that what was rendered there is lost or stops the generation. The case
  /// does not matter, as on the file systems of macOS and Windows.
  List<SmfIssue> overwrittenIssues() {
    final outputs = {
      for (final output in generated.keys) output.toLowerCase(): output,
    };
    final issues = <SmfIssue>[];
    for (final file in app.files.values) {
      final output = outputs[file.path.toLowerCase()];
      if (output == null) continue;
      final who = file.fromHook ? 'A render hook' : 'A brick';
      final written = output == file.path
          ? 'that file'
          : '$output, the same file where case does not matter,';
      issues.add(
        SmfIssue(
          '$who of ${file.owner} generates ${file.path}, but '
          '${generated[output]} writes $written once the app is rendered.',
          origin: file.owner,
          path: file.path,
        ),
      );
    }
    return issues;
  }

  /// The problems of the imports and exports of [file], the Dart file at
  /// [path] with [index].
  List<SmfIssue> issuesOf(String path, RenderedFile file, DartFileIndex index) {
    final added = <String, Map<ContributionOrigin, bool>>{};
    for (final import in file.addedImports) {
      // A fragment of a contribution that needs the import too makes it one
      // that the contributor needs whatever its render hook gives.
      added
          .putIfAbsent(
            '${import.import.uri} as ${import.import.prefix}',
            () => {},
          )
          .update(
            import.contributor,
            (ofHook) => ofHook && import.fromHook,
            ifAbsent: () => import.fromHook,
          );
    }
    final public = path.startsWith('lib/') || path.startsWith('bin/');
    final checked = (
      path: path,
      file: file,
      packages: public ? dependencies : {...dependencies, ...devDependencies},
      added: added,
    );
    return [
      for (final import in index.imports)
        ..._directiveIssues(checked, 'imports', import),
      for (final export in index.exports)
        ..._directiveIssues(checked, 'exports', export),
    ];
  }

  /// The problems of [directive], which [verb] a library in [checked].
  List<SmfIssue> _directiveIssues(
    _CheckedFile checked,
    String verb,
    IndexedImport directive,
  ) {
    final (:path, file: _, packages: _, added: _) = checked;
    final uri = directive.uri;
    // Only the files of the app and packages have rules: a library of the
    // SDK, such as dart:async, is always there.
    if (uri.contains(':') && !uri.startsWith('package:')) return const [];
    final users = _usersOf(checked, verb, directive);
    final target = _appPathOf(uri, path, appName);
    if (target == null) return _libraryIssues(checked, verb, uri, users);
    if (generated.containsKey(target)) return const [];
    if (!app.files.containsKey(target)) {
      return [
        for (final who in users.users)
          SmfIssue(
            '$path $verb $uri ${_how(who, users)}, but the app has no '
            '$target.',
            origin: who,
            path: path,
          ),
      ];
    }
    final issues = <SmfIssue>[];
    for (final who in users.users) {
      if (_mayImport(who, target)) continue;
      // What a render hook gave may follow the data that the hook read.
      final ofData = _rendersDataOf(who, target);
      if (ofData && users.ofHook.contains(who)) continue;
      issues.add(
        SmfIssue(
          '$path $verb $target ${_how(who, users)}, but that file is of '
          '${app.files[target]!.owner}, which $who neither depends on '
          'nor knows through a role.',
          hint: ofData
              ? 'The owner of that file gives data to a role that $who '
                  'renders. Code may use the file only where a render hook '
                  'of $who gives the import with the code that needs it: as '
                  'an import of a fragment of the hook, for a variable or '
                  'for a socket, or in a file that the hook generates. Of '
                  'any other import, the harness cannot tell that it '
                  'follows the data.'
              : null,
          origin: who,
          path: path,
        ),
      );
    }
    return issues;
  }

  /// Who uses [directive] of [checked], as [verb] says: the contributors of
  /// the fragments that need it, if the pipeline added it, or else the
  /// owner of the file.
  _Users _usersOf(_CheckedFile checked, String verb, IndexedImport directive) {
    final uri = _packageUriOf(directive.uri, checked.path, appName);
    final contributors = checked.added['$uri as ${directive.prefix}'];
    if (verb == 'imports' && contributors != null) {
      return (
        users: contributors.keys.toSet(),
        byPipeline: true,
        inHookFile: false,
        ofHook: {
          for (final MapEntry(key: who, value: ofHook) in contributors.entries)
            if (ofHook) who,
        },
      );
    }
    final owner = checked.file.owner;
    return (
      users: {owner},
      byPipeline: false,
      inHookFile: checked.file.fromHook,
      ofHook: {if (checked.file.fromHook) owner},
    );
  }

  /// How [who], one of [users], uses a library: for a fragment, in a
  /// template, or in a file that its render hook generated.
  static String _how(ContributionOrigin who, _Users users) {
    if (users.byPipeline) return 'for a fragment of $who';
    return users.inHookFile
        ? 'in a file of the render hook of $who'
        : 'in the template of $who';
  }

  /// The problems of [uri], the `package:` URI of a library outside the app
  /// that [checked] uses as [verb] says, for its [users]: the file may not
  /// use its package, or a module uses the package of a provider of a role
  /// without contributing it, as the pipeline would check the contribution.
  List<SmfIssue> _libraryIssues(
    _CheckedFile checked,
    String verb,
    String uri,
    _Users users,
  ) {
    final package = uri.substring('package:'.length).split('/').first;
    final issues = [..._packageIssues(checked, verb, uri, package, users)];
    final owners = packageOwners[package];
    if (owners == null) return issues;
    for (final who in users.users) {
      if (ownerOf(who) case ModuleOrigin(:final module)
          when _takesWithout(who, users, package)) {
        issues.add(
          SmfIssue(
            '${checked.path} $verb $uri ${_how(who, users)}, but $module '
            'does not contribute $package, a package of '
            '${packageOwnersText(owners)}.',
            hint: 'A module contributes the packages that its code uses, and '
                'the package of a provider of a role with the constraint any: '
                'in its variant for the provider, or for a provider that '
                'depends on it, or in itself when it depends on the provider.',
            origin: who,
            path: checked.path,
          ),
        );
      }
    }
    return issues;
  }

  /// Whether [who], one of [users], uses [package], the package of a
  /// provider of a role, without contributing it. An owner of the package
  /// contributes it too. A provider of a role renders the data that other
  /// modules give the role, so it may use the package for a fragment, or in
  /// a file that its render hook generates, when one of them contributes
  /// it, as it may import their files.
  bool _takesWithout(ContributionOrigin who, _Users users, String package) {
    final user = ownerOf(who);
    if (user is! ModuleOrigin ||
        (contributed[user.module]?.contains(package) ?? false)) {
      return false;
    }
    // A template of the module renders no data of a role.
    if (!users.byPipeline && !users.inHookFile) return true;
    for (final role in resolution.presentRoles) {
      if (!resolution
          .providersOf(role)
          .any((module) => module.origin == user)) {
        continue;
      }
      for (final contributor in dataContributors[role] ?? const {}) {
        if (contributor case ModuleOrigin(:final module)
            when contributed[module]?.contains(package) ?? false) {
          return false;
        }
      }
    }
    return true;
  }

  /// The problems of [uri], a library of [package] that [checked] uses as
  /// [verb] says, for each of its [users], when the file may not use the
  /// package.
  List<SmfIssue> _packageIssues(
    _CheckedFile checked,
    String verb,
    String uri,
    String package,
    _Users users,
  ) {
    final (:path, file: _, :packages, added: _) = checked;
    if (packages.contains(package)) return const [];
    final problem = devDependencies.contains(package)
        ? 'but $package is only a dev dependency of the app.'
        : 'but the app does not depend on $package.';
    return [
      for (final who in users.users)
        SmfIssue(
          '$path $verb $uri ${_how(who, users)}, $problem',
          origin: who,
          path: path,
        ),
    ];
  }

  /// Whether [who] may use the file of the app at [target] wherever its
  /// code is: in the template of a brick too, which is the same in every
  /// app.
  bool _mayImport(ContributionOrigin who, String target) {
    final owner = ownerOf(app.files[target]!.owner);
    final user = ownerOf(who);
    if (owner == user) return true;
    // A module knows only the modules it depends on directly.
    if ((user, owner)
        case (ModuleOrigin(:final module), ModuleOrigin(module: final other))
        when resolution.module(module)?.descriptor.dependsOn.contains(other) ??
            false) {
      return true;
    }
    final roles = rolesOf(who, registry, resolution).access;
    for (final role in roles) {
      if (owner == RoleTemplateOrigin(role) ||
          role.interface.files.contains(target) ||
          role.interface.symbols.any((symbol) => symbol.path == target)) {
        return true;
      }
    }
    return false;
  }

  /// Whether [who] is the template or a provider of a role whose hooks
  /// read data of the owner of the file of the app at [target]: data that
  /// the owner gave the role, or a role that it requires or uses, as the
  /// layout role reads the destinations of the router role.
  ///
  /// What a render hook of [who] gives may then import the file, since the
  /// hook wrote the code from that data: a fragment of the hook, whose
  /// imports the pipeline adds, and a file that the hook generates.
  bool _rendersDataOf(ContributionOrigin who, String target) {
    final owner = ownerOf(app.files[target]!.owner);
    final user = ownerOf(who);
    for (final role in resolution.presentRoles) {
      final renders = user == RoleTemplateOrigin(role) ||
          resolution.providersOf(role).any((module) => module.origin == user);
      if (!renders) continue;
      for (final read in {role, ...role.visibleRoles}) {
        if (dataContributors[read]?.contains(owner) ?? false) return true;
      }
    }
    return false;
  }
}

/// The files of the app that Flutter generates when `flutter pub get` runs
/// after rendering, and the problems of `l10n.yaml` that make it fail.
///
/// With `generate: true` in [pubspec], Flutter generates the localizations
/// that `l10n.yaml` describes, in `output-dir`, or else in `arb-dir`, which
/// is `lib/l10n` unless set. As Flutter 3.44 reads the file, an empty one
/// and an option without a value take the defaults, and YAML that does not
/// parse, a file that is not a map of options, and an option with a value
/// of another type than Flutter reads it as fail (see [_l10nOptionProblems]);
/// the outputs then are those of the defaults, so that the problem of
/// `l10n.yaml` is the only one.
({Set<String> outputs, List<SmfIssue> issues}) _localizationsOf(
  RenderedApp app,
  MergedPubspec? pubspec,
) {
  final l10n = app.files['l10n.yaml'];
  if (!(pubspec?.generate ?? false) || l10n == null) {
    return (outputs: const {}, issues: const []);
  }
  final issues = <SmfIssue>[];
  void fails(String problem, [String? detail]) => issues.add(
        SmfIssue(
          '$problem, so flutter pub get fails to generate the '
          'localizations${detail == null ? '.' : ': $detail'}',
          origin: l10n.owner,
          path: 'l10n.yaml',
        ),
      );
  final options = _l10nOptions(l10n.text, fails);
  _l10nOptionProblems(options).forEach(fails);
  String? read(String key) => switch (options[key]) {
        final String value => value,
        _ => null,
      };
  final directory =
      _cleanPath(read('output-dir') ?? read('arb-dir') ?? 'lib/l10n');
  final file = read('output-localization-file') ?? 'app_localizations.dart';
  return (outputs: {'$directory/$file'}, issues: issues);
}

/// The options of `l10n.yaml` that Flutter 3.44 reads as text.
const _l10nTextOptions = [
  'arb-dir',
  'output-dir',
  'template-arb-file',
  'output-localization-file',
  'untranslated-messages-file',
  'output-class',
  'header',
  'header-file',
];

/// The options of `l10n.yaml` that Flutter 3.44 reads as true or false.
const _l10nFlagOptions = [
  'synthetic-package',
  'use-deferred-loading',
  'required-resource-attributes',
  'nullable-getter',
  'format',
  'use-escaping',
  'suppress-warnings',
  'relax-syntax',
  'use-named-parameters',
];

/// Why Flutter 3.44 fails on the options of `l10n.yaml`, [options]: one
/// that it reads as text or as true or false with a value of another type,
/// `preferred-supported-locales` that is neither text nor a list, and
/// `synthetic-package: true`, a feature that Flutter removed. It ignores
/// other options.
Iterable<String> _l10nOptionProblems(YamlMap options) sync* {
  for (final option in _l10nTextOptions) {
    if (options[option] case final value? when value is! String) {
      yield 'The option $option in l10n.yaml is not text';
    }
  }
  for (final option in _l10nFlagOptions) {
    if (options[option] case final value? when value is! bool) {
      yield 'The option $option in l10n.yaml is not true or false';
    }
  }
  if (options['preferred-supported-locales'] case final value?
      when value is! String && value is! List<Object?>) {
    yield 'The option preferred-supported-locales in l10n.yaml is neither '
        'text nor a list';
  }
  if (options['synthetic-package'] == true) {
    yield 'l10n.yaml turns on synthetic-package, which Flutter removed';
  }
}

/// The options of `l10n.yaml`, [text], as Flutter reads them: none for an
/// empty file. [fails] gets why Flutter fails on YAML that does not parse
/// or on a file that is not a map of options, which then has none either.
YamlMap _l10nOptions(
  String text,
  void Function(String problem, [String? detail]) fails,
) {
  if (text.trim().isEmpty) return YamlMap();
  try {
    if (loadYamlNode(text) case final YamlMap map) return map;
    fails('l10n.yaml is not a map of options');
  } on YamlException catch (error) {
    fails('l10n.yaml is not valid YAML', error.message);
  }
  return YamlMap();
}

/// [path] without empty segments and `.`, as in `lib/generated` for
/// `./lib/generated/`.
String _cleanPath(String path) => [
      for (final segment in path.split('/'))
        if (segment.isNotEmpty && segment != '.') segment,
    ].join('/');

/// The path relative to the root of the app of the file of the app that
/// [uri] imports in the file at [from], or `null` for a library outside the
/// app.
String? _appPathOf(String uri, String from, String appName) {
  if (uri.startsWith('package:$appName/')) {
    return 'lib/${uri.substring('package:$appName/'.length)}';
  }
  if (uri.contains(':')) return null;
  return Uri.parse(from).resolve(uri).path;
}

/// [uri] as a `package:` URI when it imports a file of the app in `lib/`
/// relatively from [from], which is in `lib/` too; otherwise [uri].
String _packageUriOf(String uri, String from, String appName) {
  final path = _appPathOf(uri, from, appName);
  if (path == null || !path.startsWith('lib/')) return uri;
  return 'package:$appName/${path.substring('lib/'.length)}';
}

/// The subsets of [roles], the largest first.
List<List<Role>> _subsets(List<Role> roles) => [
      for (var size = roles.length; size >= 0; size--)
        for (var mask = 0; mask < 1 << roles.length; mask++)
          if (_bitCount(mask) == size)
            [
              for (var i = 0; i < roles.length; i++)
                if (mask & (1 << i) != 0) roles[i],
            ],
    ];

int _bitCount(int mask) {
  var count = 0;
  for (var rest = mask; rest != 0; rest &= rest - 1) {
    count++;
  }
  return count;
}

final SmfHost _silentHost = SmfHost(
  prompter: const _NoPrompter(),
  processRunner: const _NoProcessRunner(),
  logger: const _SilentLogger(),
  fileSystem: MemoryFileSystem(),
  environmentVariables: const {},
  operatingSystem: HostOperatingSystem.other,
  hasTerminal: false,
);

/// A host like [_silentHost] whose user answers with [prompter].
SmfHost _answeringHost(SmfPrompter prompter) => SmfHost(
      prompter: prompter,
      processRunner: const _NoProcessRunner(),
      logger: const _SilentLogger(),
      fileSystem: MemoryFileSystem(),
      environmentVariables: const {},
      operatingSystem: HostOperatingSystem.other,
      hasTerminal: true,
    );

/// Answers every question as a user who presses Enter does: with its
/// default, or with its first choice if it has no default.
final class _EnterPrompter implements SmfPrompter {
  /// Whether a question was asked since this was last set to `false`.
  bool asked = false;

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async {
    asked = true;
    return defaultValue;
  }

  @override
  Future<String> input(String message, {String? defaultValue}) async {
    asked = true;
    return defaultValue ?? '';
  }

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) async {
    asked = true;
    return defaultValue ?? choices.first;
  }

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) async {
    asked = true;
    return defaultValues;
  }
}

final class _NoPrompter implements SmfPrompter {
  const _NoPrompter();

  Never _fail(String message) =>
      throw StateError('The contract harness cannot ask: $message');

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) =>
      _fail(message);

  @override
  Future<String> input(String message, {String? defaultValue}) =>
      _fail(message);

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) =>
      _fail(message);

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) =>
      _fail(message);
}

final class _NoProcessRunner implements SmfProcessRunner {
  const _NoProcessRunner();

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
    Duration? timeout,
  }) =>
      throw StateError('The contract harness runs no commands: $executable');

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) =>
      throw StateError('The contract harness runs no commands: $executable');
}

final class _SilentLogger implements SmfLogger {
  const _SilentLogger();

  @override
  void detail(String message) {}

  @override
  void error(String message) {}

  @override
  void info(String message) {}

  @override
  SmfProgress progress(String message) => const _SilentProgress();

  @override
  void success(String message) {}

  @override
  void warn(String message) {}
}

final class _SilentProgress implements SmfProgress {
  const _SilentProgress();

  @override
  void complete([String? message]) {}

  @override
  void fail([String? message]) {}

  @override
  void update(String message) {}
}
