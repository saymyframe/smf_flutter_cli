import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

/// A module: a piece of an app that the user can select, such as a router,
/// a DI container or a feature.
///
/// A module describes itself with a [descriptor] and returns its
/// [contribute]ions: files, code for sockets, data for roles and pubspec
/// entries. It knows only the modules in its [ModuleDescriptor.dependsOn]
/// and the roles it declares; it never learns which other modules the user
/// selected.
abstract base class SmfModule {
  /// Allows subclasses to have constant constructors.
  const SmfModule();

  /// What the module is and how it relates to other modules and roles.
  ModuleDescriptor get descriptor;

  /// Returns the module's contributions to an app described by [context].
  ///
  /// It must not branch on anything but [context]: what depends on other
  /// roles goes into contributions with [Contribution.when], and what
  /// depends on the provider of a role goes into [Variants].
  List<Contribution> contribute(ModuleContext context) => const [];
}

/// What a module is and how it relates to other modules and roles.
@immutable
final class ModuleDescriptor {
  /// Creates the descriptor of the module [id].
  const ModuleDescriptor({
    required this.id,
    required this.description,
    required this.kind,
    this.dependsOn = const {},
    this.requires = const {},
    this.uses = const {},
    this.providers = const [],
    this.variants,
    this.sockets = const [],
    this.socketFamilies = const [],
  });

  /// The id of the module.
  final ModuleId id;

  /// What the module adds to the app, for prompts and diagnostics.
  final String description;

  /// What kind of module it is, which decides the rules it follows.
  final ModuleKind kind;

  /// The modules this module builds on, such as Firebase Analytics on
  /// Firebase Core.
  ///
  /// Refer to the id constants of their packages, which makes each of them
  /// a pub dependency as well. The pipeline adds them to the app, and this
  /// module may put code into their sockets. Prefer [requires] whenever a
  /// role describes what is needed.
  final Set<ModuleId> dependsOn;

  /// Roles the module needs, whichever module provides them.
  final Set<Role> requires;

  /// Roles the module works with when they are present.
  ///
  /// Contributions that refer to such a role set [Contribution.when], and
  /// template code refers to its symbols only inside `{{#has_<role>}}`.
  final Set<Role> uses;

  /// The roles the module provides, one provider object per role.
  final List<RoleProvider> providers;

  /// Alternative contributions of the module for different providers of a
  /// role, such as a feature with a BLoC and a Riverpod variant.
  final Variants? variants;

  /// Sockets of the module itself, for the modules that depend on it
  /// directly; see [SocketRef.module].
  final List<SocketRef> sockets;

  /// Socket families of the module itself; see [SocketFamily.module].
  final List<SocketFamily<Object?, SocketKind>> socketFamilies;

  /// The roles the module provides.
  Set<Role> get provides => {for (final provider in providers) provider.role};

  /// The roles the module requires, including those its [kind] implies, the
  /// role of its [variants], and those the roles it provides require.
  ///
  /// It goes one level deep: the roles a required role requires in turn are
  /// the pipeline's concern, not the module's, so the module gets no access
  /// to them.
  Set<Role> get effectiveRequires => {
        ...requires,
        ...kind.impliedRequires,
        if (variants != null) variants!.role,
        for (final role in provides) ...role.requires,
      }..removeAll(provides);

  /// The roles the module uses, including those the roles it provides use,
  /// except roles it requires or provides.
  Set<Role> get effectiveUses => {
        ...uses,
        for (final role in provides) ...role.uses,
      }
        ..removeAll(effectiveRequires)
        ..removeAll(provides);

  /// All roles of the module: those it provides, requires or uses.
  ///
  /// The module may use the sockets and symbols of these roles, and its
  /// bricks get their presence flags.
  Set<Role> get roles => {...provides, ...effectiveRequires, ...effectiveUses};
}

/// The contributions of a module's variant for one provider of a role.
typedef VariantContributions = List<Contribution> Function(
  ModuleContext context,
);

