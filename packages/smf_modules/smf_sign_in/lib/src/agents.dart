import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the guide for coding agents
/// of the app.
const agentHeading = 'Sign-in';

/// The note of the module in the guide for coding agents, in every app with
/// the module: where its screens are and what shows them, which of its
/// files are the look of a screen and which are its state, and where a
/// failure gets its text.
///
/// What a router does with a guard of the routes is for the router role to
/// tell, and what the session of the app does is for the auth role: each
/// has a section of its own in the guide of every app with the module.
const agentNote = '''
- The sign-in is three screens in `lib/features/sign_in/`: `SignInScreen`, the route `sign_in.signIn` at `/sign_in`, and over it `SignUpScreen` at `/sign_in/sign-up` and `ResetPasswordScreen` at `/sign_in/reset-password`. Two guards of `${RouterRole.routeGuards}` show them, with the functions of `lib/features/sign_in/sign_in_guards.dart`. `sign_in.gate` reads `appSession.allowsApp` and shows the sign-in in place of every other screen. `sign_in.account` reads `appSession.hasAccount` and shows it in place of a route that needs an account.
- No code navigates to the sign-in or away from it. A screen signs in or up through its state. The session changes then, and the router leaves the sign-in.
- The look of a screen and its state are in different files. The look is `SignInView`, `SignUpView` and `ResetPasswordView`, each in a file of its name, such as `lib/features/sign_in/sign_in_view.dart`. The widgets that they share are in `lib/features/sign_in/sign_in_widgets.dart`. All of them are plain Flutter widgets: a view gets the state of its call and callbacks, and imports nothing that manages state. Change these files for another look. The file of a screen, such as `lib/features/sign_in/sign_in_screen.dart`, only gives its view the state.
- That state is an `AuthActionState` or a `ResetPasswordState` of `lib/features/sign_in/sign_in_state.dart`. It stays busy once a sign-in or a sign-up succeeded, since the router leaves the screen then.
- A failure gets its text in `authFailureText()` of `lib/features/sign_in/sign_in_widgets.dart`, which has a text for every `AuthFailureReason`. `FailureMessage` shows that text, and the `developerHint` of the failure in debug mode only.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in cubits: where the state of a screen is, which file gives it the
/// session, and how a widget reads who uses the app.
const blocAgentNote = '''
- The state of each screen is a cubit in a file next to it: `SignInCubit`, `SignUpCubit` and `ResetPasswordCubit`. The screen provides its cubit and builds its view from the state. A cubit takes the session through its constructor, so a test creates one with an `AppSessionController` of its own. `lib/features/sign_in/sign_in_composition.dart` creates the cubits with `appSession`, and apart from the file of the guards, no other file of the feature names `appSession`.
- A widget reads who uses the app with `context.watch<SessionCubit>().state`, an `AppSession`. `SessionCubit` in `lib/features/sign_in/session_cubit.dart` follows `appSession`, and the root of the app provides it to every widget.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in providers: where the state of a screen is, which provider gives
/// it the session, and how a widget reads who uses the app.
const riverpodAgentNote = '''
- The state of each screen is a provider in a file next to it, with its `Notifier`: `signInProvider`, `signUpProvider` and `resetPasswordProvider`. Each lasts as long as its screen. They sign in through `appSessionProvider` of `lib/features/sign_in/session_provider.dart`, which a test overrides with an `AppSessionController` of its own. Apart from the file of the guards, that file is the only one of the feature that names `appSession`.
- A widget reads who uses the app with `ref.watch(sessionProvider)`, an `AppSession`. `sessionProvider` in the same file follows `appSession`.
''';
