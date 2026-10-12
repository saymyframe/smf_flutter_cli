import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/navigation.dart';
import 'sign_in_notifier.dart';
import 'sign_in_view.dart';

/// The screen of the sign-in: the [SignInView] with the state of
/// [signInProvider].
///
/// It does not navigate once the user is signed in, and nothing navigates
/// to it: the router shows it while a guard of the sign-in does not allow,
/// and leaves it once the user is signed in.
{{{smf_router__screen_annotations__sign_in__sign_in_screen}}}
class SignInScreen extends ConsumerWidget {
  /// Creates the screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInProvider);
    return SignInView(
      busy: state.busy,
      failure: state.failure,
      onSubmit: (email, password) => ref
          .read(signInProvider.notifier)
          .signIn(email: email, password: password),
      onCreateAccount: () => context.nav.signIn.signUp().push<void>(),
      onForgotPassword: () => context.nav.signIn.resetPassword().push<void>(),
    );
  }
}
