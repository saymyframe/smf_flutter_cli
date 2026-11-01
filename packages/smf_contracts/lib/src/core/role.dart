import 'package:meta/meta.dart';
import 'package:smf_contracts/core.dart';

part 'role/role_hooks.dart';
part 'role/role_provider.dart';
part 'role/role_template.dart';
part 'role/rules.dart';

/// How many providers of a role an app can have.
enum RoleCardinality {
  /// Exactly one, such as the app entry.
  exactlyOne,

  /// None or one, such as the router or the DI container.
  atMostOne,

  /// Any number, such as analytics services.
  many;

  /// Whether an app may have no provider of the role.
  bool get allowsNone => this != exactlyOne;

  /// Whether an app may have more than one provider of the role.
  bool get allowsMany => this == many;
}

/// The data type of a role that takes no data from modules.
///
/// It has no instances, so no [RoleData] can be created for such a role.
abstract final class NoDsl {}

/// A replaceable part of an app, such as the router, the DI container or
/// the app entry, described by what it offers to the rest of the app.
///
/// A role is defined once, in `smf_contracts` or in a third-party package,
/// as a constant instance of a subclass. Modules then refer to it:
/// - a module that implements it lists a [RoleProvider] for it in
///   [ModuleDescriptor.providers];
/// - a module that needs it lists it in [ModuleDescriptor.requires];
/// - a module that can work with or without it lists it in
///   [ModuleDescriptor.uses].
///
/// A module never learns which module provides a role it requires or uses.
/// It meets the role only through:
/// - the role's sockets (see [sockets]), where it puts code;
/// - the role's symbols, the Dart names that the role's template generates
///   or that every provider must generate (see [interface]);
/// - the role's data type [D], in which it describes what it needs, such as
///   routes for a router;
/// - the presence flag `has_<id>` of a role it uses (see [presenceFlag]).
///
/// The pipeline knows no role: everything specific to a role, from its
/// command line options to its checks, is here. Roles compare by identity,
/// so each role must have exactly one instance.
abstract base class Role<D extends Object> {
  /// Allows subclasses to have constant constructors.
  const Role();

  /// A unique id of the role in lower snake_case, such as `router`.
  ///
  /// It names the presence flag, the role's template in diagnostics
  /// (`role:<id>`) and the tags of the role's sockets. It must differ from
  /// the ids of other roles and of all modules.
  String get id;

  /// What the role does, as a short noun phrase such as `Router`.
  ///
  /// Prompts show it as it is, as in `Router: which module provides it?`,
  /// and messages name the role by it (see [toString]).
  String get description;

  /// How many providers of the role an app can have.
  RoleCardinality get cardinality;

  /// Whether every module may use the role's sockets and symbols without
  /// declaring the role.
  ///
  /// Only a role that every app has and every module may take part in
  /// should be open, such as the app entry: any module may add start-up
  /// code. The pipeline applies it without knowing the role.
  bool get openToAllModules => false;

  /// Roles that must be present whenever this role is present.
  ///
  /// The hooks of this role and its providers may read their data (see
  /// [dataIn]). Every provider of this role requires them too.
  Set<Role> get requires => const {};

  /// Roles that this role works with when they are present.
  ///
  /// The hooks of this role and its providers may read their data (see
  /// [dataIn]) and check their presence (see [RoleHookInput.has]). Every
  /// provider of this role uses them too.
  Set<Role> get uses => const {};

  /// The sockets of the role.
  ///
  /// Their tags are in the role's template files or in the files of its
  /// provider; a socket whose contributions carry imports has its tag in
  /// exactly one file (see [SocketKind.carriesImports]).
  List<SocketRef> get sockets => const [];

  /// The socket families of the role, such as the annotations of every
  /// screen of the router.
  ///
  /// The tags of their members may be in the files of the modules whose
  /// data creates them; the pipeline recognizes them with
  /// [SocketFamily.memberOfTag].
  List<SocketFamily<Object?, SocketKind>> get socketFamilies => const [];

  /// The files the role's template generates, and the files and the symbols
  /// every provider must generate.
  RoleInterface get interface => const RoleInterface();

  /// Command line options of the role, such as `--start` of the router.
  ///
  /// The [RoleTemplate.choose] hook reads their values.
  List<RoleOption> get options => const [];

  /// The code the role itself contributes, independent of its provider, or
  /// `null` if it has none.
  RoleTemplate<D>? get template => null;

  /// Checks of the data of modules that provide, require or use the role,
  /// run during validation with [checkModule].
  List<ModuleRule<D>> get moduleRules => const [];

  /// Checks of the generated code, run by the contract test harness with
  /// [checkStructure].
  List<StructuralRule<D>> get structuralRules => const [];

  /// The name of the brick variable that is `true` when the role is
  /// present: `has_<id>`.
  ///
  /// The pipeline sets it in the bricks of every module and role template
  /// that provides, requires or uses the role. Template code that refers to
  /// a symbol of a used role must be inside `{{#has_<id>}}`, or be the
  /// code of a variable for an app with the role (see [RoleVar]).
  @nonVirtual
  String get presenceFlag => 'has_$id';

  /// The roles whose data and presence the hooks of this role may read:
  /// [requires] and [uses].
  @nonVirtual
  Set<Role> get visibleRoles => {...requires, ...uses};

  /// Whether [value] can be data of this role, that is, a [D].
  @nonVirtual
  bool accepts(Object? value) => value is D;

  /// Creates [value] as data for this role; see [RoleData].
  @nonVirtual
  RoleData<D> data(
    D value, {
    Set<Role> when = const {},
    Set<ChoiceCondition> whenChosen = const {},
  }) =>
      RoleData<D>(this, value, when: when, whenChosen: whenChosen);

  /// Returns the data of this role in [input], the input of a hook of
  /// another role.
  ///
  /// A hook may read the data of roles its role requires or uses, as the
  /// layout role reads the destinations of the router. Throws an
  /// [ArgumentError] for any other role.
  @nonVirtual
  List<RoleData<D>> dataIn(RoleHookInput<Object> input) {
    if (identical(input.role, this)) {
      return List.unmodifiable(input.data.map(_typed));
    }
    final data = input._visibleData[this];
    if (data == null) {
      throw ArgumentError.value(
        this,
        'role',
        'The ${input.role} neither requires nor uses the $this, so its hooks '
            'cannot read its data',
      );
    }
    return List.unmodifiable(data.map(_typed));
  }

  /// Builds the input of this role's hooks and its providers' hooks from
  /// the pipeline's [request].
  ///
  /// The input holds the data of this role, typed as [D], and only as much
  /// of the rest of the app as the role may see: the data and presence of
  /// its [visibleRoles], and for a role that is [openToAllModules] the
  /// steps by hand of the app (see [RoleHookInput.manualSetup]). Data that
  /// does not apply, because its role or a
  /// role in its [Contribution.when] is absent, is left out. The conditions
  /// of data on what roles chose ([Contribution.whenChosen]) are the
  /// pipeline's to decide: once the roles have chosen, it leaves the data
  /// whose conditions do not hold out of [request], and before, as in
  /// validation, it takes all of it.
  ///
  /// This is the only place where data is cast to [D], and data of another
  /// type fails here with an [ArgumentError] that names the contributor.
  @nonVirtual
  RoleHookInput<D> hookInput(RoleHookRequest request) {
    final visible = visibleRoles;
    final applies = _appliesIn(request.presentRoles);
    return RoleHookInput<D>._(
      role: this,
      data: List.unmodifiable([
        for (final data in request.data)
          if (identical(data.role, this) && applies(data)) _typed(data),
      ]),
      present: {
        for (final role in request.presentRoles)
          if (visible.contains(role)) role,
      },
      visibleData: {
        for (final role in visible)
          role: List<RoleData<Object>>.unmodifiable(
            request.data.where(
              (data) => identical(data.role, role) && applies(data),
            ),
          ),
      },
      choice: request.choices[this],
      context: request.context,
      manualSetup: openToAllModules ? request.manualSetup : ManualSetup.none,
    );
  }

  /// Runs the [structuralRules] over the app in [request], checks that each
  /// provider among its modules generates the
  /// [RoleInterface.providerFiles] of the role, and returns the problems
  /// found.
  ///
  /// Each rule gets the role's data as [hookInput] builds it.
  @nonVirtual
  List<SmfIssue> checkStructure(StructuralRuleRequest request) {
    final input = StructuralRuleInput<D>._(
      roleInput: hookInput(request.hook),
      hook: request.hook,
      files: Map.unmodifiable(request.files),
      texts: Map.unmodifiable(request.texts),
      owners: Map.unmodifiable(request.owners),
      modules: List.unmodifiable(request.modules),
    );
    return [
      for (final rule in structuralRules) ...rule.check(input),
      for (final module in request.modules)
        if (module.provides.contains(this))
          for (final path in interface.providerFiles)
            if (_providerFileIssue(path, module.id, request.owners[path])
                case final issue?)
              issue,
    ];
  }

  /// The problem of the file at [path] of the [RoleInterface.providerFiles]
  /// of the role, which [owner] generated, for its provider [provider], or
  /// `null` if [owner] is that module, whichever of its variants.
  SmfIssue? _providerFileIssue(
    String path,
    ModuleId provider,
    ContributionOrigin? owner,
  ) {
    if (owner case ModuleOrigin(:final module) when module == provider) {
      return null;
    }
    final found = owner == null ? 'the app has no such file' : '$owner has it';
    return SmfIssue(
      'The module $provider provides the $this, whose every provider '
      'generates $path, but $found.',
      hint: 'The file is the part of the provider that the rest of the app '
          'relies on, so it comes with the provider and leaves with it. '
          'Generate it from a brick or a render hook of the module.',
      origin: ModuleOrigin(provider),
      path: path,
    );
  }

  /// Runs the [moduleRules] for the module in [request] and returns the
  /// problems found.
  ///
  /// Each rule gets the role's data as [hookInput] builds it, the part of
  /// it the module contributed, and the module's contributions that apply.
  @nonVirtual
  List<SmfIssue> checkModule(ModuleRuleRequest request) {
    final roleInput = hookInput(request.hook);
    final applies = _appliesIn(request.hook.presentRoles);
    final id = request.module.id;
    final input = ModuleRuleInput<D>._(
      roleInput: roleInput,
      module: request.module,
      data: List.unmodifiable([
        for (final data in roleInput.data)
          if (data.origin case ModuleOrigin(:final module) when module == id)
            data,
      ]),
      contributions: List.unmodifiable([
        for (final contribution in request.contributions)
          if (contribution.when.every(applies.isPresent) &&
              switch (contribution) {
                final RoleData<Object> data => applies(data),
                ManualStep(id: ManualStepId(:final role?)) =>
                  applies.isPresent(role),
                _ => true,
              })
            contribution,
      ]),
    );
    return [for (final rule in moduleRules) ...rule.check(input)];
  }

  /// Builds the input of [RoleTemplate.choose] from the pipeline's
  /// [request]; see [hookInput].
  ///
  /// The pipeline puts into [request] only the data of this role whose
  /// conditions on what other roles chose hold (see
  /// [Contribution.whenChosen]): those roles choose first.
  @nonVirtual
  RoleChoiceContext<D> choiceContext(RoleChoiceRequest request) {
    final applies = _appliesIn(request.presentRoles);
    return RoleChoiceContext<D>._(
      role: this,
      data: List.unmodifiable([
        for (final data in request.data)
          if (identical(data.role, this) && applies(data)) _typed(data),
      ]),
      present: request.presentRoles,
      optionValues: {
        for (final option in options)
          option.name: request.optionValues[option.name],
      },
      environment: request.environment,
      context: request.context,
    );
  }

  _Applies _appliesIn(Set<Role> presentRoles) => _Applies(this, presentRoles);

  RoleData<D> _typed(RoleData<Object> data) {
    if (data is RoleData<D>) return data;
    final value = data.value;
    if (value is! D) {
      throw ArgumentError.value(
        value,
        'data',
        '${data.origin ?? 'A module'} contributed a ${value.runtimeType} to '
            'the $this, which takes $D',
      );
    }
    final typed = RoleData<D>(
      this,
      value,
      when: data.when,
      whenChosen: data.whenChosen,
    );
    final origin = data.origin;
    return origin == null ? typed : typed.withOrigin(origin);
  }

  /// The role as messages name it: its [description] followed by `role`,
  /// such as `router role` for `Router`.
  ///
  /// The description starts in lower case, unless it starts with an
  /// acronym, as `DI role` does for `DI`.
  @override
  String toString() {
    final name = description;
    final acronym = name.length > 1 && name[1] != name[1].toLowerCase();
    return name.isEmpty || acronym
        ? '$name role'
        : '${name[0].toLowerCase()}${name.substring(1)} role';
  }
}

