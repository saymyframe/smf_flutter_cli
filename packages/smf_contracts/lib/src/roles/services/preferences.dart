part of '../services.dart';

/// The preferences role; see [PreferencesRole].
const preferencesRole = PreferencesRole._();

/// The role of the preferences: the settings of the app that are no secret,
/// which it remembers between its launches, such as the theme mode, the
/// language, and whether the user has seen the onboarding.
///
/// Nothing here is encrypted, and a backup of the device carries it: never
/// store a token, a password, an API key or an encryption key in the
/// preferences.
///
/// The role's template generates
/// `lib/core/preferences/app_preferences.dart` with:
/// - the `AppPreferences` interface. A read is synchronous, from memory,
///   and never throws: it returns `null` when the key has no value of the
///   type it asks for. Whether a number saved as an `int` is read as a
///   `double`, or the other way round, is up to the provider. Once the
///   future of a write completes, reads return what it saved, in this run
///   of the app and after its next launch. A key has one value: a write
///   replaces what the key had, a value of another type too. The
///   preferences keep a copy of a list they are given, and a read returns a
///   copy of it, so a change of either list changes nothing that is saved.
///   `remove` puts a setting back to its default: the reads of its key
///   return `null` again;
/// - `Future<void> initPreferences()`, which opens the preferences with the
///   provider's implementation and then calls the functions of
///   [restorers]. `bootstrap()` awaits it in its platform phase, so every
///   module has its settings before the DI container is filled and before
///   the first frame. If the preferences cannot be opened, it fails, and
///   `bootstrap()` with it;
/// - `AppPreferences createAppPreferences()`, which returns the preferences
///   that `initPreferences()` opened.
///
/// A module, or the template of a role that requires or uses this one,
/// reaches the preferences through [restorers], whichever kind the module
/// is of and whether the app has a DI container or not. Neither calls
/// `createAppPreferences()`, and neither calls `initPreferences()`, which
/// only `bootstrap()` calls. With a DI container, the preferences are
/// registered as a lazy singleton too: a service takes them as a
/// dependency of its factory, and the composition file of a feature
/// resolves them. Widgets talk to the state of their module, never to the
/// preferences.
///
/// A key is `<owner id>.<setting>`, such as `theme.mode`, where the owner
/// is the module or the role whose code keeps the setting. The ids of
/// modules and roles never collide, so neither do the keys of owners that
/// keep to this form. Nothing checks it: two owners that save under one
/// key overwrite each other's setting.
///
/// `initPreferences()` may run again, which only tests do, to see what the
/// next launch of the app reads: it opens the preferences anew and calls
/// the restorers again. So the function of the provider's implementation
/// reads what is saved each time it is called. A DI container that created
/// the preferences before keeps the object of the earlier open, so a test
/// of code that takes them from the container also runs
/// `resetDependencies()` and `registerDependencies()` once
/// `initPreferences()` ran again.
///
/// The provider contributes its implementation as a [RoleImplementation],
/// created with the app or asynchronously.
///
/// In the guide for coding agents of the app, the template tells in the
/// section of the role what the preferences are for, what never goes into
/// them, how code remembers a setting, and that code does not call the
/// functions of the role.
final class PreferencesRole extends Role<RoleImplementation> {
  const PreferencesRole._();

  /// The path of the file with `AppPreferences`.
  static const file = 'lib/core/preferences/app_preferences.dart';

