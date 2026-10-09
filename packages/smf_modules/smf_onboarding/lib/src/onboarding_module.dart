import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_onboarding/bundles/onboarding_bundle.dart';
import 'package:smf_onboarding/src/agents.dart';

/// The module of the onboarding of the app: a feature with one route, whose
/// screen, `OnboardingScreen`, a new user goes through on the first launch
/// of the app, before every other screen.
///
/// The screen shows two neutral pages, a welcome with the name of the app
/// and a page that ends the onboarding. A page is a cell of the periodic
/// table among smaller cells, with a title and a text below them. The
/// cell of the first page has the symbol of the app, such as `Ma` for
/// `my_app`, which the module takes from the name of the app when it
/// generates the app ([SmfNames.elementSymbolOf]), and that of the last
/// page has an icon. Skip is above
/// the pages. Below them are a mark for each page and one button: Next,
/// and Get started on the last page, where Skip is gone. The pages are the
/// list that `onboardingPages()` returns in
/// `lib/features/onboarding/onboarding_pages.dart`, which the app replaces
/// with its own.
///
/// While the pages turn, the cells and the texts of a page move at their
/// own pace, the background blends into that of the last page, and the
/// marks follow. Each of these motions ends. In an app that asks for less
/// motion, Next shows the next page at once, and the cells of a page are
/// there at once when the page is first shown. The letters and the number
/// of a cell keep their size at a large text size, since the cell is a
/// picture that does not grow. The screen takes its colours and its text
/// styles from the theme of the app, whichever module provides it, and
/// names no font but the monospaced one of the device, for the number of a
/// cell.
///
/// The route is `/` of the module, so its full path is `/onboarding`. It is
/// no destination of the main navigation, and the app cannot start on it.
/// The module declares a guard of the routes, `firstRun`, whose target is
/// that route (see [RouteGuard]): until the user has finished the
/// onboarding, the router shows it in place of every other screen of the
/// app, whichever module provides the router. Skip and the last button
/// only finish the onboarding, and the router leaves it for the location
/// that the guard kept the user from: on a first launch, the screen that
/// the app starts on, or the fallback screen of the app entry in an app
/// that no route can start. The next launches of the app start there.
///
/// Whether the user has finished the onboarding is in `onboardingStatus`, a
/// top-level object of `lib/features/onboarding/onboarding_status.dart`,
/// which the guard, the screen and the restorer of the module share, so the
/// module needs no DI container. `onboardingStatus.complete()` finishes the
/// onboarding at once and saves that. The module requires the preferences
/// role: the app saves it under the key [completedKey], and the restorer
/// that the module gives [PreferencesRole.restorers] takes it from there
/// before the first frame of the app, so a later launch never shows the
/// onboarding first. The restorer keeps the current value when nothing is
/// saved, so `complete()` before the app starts, which changes only memory,
/// opens the guard for a test of another screen.
///
/// Nothing is saved before the user finishes: an app that is closed in the
/// middle of the onboarding starts it from its first page the next time.
///
/// `onboardingStatus.restart()` starts the onboarding again, at once, and
/// saves that, for an app that lets its user see the onboarding again. The
/// guard stops allowing, so the router shows the onboarding in place of the
/// screen that the user is on. Once it is finished again, the router shows
/// that screen again, or the screen below the pushed pages if the user was
/// on a page pushed over another screen. Before the start-up of the app
/// opened the preferences, `restart()` changes only memory, and the
/// start-up then takes what is saved.
///
/// So the app shows the screen of the onboarding exactly while the
/// onboarding is not finished, and nothing navigates to it. The route is
/// the flow of the guard, which is over once the onboarding is finished: a
/// navigation to it then, such as a link, shows the screen that the app
/// starts on, or the target of another guard of the app while that one
/// does not allow, as the router role says of the flow of a guard.
/// `restart()` is the only way to show the onboarding again.
///
/// The texts of the screen, [texts], are in English and in Ukrainian. The
/// module only uses the localization role: in an app with the role they are
/// texts of the app, and in an app without it they are English.
///
/// As a feature, the module requires the router role too, whichever module
/// provides it, and keeps its files in `lib/features/onboarding/`. The page
/// that the user sees is the state of a `PageController` in the screen, so
/// the module has no variants for the modules that manage state, and it
/// adds no package to the app.
///
/// The guide for coding agents of the app has a section of the module: what
/// shows the onboarding, where its pages and its status are, how to show it
/// again, and what a test of another screen does about it.
final class OnboardingModule extends SmfModule {
  /// Creates the module.
  const OnboardingModule();

  /// The id of the module.
  static const id = ModuleId('onboarding');

  /// The key of the preferences of the app under which the app saves
  /// whether the user has finished the onboarding: `true` once the user
  /// has, and `false` once the onboarding starts again.
  static const completedKey = 'onboarding.completed';

  /// The texts of the screen: what its two pages say, but for the name of
  /// the app, and its buttons. `done` is the label of the button on the
  /// last page.
  static const texts = TextsData([
    LocalizedText(
      'welcome',
      en: 'Welcome! We are glad you are here.',
      translations: {'uk': 'Вітаємо! Раді, що ви з нами.'},
    ),
    LocalizedText(
      'readyTitle',
      en: 'You are all set',
      translations: {'uk': 'Усе готово'},
    ),
    LocalizedText(
      'ready',
      en: 'Enjoy the app.',
      translations: {'uk': 'Приємного користування!'},
    ),
    LocalizedText('skip', en: 'Skip', translations: {'uk': 'Пропустити'}),
    LocalizedText('next', en: 'Next', translations: {'uk': 'Далі'}),
    LocalizedText('done', en: 'Get started', translations: {'uk': 'Почати'}),
  ]);

  /// The name of the route of the screen, the target of the guard.
  static const _route = 'onboarding';

  /// The file with `onboardingStatus`, the function of the guard and the
  /// restorer.
  static const _status = ImportRef.app(
    'features/onboarding/onboarding_status.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Onboarding on the first launch of the app',
        kind: ModuleKinds.feature,
        requires: {preferencesRole},
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          onboardingBundle,
          vars: {
            'completed_key': SmfNames.dartString(completedKey),
            'symbol': SmfNames.dartString(
              SmfNames.elementSymbolOf(context.appName),
            ),
            ...localizationRole.varsOf(id, texts),
          },
        ),
        routerRole.data(
          const RoutesData(
            [
              Route(
                '/',
                name: _route,
                screen: ScreenRef(
                  'OnboardingScreen',
                  import: ImportRef.app(
                    'features/onboarding/onboarding_screen.dart',
                  ),
                ),
              ),
            ],
            guards: [
              RouteGuard(
                name: 'firstRun',
                allows: FunctionRef('onboardingCompleted', import: _status),
                redirectTo: _route,
              ),
            ],
          ),
        ),
        const SocketContribution.item(
          PreferencesRole.restorers,
          Fragment('restoreOnboarding', imports: [_status]),
        ),
        localizationRole.data(texts),
        AppEntryRole.agentSections.entry(agentHeading, AgentNote(agentNote)),
      ];
}
