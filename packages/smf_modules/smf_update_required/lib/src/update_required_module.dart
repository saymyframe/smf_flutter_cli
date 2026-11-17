import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_update_required/bundles/update_required_bundle.dart';
import 'package:smf_update_required/src/agents.dart';
import 'package:smf_update_required/src/readme.dart';

/// The module of the screen "Update required": a feature with one route,
/// whose screen, `UpdateRequiredScreen`, takes the place of the app while
/// the version of the app is below the lowest version that may run.
///
/// The lowest version is the parameter [minimumVersion] of the
/// [RemoteConfigRole], which the module requires, so the developer of the
/// app raises it in the backend of remote config without a new version of
/// the app. Its default is empty, which is no lowest version. The version of
/// the app is its version name, such as `1.4.0` of `version: 1.4.0+12` in
/// its pubspec, without the build number, which the module reads with
/// package_info_plus. The two compare number by number, and a missing
/// number is 0, so `1.2` equals `1.2.0` and `1.10.0` is above `1.9.2`. A
/// version or a lowest version that is not one to four numbers between dots,
/// such as `2.0.0-beta`, keeps the app running, and a debug build prints
/// why. The comparison is in `lib/features/update_required/version_compare.dart`,
/// which needs only Dart.
///
/// The screen leads to the page of the app in its store, which the
/// [ReviewRole] opens, so the module requires that role too. On iOS without
/// the App Store ID of the app, the app has no store page, and the screen
/// never shows: a debug build says so. The screen is hard until the user
/// taps "Update". From then on, or at once when the store page did not
/// open, which the screen says, it also offers "Not now", which lets the
/// user in for this launch below that lowest version. So a lowest version
/// above the version in the store, set too early, costs a user one trip to
/// the store and never locks anyone out. Another lowest version takes the
/// place of the app again, and so does the next launch.
///
/// The module declares a guard of the routes, `supported`, whose target is
/// the route of the screen (see [RouteGuard]): while the version may not
/// run, the router shows the screen in place of every other screen of the
/// app, whichever module provides the router, and leaves it once the
/// version may run again, for the screen that the guard kept the user from.
/// The guard is of the stage [GuardStage.welcome], since it needs to know
/// nothing of the user, so the app asks it before a guard that asks who the
/// user is. Among the guards of that stage, such as that of an onboarding,
/// the order of the modules of the app decides.
///
/// Whether the version may run is in `updateStatus`, a top-level object of
/// `lib/features/update_required/update_status.dart`, which the guard and
/// the screen share, so the module needs no DI container. `bootstrap()`
/// starts it once the services of the app are ready: it reads the version
/// of the app, within two seconds, and follows the values of remote config
/// from then on, so the screen takes the place of the app before its first
/// frame, and also while the app runs, once a new lowest version comes.
///
/// The route is `/` of the module, so its full path is `/update_required`.
/// It is no destination of the main navigation, and the app cannot start on
/// it. Nothing navigates to it: the route is the flow of the guard, so a
/// navigation to it while the version may run shows the screen that the app
/// starts on.
///
/// The texts of the screen, [texts], are in English and in Ukrainian. The
/// module only uses the localization role: in an app with the role they are
/// texts of the app, and in an app without it they are English.
///
/// The module adds `package_info_plus` to the app, the section
/// [readmeHeading] to the README of the app, and a section of its own to the
/// guide for coding agents of the app.
final class UpdateRequiredModule extends SmfModule {
  /// Creates the module.
  const UpdateRequiredModule();

  /// The id of the module.
  static const id = ModuleId('update_required');

  /// The parameter of remote config with the lowest version of the app that
  /// may run, such as `1.4.0`, empty for none.
  static const minimumVersion = RemoteConfigKey.text(
    'update_required_minimum_version',
    defaultValue: '',
    description: 'The lowest version of the app that may run, such as 1.4.0; '
        'empty for none',
  );

  /// The texts of the screen: its title, its text, the labels of its two
  /// buttons, and what it says when the store did not open.
  static const texts = TextsData([
    LocalizedText(
      'title',
      en: 'Update required',
      translations: {'uk': 'Потрібне оновлення'},
    ),
    LocalizedText(
      'body',
      en: 'This version of the app is no longer supported. Update the app to '
          'keep using it.',
      translations: {
        'uk': 'Ця версія застосунку більше не підтримується. Оновіть '
            'застосунок, щоб користуватися ним далі.',
      },
    ),
    LocalizedText('update', en: 'Update', translations: {'uk': 'Оновити'}),
    LocalizedText('later', en: 'Not now', translations: {'uk': 'Не зараз'}),
    LocalizedText(
      'storeFailed',
      en: "Couldn't open the store.",
      translations: {'uk': 'Не вдалося відкрити магазин.'},
    ),
  ]);

  /// The name of the route of the screen, the target of the guard.
  static const route = 'updateRequired';

  /// The name of the guard of the routes of the module.
  static const guard = 'supported';

  /// The file with `updateStatus` and the function of the guard.
  static const _status = ImportRef.app(
    'features/update_required/update_status.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A screen in place of the app below the lowest version '
            'of remote config',
        kind: ModuleKinds.feature,
        requires: {remoteConfigRole, reviewRole},
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          updateRequiredBundle,
          vars: {
            'app_symbol': SmfNames.dartString(
              SmfNames.elementSymbolOf(context.appName),
            ),
            'app_number': SmfNames.elementNumberOf(context.appName),
            'app_store_id_key': ReviewRole.appStoreIdKey.name,
            ...localizationRole.varsOf(id, texts),
          },
        ),
        const PubspecContribution.hosted('package_info_plus', '^10.2.0'),
        routerRole.data(
          const RoutesData(
            [
              Route(
                '/',
                name: route,
                screen: ScreenRef(
                  'UpdateRequiredScreen',
                  import: ImportRef.app(
                    'features/update_required/update_required_screen.dart',
                  ),
                ),
              ),
            ],
            guards: [
              // Once the version may run again, the guard brings the user
              // back to the screen that it kept the user from.
              RouteGuard(
                name: guard,
                allows: FunctionRef('versionSupported', import: _status),
                redirectTo: route,
                stage: GuardStage.welcome,
              ),
            ],
          ),
        ),
        remoteConfigRole.data(minimumVersion),
        const SocketContribution.code(
          AppEntryRole.bootstrapLate,
          Fragment('await updateStatus.start();', imports: [_status]),
        ),
        localizationRole.data(texts),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(agentHeading, AgentNote(agentNote)),
      ];
}
