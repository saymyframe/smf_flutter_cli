import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the guide for coding agents
/// of the app.
const agentHeading = 'Sign-in';

/// The note of the module in the guide for coding agents, in every app with
/// the module: where its screens are and what shows them, which of its
/// files are the look of a screen and which are its state, that its fields
/// and buttons are those of the theme, but for the one colour of the
/// action that leads to the other screen, which widget keeps the words of
/// a title and of a label whole, where a failure gets its text,
/// what a widget test minds while a call is on its way, and where the
/// screen of the account and its entry on the settings screen are, with
/// what closes that screen.
///
/// What a router does with a guard of the routes is for the router role to
/// tell, and what the session of the app does is for the auth role: each
/// has a section of its own in the guide of every app with the module.
const agentNote = '''
- The sign-in is three screens in `lib/features/sign_in/`: `SignInScreen`, the route `sign_in.signIn` at `/sign_in`, and over it `SignUpScreen` at `/sign_in/sign_up` and `ResetPasswordScreen` at `/sign_in/reset_password`. Two guards of `${RouterRole.routeGuards}` show them, with the functions of `lib/features/sign_in/sign_in_guards.dart`. `sign_in.gate` reads `appSession.allowsApp` and shows the sign-in in place of every other screen. `sign_in.hasAccount` reads `appSession.hasAccount` and shows it in place of a route that needs an account.
- A screen of the sign-in neither closes itself nor navigates once the user is signed in. It signs in or up through its state. The session changes then, and the router leaves the sign-in. While `authMode` is `AuthMode.required`, no code navigates to the sign-in either: the gate shows it. In the other modes, a screen that offers to sign in opens it with `context.nav.signIn.signIn().push<void>()`, so that back leads back.
- The look of a screen and its state are in different files. The look is `SignInView`, `SignUpView` and `ResetPasswordView`, each in a file of its name, such as `lib/features/sign_in/sign_in_view.dart`. They share `AuthPage` of `lib/features/sign_in/sign_in_page.dart`, which is the frame of a screen, and the fields and buttons of `lib/features/sign_in/sign_in_widgets.dart`. All of them are plain Flutter widgets: a view gets the state of its call and callbacks, and imports nothing that manages state. The file of a screen, such as `lib/features/sign_in/sign_in_screen.dart`, only gives its view the state.
- The fields, the buttons and the cards of the screens are those of the theme of the app. These files give a field no colour, border or padding, so for another look of a field, change the theme of the app. `OtherScreenAction`, the way from the sign-in to the sign-up and back, is a text button of the theme with one colour of its own, `colorScheme.secondary`.
- The title of a page and the label of each button are each a `WholeWords` of `lib/features/sign_in/sign_in_widgets.dart`, not a `Text`. It breaks a text between its words and never inside one. Where the longest word would not fit, as on a narrow phone with a large text size, the text is only as large as that word allows. Use it for the label of a new button of the feature too.
- That state is an `AuthActionState` or a `ResetPasswordState` of `lib/features/sign_in/sign_in_state.dart`. It stays busy once a sign-in or a sign-up succeeded, for as long as the session has the account, since the router leaves the screen then. When the session has no account again before that, the form is back.
- A failure gets its text in `authFailureText()` of `lib/features/sign_in/sign_in_widgets.dart`, which has a text for every `AuthFailureReason`. `FailureMessage` shows that text, and the `developerHint` of the failure in debug mode only.
- While a call is on its way, `SubmitButton` spins. A widget test that waits with `pumpAndSettle()` returns only once the call has ended, so until then it shows frames with `pump()`.
- The screen of the account is `AccountScreen`, the route `sign_in.account` at `/sign_in/account`, with its look in `AccountView` of `lib/features/sign_in/account_view.dart`. The route needs an account, so for a user without one the router opens the sign-in over the page first. `AccountSetting` of `lib/features/sign_in/account_setting.dart` is the entry of the account on the settings screen. It opens the screen with `context.nav.signIn.account().push<void>()`.
- The screen of the account signs out and deletes the account through its state, an `AccountState`. It neither closes itself nor navigates after that: the router closes its page, or shows the sign-in in place of every screen. The state stays busy after a call that succeeded for as long as the session has no account. `confirmDeleteAccount()` asks in a sheet first, and the sheet is closed before the account is deleted. `DestructiveAction` is a text button of the theme in the colour `colorScheme.error`.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in cubits: where the state of a screen is, which file gives it
/// the session, and how a widget reads who uses the app.
const blocAgentNote = '''
- The state of each screen is a cubit in a file next to it: `SignInCubit`, `SignUpCubit`, `ResetPasswordCubit` and `AccountCubit`. The screen provides its cubit and builds its view from the state. A cubit takes the session through its constructor, so a test creates one with an `AppSessionController` of its own. `lib/features/sign_in/sign_in_composition.dart` creates the cubits with `appSession`, and apart from the file of the guards, no other file of the feature names `appSession`.
- A widget reads who uses the app with `context.watch<SessionCubit>().state`, an `AppSession`. The root of the app provides the `SessionCubit` of `lib/features/sign_in/session_cubit.dart`, which follows `appSession`.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in providers: where the state of a screen is, which provider
/// gives it the session, and how a widget reads who uses the app.
const riverpodAgentNote = '''
- The state of each screen is a provider in a file next to it, with its `Notifier`: `signInProvider`, `signUpProvider`, `resetPasswordProvider` and `accountProvider`. Each lasts as long as its screen. They sign in through `appSessionProvider` of `lib/features/sign_in/session_provider.dart`, which a test overrides with an `AppSessionController` of its own. Apart from the file of the guards, that file is the only one of the feature that names `appSession`.
- A provider is one for the app, so two pages of one screen that are open at once show the same state.
- A widget reads who uses the app with `ref.watch(sessionProvider)`, an `AppSession`. `sessionProvider` of `lib/features/sign_in/session_provider.dart` follows `appSession`.
''';
