import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sign_up_notifier.dart';
import 'sign_up_view.dart';

/// The screen that creates an account: the [SignUpView] with the state of
/// [signUpProvider].
///
/// It does not navigate once the user has an account: the router leaves
/// the sign-in then.
{{{smf_router__screen_annotations__sign_in__sign_up_screen}}}
class SignUpScreen extends ConsumerWidget {
  /// Creates the screen.
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signUpProvider);
    return SignUpView(
      busy: state.busy,
      failure: state.failure,
      onSubmit: (email, password) => ref
          .read(signUpProvider.notifier)
          .signUp(email: email, password: password),
      // Closes this page. The screen of the sign-in is the page below it,
      // whether that one is the first page of the app or shown over
      // another screen.
      onSignIn: () => Navigator.of(context).maybePop(),
    );
  }
}
