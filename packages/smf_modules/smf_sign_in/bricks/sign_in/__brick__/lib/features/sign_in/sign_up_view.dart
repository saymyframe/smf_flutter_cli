import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/sign_in_methods.dart';
import 'sign_in_page.dart';
import 'sign_in_widgets.dart';

/// What the screen that creates an account shows: a button for each way to
/// sign in of the app that works on this platform, the form with the email
/// address and the password of the new account, and the way back to the
/// sign-in.
///
/// It keeps the form and what the user types, and nothing of the sign-up
/// itself: the screen gives it the state of the calls and takes what the
/// user asks for. So it is the same whichever way the app manages state.
class SignUpView extends StatefulWidget {
  /// Creates the view.
  const SignUpView({
    required this.busy,
    required this.failure,
    required this.method,
    required this.onSubmit,
    required this.onContinueWith,
    required this.onSignIn,
    super.key,
  });

  /// Whether a call of the screen is on its way: the sign-up of the form, or
  /// the call of [method].
  final bool busy;

  /// Why the last call failed, or `null` if none did.
  final AuthFailure? failure;

  /// The way to sign in whose call is on its way or failed last, or `null`
  /// for the call of the form.
  final SignInMethod? method;

  /// Creates the account with what the form has, once the form has both.
  final void Function(String email, String password) onSubmit;

  /// Signs in with a way to sign in of the app, whose button the user
  /// tapped.
  final void Function(SignInMethod method) onContinueWith;

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
    final methods = signInMethodsHere();
    // The failure of a call shows where the user made the call.
    final method = widget.method;
    return AuthPage(
      title: {{{text_sign_up_title}}},
      intro: methods.isEmpty
          ? {{{text_sign_up_intro}}}
          : {{{text_sign_up_methods_intro}}},
      children: [
        // Above the form, so that a phone shows them without a scroll.
        if (methods.isNotEmpty)
          SignInMethods(
            methods: methods,
            busy: widget.busy,
            method: method,
            failure: method == null ? null : widget.failure,
            onPressed: widget.onContinueWith,
          ),
        // While a call is on its way, the form takes no input: no tap, and
        // no typing into a field that has the focus.
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
                      AutofillHints.email,
                      AutofillHints.newUsername,
                    ],
                  ),
                  const SizedBox(height: 16),
                  // The device offers a new password, and to keep it.
                  PasswordField(
                    controller: _password,
                    readOnly: widget.busy,
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
            FailureMessage(method == null ? widget.failure : null),
            SubmitButton(
              label: {{{text_sign_up_submit}}},
              busy: widget.busy && method == null,
              onPressed: widget.busy && method != null ? null : _submit,
            ),
            const SizedBox(height: 4),
            OtherScreenAction(
              label: {{{text_have_account}}},
              onPressed: widget.busy ? null : widget.onSignIn,
            ),
          ],
        ),
      ],
    );
  }
}
