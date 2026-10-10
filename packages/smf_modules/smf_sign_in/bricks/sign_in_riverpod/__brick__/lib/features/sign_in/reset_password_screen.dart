import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reset_password_notifier.dart';
import 'reset_password_view.dart';

/// The screen that resets a password: the [ResetPasswordView] with the
/// state of [resetPasswordProvider].
{{{smf_router__screen_annotations__sign_in__reset_password_screen}}}
class ResetPasswordScreen extends ConsumerWidget {
  /// Creates the screen.
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resetPasswordProvider);
    return ResetPasswordView(
      busy: state.busy,
      failure: state.failure,
      sentTo: state.sentTo,
      onSubmit: (email) =>
          ref.read(resetPasswordProvider.notifier).send(email),
      // The screen of the sign-in is below this one.
      onSignIn: () => Navigator.of(context).maybePop(),
    );
  }
}
