import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'reset_password_cubit.dart';
import 'reset_password_view.dart';
import 'sign_in_composition.dart';
import 'sign_in_state.dart';

/// The screen that resets a password: the [ResetPasswordView] with the
/// state of a [ResetPasswordCubit].
{{{smf_router__screen_annotations__sign_in__reset_password_screen}}}
class ResetPasswordScreen extends StatelessWidget {
  /// Creates the screen.
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createResetPasswordCubit(),
    child: BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
      builder: (context, state) => ResetPasswordView(
        busy: state.busy,
        failure: state.failure,
        sentTo: state.sentTo,
        onSubmit: (email) => context.read<ResetPasswordCubit>().send(email),
        // Closes this page. The screen of the sign-in is the page below
        // it, whether that one is the first page of the app or shown over
        // another screen.
        onSignIn: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}
