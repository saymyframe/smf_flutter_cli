import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/router/navigation.dart';
import 'sign_in_composition.dart';
import 'sign_in_cubit.dart';
import 'sign_in_state.dart';
import 'sign_in_view.dart';

/// The screen of the sign-in: the [SignInView] with the state of a
/// [SignInCubit].
///
/// It does not navigate once the user is signed in, and nothing navigates
/// to it: the router shows it while a guard of the sign-in does not allow,
/// and leaves it once the user is signed in.
{{{smf_router__screen_annotations__sign_in__sign_in_screen}}}
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
        onSubmit: (email, password) => context.read<SignInCubit>().signIn(
          email: email,
          password: password,
        ),
        onCreateAccount: () => context.nav.signIn.signUp().push<void>(),
        onForgotPassword: () => context.nav.signIn.resetPassword().push<void>(),
      ),
    ),
  );
}