/// Alternative contributions of a module for different providers of
/// [role], such as a feature screen with a BLoC and a Riverpod variant.
///
/// The pipeline adds the contributions of the variant for the selected
/// provider to the module's own. A module with variants requires [role]. A
/// variant only adds contributions and never changes the descriptor.
///
/// Variants are keyed by the provider's id as a value, such as
/// `ModuleId('bloc')`, so the module does not depend on every provider's
/// package. A variant may import the packages of its provider. It adds them
/// to the pubspec with the constraint `any`, leaving the constraint to the
/// provider.
@immutable
final class Variants {
  /// Creates the variants of a module for the providers of [role].
  const Variants({required this.role, required this.byProvider});

  /// The role whose providers the variants are for.
  final Role role;

  /// The contributions for each supported provider, by provider id.
  ///
  /// For a selected provider without a variant, generation fails, or the
  /// module is dropped in lenient mode.
  final Map<ModuleId, VariantContributions> byProvider;
}

/// A kind of module and the rules modules of that kind follow, such as
/// "features live in `lib/features/<id>/`".
///
/// Kinds are data: the pipeline applies them without knowing any kind. The
/// kinds of the built-in modules are in `ModuleKinds` of
/// `package:smf_contracts/lego.dart`.
///
/// Paths are relative to the project root and may contain `<id>`, which
/// stands for the module id; directories may end with a slash.
@immutable
final class ModuleKind {
  /// Creates the kind [id].
  const ModuleKind({
    required this.id,
    required this.label,
    this.mustProvide = const {},
    this.impliedRequires = const {},
    this.fileRoots = const [],
    this.forbiddenFileRoots = const [],
    this.requiredData = const {},
    this.forbiddenData = const {},
    this.allowsVariants = true,
    this.compositionFile,
  });

  /// A unique id in lower snake_case, such as `feature`.
  final String id;

  /// The name of the kind in prompts, where the modules without a role are
  /// grouped by kind, such as `Features`.
  final String label;

  /// Roles every module of the kind must provide, each with a provider in
  /// [ModuleDescriptor.providers]; the pipeline checks it.
  ///
  /// Unlike [impliedRequires], these are not added to the module's roles,
  /// because providing a role takes a provider object.
  final Set<Role> mustProvide;

  /// Roles every module of the kind requires without listing them; they are
  /// added to [ModuleDescriptor.effectiveRequires].
  final Set<Role> impliedRequires;

  /// Directories every generated file of the module must be in, or empty to
  /// allow any, such as `lib/features/<id>/`.
  final List<String> fileRoots;

  /// Directories no generated file of the module may be in.
  final List<String> forbiddenFileRoots;

  /// Roles every module of the kind must contribute data to.
  final Set<Role> requiredData;

  /// Roles no module of the kind may contribute data to.
  final Set<Role> forbiddenData;

  /// Whether modules of the kind may have [Variants].
  final bool allowsVariants;

  /// The optional file where a module of the kind may obtain services from
  /// the app's service locator, such as
  /// `lib/features/<id>/<id>_composition.dart`, or `null` if the kind may
  /// not obtain services at all.
  final String? compositionFile;

  /// [fileRoots] for the module [module].
  List<String> fileRootsOf(ModuleId module) =>
      [for (final root in fileRoots) _expand(root, module)];

  /// [forbiddenFileRoots] for the module [module].
  List<String> forbiddenFileRootsOf(ModuleId module) =>
      [for (final root in forbiddenFileRoots) _expand(root, module)];

  /// [compositionFile] for the module [module], if the kind has one.
  String? compositionFileOf(ModuleId module) {
    final file = compositionFile;
    return file == null ? null : _expand(file, module);
  }

  /// Whether the module [module] may generate the file at [path].
  ///
  /// Case does not matter, as on the file systems of macOS and Windows.
  bool allowsFile(ModuleId module, String path) {
    final lower = path.toLowerCase();
    bool isIn(String root) =>
        lower.startsWith((root.endsWith('/') ? root : '$root/').toLowerCase());

    final roots = fileRootsOf(module);
    return (roots.isEmpty || roots.any(isIn)) &&
        !forbiddenFileRootsOf(module).any(isIn);
  }

  static String _expand(String pattern, ModuleId module) =>
      pattern.replaceAll('<id>', module.value);

  @override
  String toString() => 'module kind $id';
}
