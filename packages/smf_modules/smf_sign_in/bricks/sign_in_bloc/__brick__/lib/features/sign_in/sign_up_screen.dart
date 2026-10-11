import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'sign_in_composition.dart';
import 'sign_in_state.dart';
import 'sign_up_cubit.dart';
import 'sign_up_view.dart';

/// The screen that creates an account: the [SignUpView] with the state of
/// a [SignUpCubit].
///
/// It does not navigate once the user has an account: the router leaves
/// the sign-in then.
{{{smf_router__screen_annotations__sign_in__sign_up_screen}}}
class SignUpScreen extends StatelessWidget {
  /// Creates the screen.
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createSignUpCubit(),
    child: BlocBuilder<SignUpCubit, AuthActionState>(
      builder: (context, state) => SignUpView(
        busy: state.busy,
        failure: state.failure,
        onSubmit: (email, password) => context.read<SignUpCubit>().signUp(
          email: email,
          password: password,
        ),
        // Closes this page. The screen of the sign-in is the page below
        // it, whether that one is the first page of the app or shown over
        // another screen.
        onSignIn: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}