  /// The implementation of the preferences, which the template renders from
  /// the provider's [RoleImplementation]; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    preferencesRole,
    'implementations',
    CodeSocket(),
  );

  /// Functions that restore what their owner, a module or the template of a
  /// role, keeps in the preferences, such as `restoreAppThemeMode`: functions
  /// of the type `void Function(AppPreferences preferences)`.
  ///
  /// `initPreferences()` calls each with the preferences of the app once
  /// they are open, in the platform phase of `bootstrap()`: before the DI
  /// container is filled and before the first frame, for which the root of
  /// the app reads the router. A restorer reads the settings of its owner,
  /// puts them into the state of its owner, such as a notifier that its
  /// widgets listen to, and keeps the preferences there for the writes of
  /// its owner.
  ///
  /// A restorer must be synchronous and await nothing. The reads are
  /// synchronous, so it has done all of it when it returns. Nothing waits
  /// for an asynchronous one, which may finish after the first frame, and
  /// what it throws then is not caught. No rule checks this.
  ///
  /// A restorer keeps the current value of a setting when nothing is saved
  /// under its key, and a write before the preferences are open changes
  /// only memory. So the state that a test sets before `bootstrap()`
  /// survives the start.
  ///
  /// A restorer may run more than once: `initPreferences()` may run again,
  /// as a test does for the next launch of the app, and then calls each
  /// restorer with the preferences that it opened anew. So a restorer takes
  /// the state of its owner from what it reads each time, and the
  /// preferences it got last are the ones its owner writes to. A test shows
  /// that a setting is remembered by writing its key through
  /// `AppPreferences`, running `initPreferences()` again and reading the
  /// state, and that it is saved by reading the key after a choice. Running
  /// `initPreferences()` again right after a choice proves nothing, since
  /// memory has the value already. Nor does it stand for the next launch
  /// once a key was removed: the restorer finds nothing saved and keeps the
  /// value that the state has, where a new launch starts with the default.
  ///
  /// The template calls each restorer on its own, as their owners know
  /// nothing of each other: what one throws, an error or an exception,
  /// keeps no other from restoring and does not stop the start-up, since
  /// what is saved is input that development does not see. The app then
  /// starts with the defaults of that owner, and in debug mode what was
  /// thrown is printed.
  static const restorers = SocketRef<FactoryListSocket>.role(
    preferencesRole,
    'restorers',
    FactoryListSocket(),
  );

  @override
  String get id => 'preferences';

  @override
  String get description => 'Preferences';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get uses => {diRole};

  @override
  List<SocketRef> get sockets => const [implementations, restorers];

  @override
  RoleInterface get interface => const RoleInterface(files: [file]);

  @override
  RoleTemplate<RoleImplementation> get template => const _PreferencesTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'preferences.factory_calls',
          description: 'Only the DI container calls createAppPreferences(), '
              'and only bootstrap() calls initPreferences().',
          check: _checkPreferencesCalls,
        ),
        StructuralRule(
          id: 'preferences.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

/// What the owner of a file does rather than call a function of the role.
const _restorersHint =
    'Put a function into PreferencesRole.restorers, which gets the '
    'preferences when the app starts, or take them as a dependency of your '
    'own factory.';

/// The problems with the calls of the functions of the role in [input]:
/// - `createAppPreferences()` in a file of a module that does not provide
///   the DI role, or of the template of another role, which get the
///   preferences through [PreferencesRole.restorers];
/// - `initPreferences()` in any file of the app but that of `bootstrap()`,
///   which awaits it once, before the first frame.
List<SmfIssue> _checkPreferencesCalls(
  StructuralRuleInput<RoleImplementation> input,
) =>
    [
      ..._checkFactoryCalls(
        input,
        'createAppPreferences',
        PreferencesRole.file,
        hint: _restorersHint,
        templates: true,
      ),
      for (final MapEntry(key: path, value: index) in input.files.entries)
        if (path != AppEntryRole.bootstrapFile &&
            usesSymbols(index, {'initPreferences'}, PreferencesRole.file))
          SmfIssue(
            '$path calls initPreferences(), which only bootstrap() calls.',
            hint: 'The role opens the preferences in bootstrap(), before the '
                'first frame. $_restorersHint',
            origin: input.owners[path],
            path: path,
          ),
    ];

final class _PreferencesTemplate extends _ServiceTemplate {
  const _PreferencesTemplate();

  @override
  Role<RoleImplementation> get role => preferencesRole;

  @override
  MasonBundle get bundle => preferencesRoleBundle;

  @override
  String get file => PreferencesRole.file;

  @override
  String get service => 'AppPreferences';

  @override
  String get factory => 'createAppPreferences';

  @override
  String get initFunction => 'initPreferences';

  @override
  String get variable => '_appPreferences';

  @override
  SocketRef<CodeSocket> get implementations => PreferencesRole.implementations;

  /// The note of the role in the guide for coding agents: what the
  /// preferences are for, what never goes into them, and how the code of an
  /// app gets them, whichever module provides the role.
  String get agentNote => '''
- `$service` in `$file` remembers the settings of the app between its launches, such as the theme mode. It is not encrypted: never save a token, a password, an API key or an encryption key in it.
- To remember a setting, write a function that takes the `$service` and add it to `_restorers` in that file. In it, read the setting, put it into the state that the widgets listen to, and keep the preferences in that state for its writes. The function awaits nothing, and keeps the current value when nothing is saved.
- Name a key `<owner id>.<setting>`, such as `theme.mode`, where the owner is the feature or the concern whose code keeps the setting.
- Do not call `$factory()` or `$initFunction()`. `${AppEntryRole.bootstrap.name}()` opens the preferences, and code gets them as the argument of its function in `_restorers`, or, with a DI container in the app, from the container. Widgets use the state and do not touch the preferences.
''';

  @override
  List<Contribution> contribute(ModuleContext context) => [
        ...super.contribute(context),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
      ];

  /// `bootstrap()` always awaits `initPreferences()`, which also calls the
  /// restorers, whether the implementation is created asynchronously or
  /// not.
  @override
  String bootstrap({required bool hasAsync}) => 'await $initFunction();';

  /// The preferences of the app, and `initPreferences()`, which opens them
  /// with the only implementation in [all] and then calls the restorers.
  ///
  /// It may run again, so the variable is not final.
  @override
  String _single(List<_Prefixed> all) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    final open = implementation.isAsync ? 'await $factory()' : '$factory()';
    return '''
late $service $variable;

/// Opens the preferences of the app and gives them to the restorers of its
/// parts; `bootstrap()` awaits it before the first frame, and nothing else
/// in the app calls it.
///
/// It may run again, as a test does to see what the next launch of the app
/// reads: it opens the preferences anew, with what is saved, and calls the
/// restorers again.
Future<void> $initFunction() async {
  $variable = $open;
  _restore($variable);
}''';
  }
}
