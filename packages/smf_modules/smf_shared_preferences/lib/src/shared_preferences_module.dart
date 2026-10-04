import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_shared_preferences/bundles/shared_preferences_bundle.dart';
import 'package:smf_shared_preferences/src/agents.dart';

/// The module that keeps the preferences of the app with the
/// shared_preferences package, and so provides the preferences role: the
/// settings of the app that are no secret, which it remembers between its
/// launches, such as the theme mode.
///
/// The template of the role generates the `AppPreferences` interface and
/// `initPreferences()`, which `bootstrap()` awaits before the first frame.
/// This module adds `shared_preferences` to the dependencies of the app and
/// implements the interface in
/// `lib/core/preferences/shared_app_preferences.dart` on
/// `SharedPreferencesWithCache`, which reads what is saved into memory when
/// the app starts, so that the reads are synchronous. The package keeps the
/// values in DataStore on Android and in `UserDefaults` on iOS. Neither is
/// encrypted, and a backup of the device carries them: never store a token,
/// a password, an API key or an encryption key in the preferences.
///
/// The implementation keeps what the role promises and the package does
/// not: a read of a key with a value of another type returns `null` rather
/// than throwing, and the preferences keep a copy of a list they are given.
/// It reads a list in the form that each platform returns it in when the
/// preferences are opened, and returns `null` for one with an item that is
/// no text.
///
/// The role leaves to its provider whether a number saved as an `int` is
/// read as a `double`, or the other way round. This one reads a number only
/// as the type that it was saved as: `getDouble` returns `null` for a key
/// with an `int`, and `getInt` for a key with a `double`, a whole number
/// too.
///
/// When the app has a DI container, the role registers the preferences in
/// it.
///
/// In the guide for coding agents, the module adds to the section of the
/// preferences which file imports the package, how this provider reads a
/// number, and what a test of the app sets in place of the platform side of
/// the package.
final class SharedPreferencesModule extends SmfModule {
  /// Creates the module.
  const SharedPreferencesModule();

  /// The id of the module.
  static const id = ModuleId('shared_preferences');

  static const _file = ImportRef.app(
    'core/preferences/shared_app_preferences.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Preferences with shared_preferences',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(preferencesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(sharedPreferencesBundle),
        const PubspecContribution.hosted('shared_preferences', '^2.5.5'),
        preferencesRole.data(
          const RoleImplementation.async(
            type: TypeRef('SharedAppPreferences', import: _file),
            init: FactoryRef('openSharedAppPreferences', import: _file),
          ),
        ),
        AppEntryRole.agentSections.entry(
          preferencesRole.description,
          AgentNote(agentNote),
        ),
      ];
}
