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
- No code navigates to the sign-in or away from it. A screen only signs in: the session changes, and the router leaves the sign-in. A sign-out shows the sign-in in the same way.
- The look of a screen and its state are in different files. The look is `SignInView`, `SignUpView` and `ResetPasswordView`, each in a file of its name, such as `lib/features/sign_in/sign_in_view.dart`, and the widgets that they share in `lib/features/sign_in/sign_in_widgets.dart`. They are plain Flutter widgets: a view gets the state of its call and callbacks, and imports nothing that manages state. Change these files for another look. The file of a screen, such as `lib/features/sign_in/sign_in_screen.dart`, only gives its view the state.
- `AuthActionState` and `ResetPasswordState` in `lib/features/sign_in/sign_in_state.dart` are the values of that state. The state of a screen stays busy once its call succeeded, since the router leaves the screen then.
- A failure gets its text in `authFailureText()` of `lib/features/sign_in/sign_in_widgets.dart`, which has a text for every `AuthFailureReason`. `FailureMessage` shows it, and the `developerHint` of the failure in debug mode only.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in cubits: where the state of a screen is, which file gives it the
/// session, and how a widget reads who uses the app.
const blocAgentNote = '''
- The state of each screen is a cubit in a file next to it: `SignInCubit`, `SignUpCubit` and `ResetPasswordCubit`. The screen provides its cubit and builds its view from the state. `lib/features/sign_in/sign_in_composition.dart` creates the cubits with `appSession`, and no other file of the screens names it. A test creates a cubit with an `AppSessionController` of its own.
- A widget reads who uses the app with `context.watch<SessionCubit>().state`, an `AppSession`. `SessionCubit` in `lib/features/sign_in/session_cubit.dart` follows `appSession`, and the root of the app provides it to every widget.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in providers: where the state of a screen is, which provider gives
/// it the session, and how a widget reads who uses the app.
const riverpodAgentNote = '''
- The state of each screen is a provider in a file next to it, with its `Notifier`: `signInProvider`, `signUpProvider` and `resetPasswordProvider`. Each lasts as long as its screen. They sign in through `appSessionProvider` of `lib/features/sign_in/session_provider.dart`, and no other file of the screens names `appSession`. A test overrides that provider with an `AppSessionController` of its own.
- A widget reads who uses the app with `ref.watch(sessionProvider)`, an `AppSession`. `sessionProvider` in that file follows `appSession`.
''';
