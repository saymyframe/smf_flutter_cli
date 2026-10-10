import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_page.dart';
import 'sign_in_widgets.dart';

/// What the screen that resets a password shows: the form with the email
/// address of an account, and, once the message with the link is sent, the
/// address that it went to and the way back to the sign-in.
///
/// It keeps the form and what the user types, and nothing of the call
/// itself: the screen gives it the state of the call and takes what the
/// user asks for. So it is the same whichever way the app manages state.
class ResetPasswordView extends StatefulWidget {
  /// Creates the view.
  const ResetPasswordView({
    required this.busy,
    required this.failure,
    required this.sentTo,
    required this.onSubmit,
    required this.onSignIn,
    super.key,
  });

  /// Whether the message is on its way.
  final bool busy;

  /// Why the message was not sent, or `null` if nothing failed.
  final AuthFailure? failure;

  /// The address that the message was sent to, or `null` before it is
  /// sent.
  final String? sentTo;

  /// Sends the message to the address that the form has.
  final void Function(String email) onSubmit;

  /// Leads back to the sign-in.
  final VoidCallback onSignIn;

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  /// Whether the user has submitted the form: from then on it tells of a
  /// mistake as the user types.
  var _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy) return;
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    widget.onSubmit(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = widget.sentTo;
    if (sentTo != null) {
      // A page of its own, which rises in as the form did.
      return AuthPage(
        key: const ValueKey('sent'),
        icon: Icons.mark_email_read_outlined,
        title: {{{text_reset_sent_title}}},
        intro: {{{text_reset_sent}}},
        children: [
          EmailAddress(sentTo),
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: FilledButton(
              onPressed: widget.onSignIn,
              child: Text(
                {{{text_back_to_sign_in}}},
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return AuthPage(
      title: {{{text_reset_title}}},
      intro: {{{text_reset_intro}}},
      children: [
        // While the message is on its way, the form takes no input.
        AbsorbPointer(
          absorbing: widget.busy,
          child: Form(
            key: _form,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: EmailField(
              controller: _email,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            FailureMessage(widget.failure),
            SubmitButton(
              label: {{{text_send_link}}},
              busy: widget.busy,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
