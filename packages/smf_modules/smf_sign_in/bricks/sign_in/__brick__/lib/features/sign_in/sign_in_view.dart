import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/sign_in_methods.dart';
import 'sign_in_page.dart';
import 'sign_in_widgets.dart';

/// What the screen of the sign-in shows: a button for each way to sign in
/// of the app that works on this platform, the form with the email address
/// and the password of an account, and the ways to the screens that create
/// an account and reset a password.
///
/// It keeps the form and what the user types, and nothing of the sign-in
/// itself: the screen gives it the state of the calls and takes what the
/// user asks for. So it is the same whichever way the app manages state.
class SignInView extends StatefulWidget {
  /// Creates the view.
  const SignInView({
    required this.busy,
    required this.failure,
    required this.method,
    required this.onSubmit,
    required this.onContinueWith,
    required this.onCreateAccount,
    required this.onForgotPassword,
    super.key,
  });

  /// Whether a call of the screen is on its way: the sign-in of the form, or
  /// the call of [method].
  final bool busy;

  /// Why the last call failed, or `null` if none did.
  final AuthFailure? failure;

  /// The way to sign in whose call is on its way or failed last, or `null`
  /// for the call of the form.
  final SignInMethod? method;

  /// Signs in with what the form has, once the form has both.
  final void Function(String email, String password) onSubmit;

  /// Signs in with a way to sign in of the app, whose button the user
  /// tapped.
  final void Function(SignInMethod method) onContinueWith;

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
    final methods = signInMethodsHere();
    // The failure of a call shows where the user made the call.
    final method = widget.method;
    return AuthPage(
      title: {{{text_title}}},
      intro: methods.isEmpty
          ? {{{text_intro}}}
          : {{{text_methods_intro}}},
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
                      child: WholeWords(
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
            FailureMessage(method == null ? widget.failure : null),
            SubmitButton(
              label: {{{text_submit}}},
              busy: widget.busy && method == null,
              onPressed: widget.busy && method != null ? null : _submit,
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