/// Whether data applies in an app: its role and the roles in its
/// [Contribution.when] are present. The role whose hook runs is present.
final class _Applies {
  _Applies(this._role, this._present);

  final Role _role;
  final Set<Role> _present;

  bool isPresent(Role role) =>
      identical(role, _role) || _present.contains(role);

  bool call(RoleData<Object> data) =>
      isPresent(data.role) && data.when.every(isPresent);
}

/// A command line option of a role, such as `--start` of the router.
final class RoleOption {
  /// Creates the option `--<name>`.
  const RoleOption({
    required this.name,
    required this.help,
    this.valueHelp,
    this.allowed,
  }) : isMode = false;

  /// Creates the mode option `--<name>`, which takes one of [values].
  ///
  /// With it a role states that each value makes another app, as an app
  /// that every user signs in to is another app than one that lets a guest
  /// in:
  /// - The code of the app depends on the value. The template of the role
  ///   and its providers read the choice in their render hooks (see
  ///   [RoleHookInput.choice]). A module that is no provider has no hook
  ///   and its contributions are the same for every value, so the template
  ///   writes the value into a file of the role as a constant, and the code
  ///   of such a module branches on it when the app runs.
  /// - The first of [values] is the default, the value of an app that got
  ///   none. [RoleTemplate.choose] chooses the value that the option gives,
  ///   and the first one when the option is not given: in a run without a
  ///   terminal, where it neither fails nor asks for the lack of the
  ///   option, and at its question, where a user who presses Enter gets it
  ///   too. So no run needs the option, and a script written before the
  ///   role had it generates the same app.
  /// - [RoleTemplate.optionsOf] gives the option with its value for every
  ///   choice, also for one that the template made without asking.
  /// - The choices of the role compare by value, and with the same options
  ///   the role makes the same choice in a terminal and in a run without
  ///   one, so that what a test renders is what `smf create` generates.
  /// - Every value gets apps in the tests. The contract test harness
  ///   builds an app of each provider of the role for each value after the
  ///   first, besides the apps with the first. It makes the choices of each
  ///   such app in a terminal and without one, and reports a template that
  ///   does not hold to the statements above.
  ///
  /// A mode has at least two [values], each of lower-case letters and
  /// digits with single hyphens between them, as they become part of the
  /// names of those apps.
  const RoleOption.mode({
    required this.name,
    required this.help,
    required List<String> values,
  })  : allowed = values,
        valueHelp = null,
        isMode = true;

