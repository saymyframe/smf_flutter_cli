import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sign_in/bundles/sign_in_bloc_bundle.dart';
import 'package:smf_sign_in/bundles/sign_in_bundle.dart';
import 'package:smf_sign_in/bundles/sign_in_riverpod_bundle.dart';
import 'package:smf_sign_in/src/agents.dart';

/// The module of the sign-in screens of the app: a feature with three
/// routes, on which a user signs in to an account with an email address and
/// a password, creates an account, and asks for the message that resets a
/// password.
///
/// ## The screens
///
/// `SignInScreen` is at `/` of the module, so its full path is `/sign_in`.
/// `SignUpScreen`, at `/sign_in/sign_up`, and `ResetPasswordScreen`, at
/// `/sign_in/reset_password`, are below it, so each shows over the sign-in
/// and its back button leads there. None of them is a destination of the
/// main navigation, and the app cannot start on them.
///
/// A screen shows the cell of the app, with the symbol and the number of
/// the name of the app ([SmfNames.elementSymbolOf] and
/// [SmfNames.elementNumberOf]), such as `Ma` and 5 for `my_app`, next to
/// the cells of a table that light up one after another. Below it are a
/// title, a line of text and the form: a field for the email address, a
/// field for the password with a button that shows it, and a button of the
/// whole width that submits. While its call is on its way, the button spins
/// and the form takes no input: its fields take no typing, though one that
/// has the focus keeps it, and its actions take neither a tap nor a key. A
/// failure shows above the button, in a text
/// of the module for each reason of the auth role. Once the message that
/// resets a password is sent, the screen shows the address that it went to,
/// in a widget of its own, since a text has no parameters.
///
/// The parts of a screen rise in one after another, once. In an app that
/// asks for less motion they are there at once, and a busy button is
/// disabled with its label rather than spinning. A screen scrolls when it
/// is too small for its content and is no wider than a phone. The letters
/// of the cell keep their size at a large text size, since the cell is a
/// picture.
///
/// The fields, the buttons and the cards of a screen are those of the
/// theme of the app, whichever module provides it: a screen gives a field
/// no colour, border or padding of its own, so a change of the theme
/// changes them here as everywhere else. What a screen draws itself, the
/// cells of its picture, takes its colours from the theme too. One button
/// has a colour of its own: the action that leads to the other screen,
/// from the sign-in to the sign-up and back, is a text button of the theme
/// in the accent of the colour scheme, since a theme keeps its text
/// buttons quiet and this one is the second way on from its screen.
///
/// ## Look and state
///
/// The look of the screens is the same in every app: the views
/// `SignInView`, `SignUpView` and `ResetPasswordView` and their widgets,
/// plain Flutter widgets that take the state of a call and callbacks. What
/// keeps that state depends on the module that manages state in the app, so
/// the module has [Variants] of the state management role, and requires
/// that role:
/// - for [blocVariant], a cubit for each screen, which the screen provides
///   and builds its view from, and a composition file that creates the
///   cubits with the session of the app;
/// - for [riverpodVariant], a provider for each screen, which lasts as long
///   as the screen, and `appSessionProvider`, through which they reach the
///   session of the app.
///
/// Each variant adds the package of its state manager with the constraint
/// `any`, so the version is the one of the module that provides the role.
///
/// The state signs in only through `appSession` of the auth role, which
/// the module requires, whichever module provides it. It calls
/// `appSession.signUp` in every mode of the app: what an anonymous user
/// gets is up to the session. While a call is on its way, the state is
/// busy and takes no second call. A failure ends that, with the failure as
/// part of the state. A sign-in or a sign-up that succeeded leaves the
/// state busy for as long as the session has the account: the user is
/// signed in then, and the router leaves the screen. When the session has
/// no account again before the router did, as when code of the app signs
/// the user out at once, the state is idle and the form is back. The module
/// registers nothing in a DI container and needs none.
///
/// ## The guards
///
/// The module declares two guards of the routes, whose target is the route
/// of the sign-in (see [RouteGuard]), with the functions of
/// `lib/features/sign_in/sign_in_guards.dart`:
/// - [gate] is a gate over the whole app, whose function returns
///   `appSession.allowsApp`: in an app that needs an account, the router
///   shows the sign-in in place of every other screen until the user is
///   signed in. It is of the stage [GuardStage.identity], so the app asks it
///   after a guard of a first launch, such as that of an onboarding. It
///   does not bring the user back ([RouteGuard.resumes]): after a sign-out,
///   the next user comes to the screen that the app starts on;
/// - [accountGuard] stands for [AuthRole.account], the condition of a route
///   whose screen is only for the user of an account. Its function returns
///   `appSession.hasAccount`, and the router shows the sign-in in place of
///   such a route until it holds. With it, the screens of the sign-in show
///   in an app that everyone may use without an account too, where the gate
///   always allows. It does not bring the user back either: once the user
///   of an account signs out on such a route, the next user does not come
///   to it.
///
/// So no screen navigates once the user is signed in, and nothing navigates
/// to the sign-in: the session changes, and the router shows the sign-in or
/// leaves it, whichever module provides the router. The three routes are
/// the flow of both guards, which is over once both allow: a navigation to
/// one of them then shows the screen that the app starts on.
///
/// ## Texts
///
/// The texts of the screens, [texts], are in English and in Ukrainian. The
/// module only uses the localization role: in an app with the role they
/// are texts of the app, and in an app without it they are English. The
/// text for a sign-in that is not set up at the provider says only that
/// sign-in is unavailable: what is wrong is in the `developerHint` of the
/// failure, which a screen shows in debug mode only.
///
/// The guide for coding agents of the app has a section of the module:
/// where its screens are and what shows them, which files are the look and
/// which the state, where a failure gets its text, what a widget test minds
/// while a call is on its way, and, by the variant, where the state of a
/// screen is.
final class SignInModule extends SmfModule {
  /// Creates the module.
  const SignInModule();

