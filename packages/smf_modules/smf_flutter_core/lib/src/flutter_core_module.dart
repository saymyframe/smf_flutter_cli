import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/flutter_core_bundle.dart';
import 'package:smf_flutter_core/src/agents.dart';

/// The module that creates the app itself, and so provides the app entry
/// role.
///
/// Its brick has the files of `flutter create` for Android and iOS, and:
/// - `lib/main.dart`, whose `main()` awaits `bootstrap()` and runs `App`
///   inside the root wrappers of the modules;
/// - `lib/bootstrap.dart`, with the start-up code of the modules in the
///   order of its phases;
/// - `lib/app.dart`, the root widget `App`: a `MaterialApp.router` with the
///   router's configuration when a router is present, or else a
///   `MaterialApp` that shows the `FallbackStartScreen`. `App` creates it in
///   its `build`, so the arguments that the modules give it read the
///   `BuildContext` of `App`, below the root wrappers, and `App` rebuilds
///   when an inherited widget that they read notifies;
/// - `lib/core/app/fallback_start_screen.dart`, the screen that an app
///   without a route to start on shows, and a widget test of it;
/// - `pubspec.yaml` with the dependencies of all modules, and the lints of
///   a new Flutter app.
///
/// Every socket of the app entry role has its tag in these files, but for
/// the sections of the guide for coding agents, whose tag is in the template
/// of the role. The native projects follow `flutter create` of Flutter 3.44,
/// so the app needs Flutter 3.44 or newer, and iOS [minimumIosVersion] or
/// newer.
///
/// The fallback start screen is for the developer of the app, who sees it
/// until the app has a screen to start on. It shows a cell like that of an
/// element of the periodic table, with a symbol and a number that the
/// module takes from the name of the app ([SmfNames.elementSymbolOf] and
/// [SmfNames.elementNumberOf], as every module that shows such a cell does),
/// then the name of the app, a hint that the app has no start screen yet,
/// and the path of the file of the screen, which a tap copies. The hint and
/// the word that the screen says once the path is copied are texts of the
/// module, in English and in Ukrainian, which the module gives the
/// localization role, a role that it uses: with the role, the screen reads
/// them from the texts of the app, in the language of the app, and without
/// it they are the English texts. `FallbackStartScreen` only reads the two
/// texts and gives them to `FallbackStartView`, which shows the rest. So
/// the widget test of the app shows the view with texts of its own, in an
/// app with the role too, where only the root of the app has the texts.
///
/// In the guide for coding agents, the module adds to the section of the
/// app entry what its files bring: the root widget and where its arguments
/// go, where the tests are and the platforms of the app.
final class FlutterCoreModule extends SmfModule {
  /// Creates the module.
  const FlutterCoreModule();

  /// The id of the module.
  static const id = ModuleId('flutter_core');

  /// The minimum iOS version of the app unless a module needs a higher one
  /// through [AppEntryRole.iosDeploymentTarget].
  ///
  /// It is the lowest version Xcode 27 builds for, and the one of the
  /// template of Flutter 3.47; the template of Flutter 3.44 still has 13.0.
  static const minimumIosVersion = '15.0';

  /// The hint of the fallback start screen, which tells the developer of
  /// the app that it has no start screen yet.
  static const _hint = LocalizedText(
    'fallbackHint',
    en: 'No start screen yet. Add a feature with a route, or replace this '
        'screen.',
    translations: {
      'uk': 'Стартового екрана ще немає. Додайте фічу з маршрутом або '
          'замініть цей екран.',
    },
  );

  /// What the fallback start screen says before the path of its file once
  /// a tap copied the path.
  static const _copied = LocalizedText(
    'fallbackCopied',
    en: 'Copied',
    translations: {'uk': 'Скопійовано'},
  );

  /// The texts of the module, which it gives the localization role.
  static const _texts = TextsData([_hint, _copied]);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Flutter app for Android and iOS',
        kind: ModuleKinds.scaffold,
        uses: {routerRole, localizationRole},
        providers: [RoleProvider.plain(appEntryRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final identity = context.appIdentity;
    return [
      BrickContribution(
        flutterCoreBundle,
        vars: {
          'android_namespace': identity.androidNamespace,
          'android_application_id': identity.androidApplicationId,
          // The directory of MainActivity.kt; the brick reads it in three
          // braces, so mustache does not escape the slashes.
          'android_package_path':
              identity.androidNamespace.replaceAll('.', '/'),
          'ios_bundle_id': identity.iosBundleId,
          'app_symbol': SmfNames.elementSymbolOf(context.appName),
          'app_number': SmfNames.elementNumberOf(context.appName),
          ...localizationRole.varsOf(id, _texts),
        },
      ),
      localizationRole.data(_texts),
      AppEntryRole.iosDeploymentTarget.value(minimumIosVersion),
      const PubspecContribution.environment(
        sdk: '^3.12.0',
        flutter: '>=3.44.0',
      ),
      const PubspecContribution.sdk('flutter'),
      const PubspecContribution.sdk('flutter_test', dev: true),
      const PubspecContribution.hosted('flutter_lints', '^6.0.0', dev: true),
      const PubspecContribution.flutter(usesMaterialDesign: true),
      AppEntryRole.agentSections.entry(
        appEntryRole.description,
        AgentNote(agentNote),
      ),
    ];
  }
}
