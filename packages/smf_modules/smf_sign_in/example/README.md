# Generate a Flutter app with sign-in screens

`sign_in` is the feature with the sign-in screens of the apps that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) generates. On its screens a user signs in with an email address and a password, creates an account, and resets a password. The sign-in and the sign-up also have a button for each way to sign in that another module adds, such as `google_sign_in`. On the screen of the account, the user signs out or deletes the account. Choose it with `-m`, here with the start screen `home`, BLoC for the state of the screens, and `bottom_tabs`, which provides the layout role, the main navigation of the app:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,sign_in,bloc,bottom_tabs --no-input
```

The screens need a router, a module that provides sign-in, a settings screen and a module that manages state. `smf create` adds a module when it is the only one that provides what another one requires, and says which module needs it.

The module writes its files into `lib/features/sign_in/`. The look of a screen is a view, a plain Flutter widget. The screen gives the view the state of a cubit:

```dart
class SignInScreen extends StatelessWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createSignInCubit(),
    child: BlocBuilder<SignInCubit, AuthActionState>(
      builder: (context, state) => SignInView(
        busy: state.busy,
        failure: state.failure,
        method: state.method,
        onSubmit: (email, password) => context.read<SignInCubit>().signIn(
          email: email,
          password: password,
        ),
        onContinueWith: context.read<SignInCubit>().continueWith,
        onCreateAccount: () => context.nav.signIn.signUp().push<void>(),
        onForgotPassword: () => context.nav.signIn.resetPassword().push<void>(),
      ),
    ),
  );
}
```

`SignInCubit` signs in through `appSession`, the session of the app. Its state tells the view whether a call is on its way, which one, and why the last one failed. A button of a way to sign in calls `continueWith`. After a sign-in that succeeded the state stays busy for as long as the session has the account, since the router takes the screen away then:

```dart
  Future<void> signIn({required String email, required String password}) =>
      _run(() async {
        await _session.signIn(email: email, password: password);
        return true;
      });

  /// Signs in with [method], a way to sign in of the app: asks its identity
  /// provider for a credential, with a sheet of its own, and gives it to
  /// the session.
  ///
  /// When the user closes the sheet, the state is again as it was before.
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy for as long as the session has the account.
  Future<void> continueWith(SignInMethod method) =>
      _run(() => continueWithMethod(_session, method), method: method);
```

With `riverpod` in place of `bloc` in the command, the same screen watches a provider. `SignInView` and the other files of the look are the same:

```dart
class SignInScreen extends ConsumerWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInProvider);
    return SignInView(
      busy: state.busy,
      failure: state.failure,
      method: state.method,
      onSubmit: (email, password) => ref
          .read(signInProvider.notifier)
          .signIn(email: email, password: password),
      onContinueWith: ref.read(signInProvider.notifier).continueWith,
      onCreateAccount: () => context.nav.signIn.signUp().push<void>(),
      onForgotPassword: () => context.nav.signIn.resetPassword().push<void>(),
    );
  }
}
```

Neither screen navigates once the user is signed in, and the cubit does not tell the screen that the sign-in succeeded. Two guards of the routes read the session, with the functions of `sign_in_guards.dart`:

```dart
ValueListenable<bool> signInAllowsApp() => appSession.allowsApp;
```

```dart
ValueListenable<bool> signInHasAccount() => appSession.hasAccount;
```

While the first is false, the router shows the sign-in at `/sign_in` in place of every other screen. In an app that nobody may use without an account, that lasts until the user is signed in. While the second is false, the router shows the sign-in in place of a route that needs an account, in an app that everyone may use. Once the user is signed in to an account, both are true, and the router leaves the sign-in. On a first launch, it then shows the start screen at `/home`.

The settings screen of the app gets an entry for the account. It reads who uses the app from `SessionCubit`, which the module puts around the root of the app, so it follows a sign-in and a sign-out. A tap opens the screen of the account at `/sign_in/account`:

```dart
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    return AccountSettingRow(
      signedIn: session is AccountSession,
      email: session is AccountSession ? session.email : null,
      onTap: () => context.nav.signIn.account().push<void>(),
    );
  }
```

That route needs an account. For a user without one, in an app that everyone may use, the router opens the sign-in over the settings screen first, and shows the screen of the account once the user is signed in. With `riverpod`, a widget reads the same from `ref.watch(sessionProvider)`.

The tabs of `bottom_tabs` lead to the settings screen. In an app without a main navigation, a screen of yours opens it, or opens the account directly with `context.nav.signIn.account().push<void>()`.

The fields and the buttons of the screens are those of the theme of the app, so they change with the theme. The texts are in English and in Ukrainian, and a failure of sign-in has a text for each of its reasons, in `authFailureText()` of `sign_in_widgets.dart`.

The documentation has more on [the sign-in module](https://doc.saymyframe.com/modules/sign-in) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
