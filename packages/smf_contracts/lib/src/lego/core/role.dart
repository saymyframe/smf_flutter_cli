import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

part 'role/role_hooks.dart';
part 'role/role_provider.dart';
part 'role/role_template.dart';

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

  /// What the role does, for prompts and diagnostics, such as `Routing`.
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
  /// Every socket has exactly one tag in the templates of the app: in the
  /// role's own template files, or in the files of its provider.
  List<SocketRef> get sockets => const [];

  /// The files the role's template generates and the symbols every provider
  /// must generate.
  RoleInterface get interface => const RoleInterface();

  /// Command line options of the role, such as `--start` of the router.
  ///
  /// The [RoleTemplate.choose] hook reads their values.
  List<RoleOption> get options => const [];

  /// The code the role itself contributes, independent of its provider, or
  /// `null` if it has none.
  RoleTemplate<D>? get template => null;

  /// Checks of the data of modules that provide, require or use the role,
  /// run during validation.
  List<ModuleRule> get moduleRules => const [];

  /// Checks of the generated code, run by the contract test harness.
  List<StructuralRule> get structuralRules => const [];

  /// The name of the brick variable that is `true` when the role is
  /// present: `has_<id>`.
  ///
  /// The pipeline sets it in the bricks of every module and role template
  /// that provides, requires or uses the role. Template code that refers to
  /// a symbol of a used role must be inside `{{#has_<id>}}`.
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
  RoleData<D> data(D value, {Set<Role> when = const {}}) =>
      RoleData<D>(this, value, when: when);

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
  /// its [visibleRoles]. This is the only place where data is cast to [D],
  /// and data of another type fails here with an [ArgumentError] that names
  /// the contributor.
  @nonVirtual
  RoleHookInput<D> hookInput(RoleHookRequest request) {
    final visible = visibleRoles;
    return RoleHookInput<D>._(
      role: this,
      data: List.unmodifiable([
        for (final data in request.data)
          if (identical(data.role, this)) _typed(data),
      ]),
      present: {
        for (final role in request.presentRoles)
          if (visible.contains(role)) role,
      },
      visibleData: {
        for (final role in visible)
          role: List<RoleData<Object>>.unmodifiable(
            request.data.where((data) => identical(data.role, role)),
          ),
      },
      choice: request.choices[this],
      context: request.context,
    );
  }

  /// Builds the input of [RoleTemplate.choose] from the pipeline's
  /// [request]; see [hookInput].
  @nonVirtual
  RoleChoiceContext<D> choiceContext(RoleChoiceRequest request) {
    return RoleChoiceContext<D>._(
      role: this,
      data: List.unmodifiable([
        for (final data in request.data)
          if (identical(data.role, this)) _typed(data),
      ]),
      optionValues: {
        for (final option in options)
          option.name: request.optionValues[option.name],
      },
      environment: request.environment,
      context: request.context,
    );
  }

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
    final typed = RoleData<D>(this, value, when: data.when);
    final origin = data.origin;
    return origin == null ? typed : typed.withOrigin(origin);
  }

  @override
  String toString() => 'role $id';
}

/// A command line option of a role, such as `--start` of the router.
final class RoleOption {
  /// Creates the option `--<name>`.
  const RoleOption({
    required this.name,
    required this.help,
    this.valueHelp,
    this.allowed,
  });

  /// The name of the option without dashes, in lower kebab-case, such as
  /// `start`.
  ///
  /// It must differ from the options of the pipeline and of other roles.
  final String name;

  /// What the option does, for `--help`.
  final String help;

  /// The placeholder of the value in `--help`, such as `path`.
  final String? valueHelp;

  /// The allowed values, or `null` to allow any.
  final List<String>? allowed;
}

/// What a role guarantees to the rest of the app: the files its template
/// generates and the symbols every provider must generate.
final class RoleInterface {
  /// Creates the interface of a role.
  const RoleInterface({this.files = const [], this.symbols = const []});

  /// The files the role's template generates, relative to the project root.
  final List<String> files;

  /// The symbols every provider of the role must generate.
  final List<RequiredSymbol> symbols;

  /// Checks that [files], the indexes of an app by path, declare every
  /// required symbol, and returns the problems found.
  List<SmfIssue> checkSymbols(Map<String, DartFileIndex> files) =>
      [for (final symbol in symbols) ...symbol.checkIn(files)];
}
