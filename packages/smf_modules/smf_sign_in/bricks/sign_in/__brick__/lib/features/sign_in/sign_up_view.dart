import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_page.dart';
import 'sign_in_widgets.dart';

/// What the screen that creates an account shows: the form with the email
/// address and the password of the new account, and the way back to the
/// sign-in.
///
/// It keeps the form and what the user types, and nothing of the sign-up
/// itself: the screen gives it the state of the call and takes what the
/// user asks for. So it is the same whichever way the app manages state.
class SignUpView extends StatefulWidget {
  /// Creates the view.
  const SignUpView({
    required this.busy,
    required this.failure,
    required this.onSubmit,
    required this.onSignIn,
    super.key,
  });

  /// Whether the sign-up is on its way.
  final bool busy;

  /// Why the last sign-up failed, or `null` if none did.
  final AuthFailure? failure;

  /// Creates the account with what the form has, once the form has both.
  final void Function(String email, String password) onSubmit;

  /// Leads back to the sign-in, for a user who has an account.
  final VoidCallback onSignIn;

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Whether the user has submitted the form: from then on it tells of a
  /// mistake as the user types.
  var _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy) return;
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    widget.onSubmit(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: {{{text_sign_up_title}}},
      intro: {{{text_sign_up_intro}}},
      children: [
        // While the sign-up is on its way, the form takes no input.
        AbsorbPointer(
          absorbing: widget.busy,
          child: AutofillGroup(
            child: Form(
              key: _form,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EmailField(
                    controller: _email,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.newUsername,
                    ],
                  ),
                  const SizedBox(height: 16),
                  // The device offers a new password, and to keep it.
                  PasswordField(
                    controller: _password,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            FailureMessage(widget.failure),
            SubmitButton(
              label: {{{text_sign_up_submit}}},
              busy: widget.busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: widget.busy ? null : widget.onSignIn,
              child: Text(
                {{{text_have_account}}},
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
