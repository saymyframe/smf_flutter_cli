import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_page.dart';
import 'sign_in_widgets.dart';

/// What the screen of the sign-in shows: the form with the email address
/// and the password of an account, and the ways to the screens that create
/// an account and reset a password.
///
/// It keeps the form and what the user types, and nothing of the sign-in
/// itself: the screen gives it the state of the call and takes what the
/// user asks for. So it is the same whichever way the app manages state.
class SignInView extends StatefulWidget {
  /// Creates the view.
  const SignInView({
    required this.busy,
    required this.failure,
    required this.onSubmit,
    required this.onCreateAccount,
    required this.onForgotPassword,
    super.key,
  });

  /// Whether the sign-in is on its way.
  final bool busy;

  /// Why the last sign-in failed, or `null` if none did.
  final AuthFailure? failure;

  /// Signs in with what the form has, once the form has both.
  final void Function(String email, String password) onSubmit;

  /// Shows the screen that creates an account.
  final VoidCallback onCreateAccount;

  /// Shows the screen that resets a password.
  final VoidCallback onForgotPassword;

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
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
      title: {{{text_title}}},
      intro: {{{text_intro}}},
      children: [
        // While the sign-in is on its way, the form takes no input: no tap,
        // and no typing into a field that has the focus.
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
                    readOnly: widget.busy,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    readOnly: widget.busy,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: _submit,
                  ),
                  // It belongs to the password: at the end of its field.
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      // Nor a key: the action takes none while busy.
                      onPressed: widget.busy ? null : widget.onForgotPassword,
                      child: Text(
                        {{{text_forgot_password}}},
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            FailureMessage(widget.failure),
            SubmitButton(
              label: {{{text_submit}}},
              busy: widget.busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 4),
            // The way to the other screen, as on the screen that creates an
            // account: in the middle below the button, apart from what
            // belongs to the password above it.
            OtherScreenAction(
              label: {{{text_create_account}}},
              onPressed: widget.busy ? null : widget.onCreateAccount,
            ),
          ],
        ),
      ],
    );
  }
}