  /// The id of the module.
  static const id = ModuleId('sign_in');

  /// The id of the provider of the state management role whose variant of
  /// the screens keeps their state in cubits.
  static const blocVariant = ModuleId('bloc');

  /// The id of the provider of the state management role whose variant of
  /// the screens keeps their state in providers.
  static const riverpodVariant = ModuleId('riverpod');

  /// The name of the gate of the module among its guards, which shows the
  /// sign-in in place of every other screen while the user may not see the
  /// app; its full name is `sign_in.gate`.
  static const gate = 'gate';

  /// The name of the guard of the module that stands for
  /// [AuthRole.account], which shows the sign-in in place of a route that
  /// needs an account; its full name is `sign_in.hasAccount`, after what it
  /// reads.
  static const accountGuard = 'hasAccount';

  /// The texts of the screens: those of the sign-in, of the sign-up and of
  /// the password reset, what a form says of a field that is not filled
  /// in, and a text for each reason of a failure of the auth role.
  ///
  /// `emailInvalid` is both what the form says of an address without an
  /// `@` and the text of the failure `invalidEmail`.
  static const texts = TextsData([
    LocalizedText('title', en: 'Sign in', translations: {'uk': 'Вхід'}),
    LocalizedText(
      'intro',
      en: 'Enter the email and the password of your account.',
      translations: {'uk': 'Введіть пошту й пароль свого акаунта.'},
    ),
    LocalizedText(
      'email',
      en: 'Email',
      translations: {'uk': 'Електронна пошта'},
    ),
    LocalizedText('password', en: 'Password', translations: {'uk': 'Пароль'}),
    LocalizedText(
      'showPassword',
      en: 'Show password',
      translations: {'uk': 'Показати пароль'},
    ),
    LocalizedText(
      'hidePassword',
      en: 'Hide password',
      translations: {'uk': 'Приховати пароль'},
    ),
    LocalizedText('submit', en: 'Sign in', translations: {'uk': 'Увійти'}),
    LocalizedText(
      'forgotPassword',
      en: 'Forgot password?',
      translations: {'uk': 'Забули пароль?'},
    ),
    LocalizedText(
      'createAccount',
      en: 'Create account',
      translations: {'uk': 'Створити акаунт'},
    ),
    LocalizedText(
      'signUpTitle',
      en: 'Create account',
      translations: {'uk': 'Новий акаунт'},
    ),
    LocalizedText(
      'signUpIntro',
      en: 'All it takes is an email and a password.',
      translations: {'uk': 'Потрібні лише пошта й пароль.'},
    ),
    LocalizedText(
      'signUpSubmit',
      en: 'Create account',
      translations: {'uk': 'Створити акаунт'},
    ),
    LocalizedText(
      'haveAccount',
      en: 'I already have an account',
      translations: {'uk': 'У мене вже є акаунт'},
    ),
    LocalizedText(
      'resetTitle',
      en: 'Reset password',
      translations: {'uk': 'Відновлення пароля'},
    ),
    LocalizedText(
      'resetIntro',
      en: 'Enter the email of your account, and we will send you a link to '
          'set a new password.',
      translations: {
        'uk': 'Введіть пошту свого акаунта, і ми надішлемо посилання, щоб '
            'задати новий пароль.',
      },
    ),
    LocalizedText(
      'sendLink',
      en: 'Send link',
      translations: {'uk': 'Надіслати посилання'},
    ),
    LocalizedText(
      'resetSentTitle',
      en: 'Check your email',
      translations: {'uk': 'Перевірте пошту'},
    ),
    LocalizedText(
      'resetSent',
      en: 'If this address has an account, a link to set a new password is '
          'on its way to:',
      translations: {
        'uk': 'Якщо для цієї адреси є акаунт, посилання для нового пароля '
            'вже надіслано на:',
      },
    ),
    LocalizedText(
      'backToSignIn',
      en: 'Back to sign in',
      translations: {'uk': 'Назад до входу'},
    ),
    LocalizedText(
      'emailRequired',
      en: 'Enter your email.',
      translations: {'uk': 'Введіть пошту.'},
    ),
    LocalizedText(
      'emailInvalid',
      en: 'Enter a valid email address.',
      translations: {'uk': 'Введіть правильну адресу пошти.'},
    ),
    LocalizedText(
      'passwordRequired',
      en: 'Enter a password.',
      translations: {'uk': 'Введіть пароль.'},
    ),
    LocalizedText(
      'failureCredentials',
      en: 'The email or the password is wrong.',
      translations: {'uk': 'Неправильна пошта або пароль.'},
    ),
    LocalizedText(
      'failureEmailInUse',
      en: 'This email already has an account. Sign in instead.',
      translations: {'uk': 'Для цієї пошти вже є акаунт. Увійдіть у нього.'},
    ),
    LocalizedText(
      'failureWeakPassword',
      en: 'This password is too weak. Choose a stronger one.',
      translations: {'uk': 'Цей пароль надто слабкий. Виберіть надійніший.'},
    ),
    LocalizedText(
      'failureDisabled',
      en: 'This account is disabled.',
      translations: {'uk': 'Цей акаунт заблоковано.'},
    ),
    LocalizedText(
      'failureTooManyAttempts',
      en: 'Too many attempts. Try again later.',
      translations: {'uk': 'Забагато спроб. Спробуйте пізніше.'},
    ),
    LocalizedText(
      'failureNoNetwork',
      en: 'No connection. Check the internet and try again.',
      translations: {
        'uk': 'Немає зв’язку. Перевірте інтернет і спробуйте ще раз.',
      },
    ),
    LocalizedText(
      'failureRecentSignIn',
      en: 'Sign out and sign in again, then try once more.',
      translations: {
        'uk': 'Вийдіть і увійдіть знову, а тоді спробуйте ще раз.',
      },
    ),
    LocalizedText(
      'failureNotSetUp',
      en: 'Sign-in is unavailable right now.',
      translations: {'uk': 'Вхід зараз недоступний.'},
    ),
    LocalizedText(
      'failureUnknown',
      en: 'Something went wrong. Try again.',
      translations: {'uk': 'Щось пішло не так. Спробуйте ще раз.'},
    ),
    LocalizedText(
      'accountTitle',
      en: 'Account',
      translations: {'uk': 'Акаунт'},
    ),
    LocalizedText(
      'signedInAs',
      en: 'You are signed in to this account:',
      translations: {'uk': 'Ви увійшли в цей акаунт:'},
    ),
    LocalizedText(
      'signedIn',
      en: 'You are signed in.',
      translations: {'uk': 'Ви увійшли в акаунт.'},
    ),
    LocalizedText(
      'signOut',
      en: 'Sign out',
      translations: {'uk': 'Вийти'},
    ),
    LocalizedText(
      'deleteAccount',
      en: 'Delete account',
      translations: {'uk': 'Видалити акаунт'},
    ),
    LocalizedText(
      'deleteTitle',
      en: 'Delete your account?',
      translations: {'uk': 'Видалити акаунт?'},
    ),
    LocalizedText(
      'deleteText',
      en: 'This deletes your account for good. You cannot undo it.',
      translations: {
        'uk': 'Акаунт буде видалено назавжди. Відновити його не можна.',
      },
    ),
    LocalizedText(
      'cancel',
      en: 'Cancel',
      translations: {'uk': 'Скасувати'},
    ),
    LocalizedText(
      'delete',
      en: 'Delete',
      translations: {'uk': 'Видалити'},
    ),
    LocalizedText(
      'settingSignedIn',
      en: 'Signed in',
      translations: {'uk': 'Вхід виконано'},
    ),
    LocalizedText(
      'notSignedIn',
      en: 'Not signed in',
      translations: {'uk': 'Вхід не виконано'},
    ),
  ]);