  /// The name of the option without dashes, in lower kebab-case, such as
  /// `start`.
  ///
  /// It must differ from the options of the pipeline and of other roles.
  final String name;

  /// What the option does, for `--help`.
  final String help;

  /// The placeholder of the value in `--help`, such as `path`.
  final String? valueHelp;

  /// The allowed values, or `null` to allow any; the values of a mode
  /// option, the default first.
  final List<String>? allowed;

  /// Whether the option is a mode of the app, whose values each get apps in
  /// the tests; see [RoleOption.mode].
  final bool isMode;
}

/// What a role guarantees to the rest of the app: the files its template
/// generates, the files its providers generate and the symbols that other
/// code uses.
final class RoleInterface {
  /// Creates the interface of a role.
  const RoleInterface({
    this.files = const [],
    this.providerFiles = const [],
    this.symbols = const [],
  });

  /// The files the role's template generates, relative to the project root.
  final List<String> files;

  /// The files that every provider of the role must generate, whatever is in
  /// them, relative to the project root, such as an image that the README of
  /// the app tells its developer to replace.
  ///
  /// They are for what [symbols] cannot name, a file that is no Dart code.
  /// Such a file has one owner, so a role with them has at most one provider
  /// in an app. [Role.checkStructure] checks that the provider generates
  /// each, and so a note of the role may name them whichever module provides
  /// the role.
  final List<String> providerFiles;

