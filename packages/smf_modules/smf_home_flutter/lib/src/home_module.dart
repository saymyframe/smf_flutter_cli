import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_home_flutter/bundles/home_bundle.dart';
import 'package:smf_home_flutter/src/agents.dart';
import 'package:smf_home_flutter/src/app_cell.dart';

/// The module of the start screen of the app: a feature with one route,
/// whose screen, `HomeScreen`, welcomes the developer of the app.
///
/// The screen greets by the time of the day and names the app, next to the
/// mark of Say My Frame. Below them, a card in the colours of Say My Frame
/// tells that the app is ready. The card shows the app as a cell of the
/// periodic table, with a symbol and a number that the module makes from
/// the name of the app, such as `Ma` and 5 for `my_app`, next to cells that
/// light up one after another. Three steps follow, each with the path or
/// the address that it is about, which a tap copies: replace the screen,
/// add a feature, read the documentation. The parts of the screen rise in
/// one after another, once, and an app that asks for less motion shows
/// them at once. The app replaces the content of the screen with its own
/// first screen.
///
/// The route is `/` of the module, so its full path is `/home`. The app can
/// start on it: when no other route can, the app starts there, and
/// otherwise `smf create` asks which route, or takes it from `--start`. The
/// main navigation of the app, when a module provides it, shows the route
/// as Home with the home icon.
///
/// The texts of the screen, [texts], and that label are texts of the
/// module, in English and in Ukrainian, which the module gives the
/// localization role, a role that it uses. With the role, the screen and
/// the main navigation read them from the texts of the app, in the language
/// of the app; without it, they are the English texts.
///
/// The mark is an image of the app, [markFile], with a file for each of
/// the screens with more pixels ([markVariants]), which Flutter finds next
/// to it. The module declares the image in `pubspec.yaml` of the app, and
/// adds no package: the styles of the texts are those of the theme of the
/// app, whichever module provides it, and a path is in the monospaced font
/// of the device.
///
/// As a feature, the module requires the router role, whichever module
/// provides it, and keeps its files in `lib/features/home/`, the image
/// too. What moves on the screen is the state of the screen itself, so the
/// module has no variants for the modules that manage state.
///
/// The guide for coding agents of the app has a section of the module,
/// which says that the screen is a welcome whose content the app replaces,
/// and where the image is declared.
final class HomeModule extends SmfModule {
  /// Creates the module.
  const HomeModule();

  /// The id of the module.
  static const id = ModuleId('home');

  /// The mark of Say My Frame in the app, an image for a screen with one
  /// pixel for each logical pixel, which `pubspec.yaml` of the app declares
  /// among its assets.
  static const markFile = '$_markDirectory/smf_mark.png';

  /// The files of the mark for the screens with more pixels, each by the
  /// number of pixels for a logical pixel. Flutter finds them next to
  /// [markFile], which alone is declared.
  static const markVariants = {
    2: '$_markDirectory/2.0x/smf_mark.png',
    3: '$_markDirectory/3.0x/smf_mark.png',
  };

  /// The directory of the app with the files of the mark.
  static const _markDirectory = 'lib/features/home/assets';

  /// The label of the destination of the screen in the main navigation.
  static const _label = LocalizedText(
    'label',
    en: 'Home',
    translations: {'uk': 'Головна'},
  );

  /// The texts of the screen: its greeting at each time of the day, what
  /// its card says, its three steps, what it says once a tap has copied the
  /// path of a step, and its last line.
  static const texts = TextsData([
    LocalizedText(
      'greetingMorning',
      en: 'Good morning',
      translations: {'uk': 'Доброго ранку'},
    ),
    LocalizedText(
      'greetingAfternoon',
      en: 'Good afternoon',
      translations: {'uk': 'Добрий день'},
    ),
    LocalizedText(
      'greetingEvening',
      en: 'Good evening',
      translations: {'uk': 'Добрий вечір'},
    ),
    LocalizedText(
      'readyTitle',
      en: 'Your app is ready',
      translations: {'uk': 'Ваш застосунок готовий'},
    ),
    LocalizedText(
      'readyText',
      en: 'Generated with Say My Frame. Everything you see is yours to '
          'change.',
      translations: {
        'uk': 'Згенеровано з Say My Frame. Усе, що ви бачите, можна змінити.',
      },
    ),
    LocalizedText(
      'nextTitle',
      en: 'Next steps',
      translations: {'uk': 'Що далі'},
    ),
    LocalizedText(
      'stepScreenTitle',
      en: 'Make this screen yours',
      translations: {'uk': 'Зробіть цей екран своїм'},
    ),
    LocalizedText(
      'stepScreenText',
      en: 'Replace this welcome with the first screen of your app.',
      translations: {
        'uk': 'Замініть це привітання першим екраном вашого застосунку.',
      },
    ),
    LocalizedText(
      'stepFeatureTitle',
      en: 'Add a feature',
      translations: {'uk': 'Додайте фічу'},
    ),
    LocalizedText(
      'stepFeatureText',
      en: 'A feature keeps its screens and routes in a folder of its own.',
      translations: {
        'uk': 'Фіча тримає свої екрани й маршрути у власній теці.',
      },
    ),
    LocalizedText(
      'stepDocsTitle',
      en: 'Read the docs',
      translations: {'uk': 'Почитайте документацію'},
    ),
    LocalizedText(
      'stepDocsText',
      en: 'Guides for every module, and for writing your own.',
      translations: {
        'uk': 'Настанови до кожного модуля і до написання власного.',
      },
    ),
    LocalizedText(
      'copied',
      en: 'Copied',
      translations: {'uk': 'Скопійовано'},
    ),
    LocalizedText(
      'footer',
      en: 'Built with Say My Frame',
      translations: {'uk': 'Зроблено з Say My Frame'},
    ),
  ]);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Start screen with a welcome and the next steps',
        kind: ModuleKinds.feature,
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          homeBundle,
          vars: {
            'app_symbol': SmfNames.dartString(appSymbolOf(context.appName)),
            'app_number': appNumberOf(context.appName),
            ...localizationRole.varsOf(id, texts),
          },
        ),
        const PubspecContribution.flutter(assets: [markFile]),
        localizationRole.data(const TextsData([_label])),
        localizationRole.data(texts),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: 'home',
              screen: ScreenRef(
                'HomeScreen',
                import: ImportRef.app('features/home/home_screen.dart'),
              ),
              destination: Destination(
                label: _label,
                icon: Fragment(
                  'Icons.home',
                  imports: [
                    ImportRef('package:flutter/material.dart', show: ['Icons']),
                  ],
                ),
              ),
              startCandidate: true,
            ),
          ]),
        ),
        AppEntryRole.agentSections.entry(agentHeading, AgentNote(agentNote)),
      ];
}