  /// The name of the route of the sign-in, the target of both guards.
  static const _route = 'signIn';

  static const _folder = 'features/sign_in';

  /// The file with the functions of the guards.
  static const _guards = ImportRef.app('$_folder/sign_in_guards.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sign-in, sign-up and password reset with an email',
        kind: ModuleKinds.feature,
        requires: {authRole, settingsScreenRole},
        uses: {localizationRole},
        variants: Variants(
          role: stateManagementRole,
          // Each variant imports the package of its provider, whose
          // constraint the provider owns.
          byProvider: {blocVariant: _bloc, riverpodVariant: _riverpod},
        ),
      );

  /// The screens with their state in cubits, and what the note of the
  /// module says of them.
  static List<Contribution> _bloc(ModuleContext context) => [
        BrickContribution(signInBlocBundle),
        const PubspecContribution.hosted('flutter_bloc', 'any'),
        // Who uses the app, for every widget of the app.
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'BlocProvider(create: (_) => createSessionCubit(), child: ',
            ')',
            imports: [
              ImportRef(
                'package:flutter_bloc/flutter_bloc.dart',
                show: ['BlocProvider'],
              ),
              ImportRef.app(
                '$_folder/sign_in_composition.dart',
                show: ['createSessionCubit'],
              ),
            ],
          ),
        ),
        AppEntryRole.agentSections.entry(
          agentHeading,
          AgentNote(blocAgentNote),
        ),
      ];

  /// The screens with their state in providers, and what the note of the
  /// module says of them.
  static List<Contribution> _riverpod(ModuleContext context) => [
        BrickContribution(signInRiverpodBundle),
        const PubspecContribution.hosted('flutter_riverpod', 'any'),
        AppEntryRole.agentSections.entry(
          agentHeading,
          AgentNote(riverpodAgentNote),
        ),
      ];

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          signInBundle,
          vars: {
            'app_symbol': SmfNames.dartString(
              SmfNames.elementSymbolOf(context.appName),
            ),
            'app_number': SmfNames.elementNumberOf(context.appName),
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
                  'SignInScreen',
                  import: ImportRef.app('$_folder/sign_in_screen.dart'),
                ),
                children: [
                  Route(
                    'sign_up',
                    name: 'signUp',
                    screen: ScreenRef(
                      'SignUpScreen',
                      import: ImportRef.app('$_folder/sign_up_screen.dart'),
                    ),
                  ),
                  Route(
                    'reset_password',
                    name: 'resetPassword',
                    screen: ScreenRef(
                      'ResetPasswordScreen',
                      import: ImportRef.app(
                        '$_folder/reset_password_screen.dart',
                      ),
                    ),
                  ),
                ],
              ),
              // For the user of an account only. It is shown over the
              // screen that the user asked for it on, and is no destination
              // of the main navigation.
              Route(
                '/account',
                name: 'account',
                screen: ScreenRef(
                  'AccountScreen',
                  import: ImportRef.app('$_folder/account_screen.dart'),
                ),
                conditions: [AuthRole.account],
              ),
            ],
            guards: [
              // After a sign-out, the next user starts on the screen that
              // the app starts on.
              RouteGuard(
                name: gate,
                allows: FunctionRef('signInAllowsApp', import: _guards),
                redirectTo: _route,
                stage: GuardStage.identity,
                resumes: false,
              ),
              RouteGuard(
                name: accountGuard,
                allows: FunctionRef('signInHasAccount', import: _guards),
                redirectTo: _route,
                stage: GuardStage.identity,
                resumes: false,
                condition: AuthRole.account,
              ),
            ],
          ),
        ),
        // The entrance to the screen of the account.
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef(
              'AccountSetting',
              import: ImportRef.app('$_folder/account_setting.dart'),
            ),
          ),
        ),
        localizationRole.data(texts),
        AppEntryRole.agentSections.entry(agentHeading, AgentNote(agentNote)),
      ];
}
