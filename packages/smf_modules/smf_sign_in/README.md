# smf_sign_in

The SMF module of the sign-in screens of the app. It is a feature: three screens with their routes, which the module that provides the router renders, and two guards of the routes, which that module asks. On the screens, a user signs in to an account with an email address and a password, creates an account, and asks for the message that resets a password.

The module keeps no accounts. It requires a module that provides sign-in, and reaches it only through `appSession`, the session of the app, so the screens are the same whichever module that is.

## The screens

The sign-in is at `/sign_in`. It has a field for the email address and one for the password, Forgot password?, the button that signs in, and Create account.

Create account leads to the sign-up at `/sign_in/sign_up`, with the same two fields for a new account. There the device may suggest a password and offer to keep it.

Forgot password? leads to the password reset at `/sign_in/reset_password`, which asks for the email address of an account. Once the message with the link is sent, the screen shows the address that it went to. It says the same whether the address has an account or not, so nobody learns from the app which addresses have one.

Each screen shows the cell of the app, with the symbol that SMF makes from its name, `Ma` for `my_app`, next to the cells of a table that light up one after another. Below it are a title, a line of text and the form. A field has its label above it, and the password field has a button that shows the password. The button that submits is as wide as the form. While its call is on its way, it spins and the form takes no input: a field takes no typing, though one that has the focus keeps it, and the actions of the screen take neither a tap nor a key. A failure shows above the button, in a text of its own for each reason, such as a wrong password or no connection.

The fields, the buttons and the cards of the screens are those of the theme of the app, in its light and in its dark mode. The screens give a field no colour, border or padding of their own, so for another look of the fields, change the theme of the app. The cells of the picture, which a screen draws itself, take their colours from the theme too.

One button has a colour of its own. The action that leads to the other screen is Create account on the sign-in and I already have an account on the sign-up. It is a text button of the theme in the accent of the colour scheme, `colorScheme.secondary`, because a theme keeps its text buttons quiet and this one is the second way on from its screen. Forgot password? stays as the theme has it.

The parts of a screen rise in one after another, once. On a device that asks for less motion, they are there at once, and a busy button is disabled and keeps its label. A screen scrolls when it is too small for what it shows, as with the keyboard open or with a large text size on a small phone, and the labels and the buttons grow with their texts. A title grows only by half. A title and the label of a button break between their words and never inside one. Where the longest word would not fit, as on a narrow phone with a large text size, the text is only as large as that word allows. The letters in the cell keep their size, since they are part of a picture. A screen reader announces the title as a header, each field by its label, and a failure when it appears.

## Look and state

The module generates its files in `lib/features/sign_in/`. The look of the screens is the same in every app:

- `sign_in_view.dart`, `sign_up_view.dart` and `reset_password_view.dart` have `SignInView`, `SignUpView` and `ResetPasswordView`. A view is a plain Flutter widget: it keeps its form, gets the state of its call, and takes callbacks for what the user asks for.
- `sign_in_page.dart` has `AuthPage`, the frame of a screen: the cell, the title, the line of text, and the entrance.
- `sign_in_widgets.dart` has the fields, the button that submits, `OtherScreenAction` for the way to the other screen, and `FailureMessage`. It also has `authFailureText()`, which has a text for every reason of a failure, and `WholeWords`, the text of a title or of the label of a button, which keeps its words whole.
- `sign_in_state.dart` has `AuthActionState` and `ResetPasswordState`, the values of the state of a screen.
- `sign_in_guards.dart` has the functions of the two guards.

What keeps the state of a screen depends on the module that manages state in the app, so the module has a variant for each:

- With `bloc`, each screen has a cubit: `SignInCubit`, `SignUpCubit` and `ResetPasswordCubit`. A screen provides its cubit and builds its view from the state. `sign_in_composition.dart` creates the cubits with `appSession`.
- With `riverpod`, each screen has a provider that lasts as long as the screen: `signInProvider`, `signUpProvider` and `resetPasswordProvider`. They reach the session through `appSessionProvider` in `session_provider.dart`.

The screens are `SignInScreen`, `SignUpScreen` and `ResetPasswordScreen`, in `sign_in_screen.dart`, `sign_up_screen.dart` and `reset_password_screen.dart` in both variants. A screen only gives its view the state. The module adds the package of the state manager to the app, in the version that the module of that state manager asks for, and no other package.

While a call is on its way, the state of a screen is busy and takes no second call. A failure ends that, and the state has the failure. A sign-in or a sign-up that succeeded leaves the state busy for as long as the session has the account: the user is signed in then, and the router takes the screen away. When the session has no account again before that, as when code of the app signs the user out at once, the form is back.

With `bloc`, each page of a screen has a cubit of its own. With `riverpod`, a provider is one for the app, so two pages of one screen that are open at once show the same state.

## What shows the sign-in

The screens neither close themselves nor navigate once the user is signed in. The module declares two guards of the routes, and the router shows the sign-in and leaves it by what they say:

- `sign_in.gate` reads `appSession.allowsApp`. In an app that nobody may use without an account, the router shows the sign-in in place of every other screen until the user is signed in.
- `sign_in.hasAccount` reads `appSession.hasAccount`. In an app that everyone may use, a request for a route that needs an account opens the sign-in over the page that the user is on, and the rest of the app stays open. Back returns to that page. Once the user is signed in, the router closes the sign-in and shows the route that was asked for.

Which of the two keeps a user out is up to the sign-in mode of the app, which `smf create` asks for. The code of the module is the same in every mode.

In an app that everyone may use, a screen may also offer to sign in. It opens the sign-in with `context.nav.signIn.signIn().push<void>()`, so that back leads back. In an app that needs an account, no code navigates to the sign-in: the gate shows it.

Once the user is signed in to an account, both guards allow, and the router leaves the sign-in. From then on, a navigation to one of the three routes, such as a link, shows the screen that the app starts on. After a sign-out in an app that needs an account, the router shows the sign-in again. The next user then starts on the screen that the app starts on, wherever the last user was.

Both guards have the stage `identity`. In an app with a guard of a first launch, such as that of an onboarding, that one comes first, whichever order the modules were named in.

## Texts

The texts of the screens are in English and in Ukrainian. In an app with a module that provides localization, they follow the language of the app. An app without such a module shows them in English.

Every reason of a failure has a text of its own. When sign-in is not set up at the provider, the user reads only that sign-in is unavailable. What is wrong is in the `developerHint` of the failure, which the screen shows below the text in debug mode only.

## In your tests

A cubit takes the session through its constructor, and a provider reaches it through `appSessionProvider`, which a test overrides. So a test of the state of a screen gives it an `AppSessionController` of its own, with a service that the test scripts.

The button that submits spins for as long as its call takes. A widget test that waits for a screen with `pumpAndSettle()` returns only once the call has ended, so while a call is on its way, such a test shows frames with `pump()`.

A page starts its entrance when it is first built. A widget test that starts the app in real time, as with `tester.runAsync()`, does so once in its file: a second start in the same file fails an assertion of Flutter in that animation.

## Use with the SMF CLI

`smf create` asks which features the app has. To choose this one without the question, here with a start screen and BLoC:

```bash
smf create my_app -m home,sign_in,bloc
```

The feature requires a router, a module that provides sign-in and a module that manages state. `smf create` adds each when only one module provides it, and asks, or takes it from `-m`, when several do.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The sign-in module](https://doc.saymyframe.com/modules/sign-in)
- [Navigation](https://doc.saymyframe.com/guides/navigation)