  /// The symbols that other code uses: those every provider of the role
  /// must generate, and those of the files of the role's template.
  ///
  /// A symbol with conditions on what roles chose
  /// ([RequiredSymbol.whenChosen]) has a file of its own, which only the
  /// apps where the conditions hold have.
  final List<RequiredSymbol> symbols;

  /// Checks that [files], the indexes of the Dart files of the app of
  /// [hook] by path, declare every symbol that the app needs, and returns
  /// the problems found.
  ///
  /// The app needs a symbol when every condition of its
  /// [RequiredSymbol.whenChosen] holds with the roles of [hook] and their
  /// choices, and it is checked with [RequiredSymbol.checkIn]. In an app
  /// where a condition does not hold, the app must not have the file of
  /// the symbol: what only some apps need is in no other app.
  List<SmfIssue> checkSymbols(
    Map<String, DartFileIndex> files,
    RoleHookRequest hook,
  ) =>
      [for (final symbol in symbols) ..._symbolIssues(symbol, files, hook)];

  /// The problems of [symbol] in [files], the Dart files of the app of
  /// [hook]; see [checkSymbols].
  static List<SmfIssue> _symbolIssues(
    RequiredSymbol symbol,
    Map<String, DartFileIndex> files,
    RoleHookRequest hook,
  ) {
    final failing = [
      for (final condition in symbol.whenChosen)
        if (!condition.holdsIn(hook)) condition.name,
    ];
    if (failing.isEmpty) return symbol.checkIn(files);
    final path = symbol.path;
    if (!files.containsKey(path)) return const [];
    return [
      SmfIssue(
        'The app has $path, the file of $symbol, which only an app where '
        '${failing.join(' and where ')} needs.',
        hint: 'Contribute the file under the conditions of the symbol, with '
            'whenChosen of its brick.',
        path: path,
      ),
    ];
  }
}
