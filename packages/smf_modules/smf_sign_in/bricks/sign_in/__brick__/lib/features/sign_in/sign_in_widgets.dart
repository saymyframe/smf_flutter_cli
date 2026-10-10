import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';

/// A field of a form with its [label] above it. The label takes as many
/// lines as it needs, and a screen reader announces it with the field.
///
/// The field itself is as the theme of the app has its fields: no widget
/// of the sign-in gives a field a colour, a border or a padding.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(label: label, child: child),
      ],
    );
  }
}

/// What every field of the sign-in has of its own: the text of a mistake
/// takes the lines that it needs, as with a large text size, whatever the
/// theme of the app says of its fields.
const _mistakeLines = 5;

/// The field of the email address of a form. It tells the form of an
/// address that is missing or that has no `@`: whether the address is one,
/// the provider of sign-in knows.
class EmailField extends StatelessWidget {
  /// Creates the field.
  const EmailField({
    required this.controller,
    required this.autofillHints,
    this.readOnly = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  /// The controller of the address.
  final TextEditingController controller;

  /// Whether the field takes no typing, as while the call of its form is on
  /// its way. It keeps the focus then, so the user goes on typing once the
  /// call has failed.
  final bool readOnly;

  /// What the field is for the autofill of the device: the address of an
  /// account that exists, or of a new one.
  final List<String> autofillHints;

  /// The button of the keyboard: the next field, unless this is the last.
  final TextInputAction textInputAction;

  /// What the button of the keyboard does on the last field of a form.
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final missing = {{{text_email_required}}};
    final invalid = {{{text_email_invalid}}};
    return _Labelled(
      label: {{{text_email}}},
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: const InputDecoration(errorMaxLines: _mistakeLines),
        keyboardType: TextInputType.emailAddress,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        autocorrect: false,
        enableSuggestions: false,
        onFieldSubmitted: (_) => onSubmitted?.call(),
        validator: (value) {
          final email = value?.trim() ?? '';
          if (email.isEmpty) return missing;
          return email.contains('@') ? null : invalid;
        },
      ),
    );
  }
}

/// The field of the password of a form, with a button that shows the
/// password and hides it again. It tells the form of a password that is
/// missing: which passwords are good enough, the provider of sign-in knows.
class PasswordField extends StatefulWidget {
  /// Creates the field.
  const PasswordField({
    required this.controller,
    required this.autofillHints,
    required this.onSubmitted,
    this.readOnly = false,
    super.key,
  });

  /// The controller of the password.
  final TextEditingController controller;

  /// Whether the field takes no typing, as while the call of its form is on
  /// its way. It keeps the focus then, so the user goes on typing once the
  /// call has failed.
  final bool readOnly;

  /// What the field is for the autofill of the device: the password of an
  /// account, or a new one.
  final List<String> autofillHints;

  /// What the button of the keyboard does: the field is the last of its
  /// form.
  final VoidCallback onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  var _hidden = true;

  @override
  Widget build(BuildContext context) {
    final missing = {{{text_password_required}}};
    return _Labelled(
      label: {{{text_password}}},
      child: TextFormField(
        controller: widget.controller,
        readOnly: widget.readOnly,
        decoration: InputDecoration(
          errorMaxLines: _mistakeLines,
          suffixIcon: IconButton(
            onPressed: () => setState(() => _hidden = !_hidden),
            tooltip: _hidden
                ? {{{text_show_password}}}
                : {{{text_hide_password}}},
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        obscureText: _hidden,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        autofillHints: widget.autofillHints,
        autocorrect: false,
        enableSuggestions: false,
        onFieldSubmitted: (_) => widget.onSubmitted(),
        validator: (value) => value == null || value.isEmpty ? missing : null,
      ),
    );
  }
}

/// The button that submits a form, as wide as the form. While the call of
/// the form is on its way, it shows that it is [busy] and does nothing.
///
/// It spins for as long as the call takes. So a widget test that waits for
/// the screen with `pumpAndSettle()` returns only once the call has ended:
/// while a call is on its way, such a test pumps frames one at a time.
class SubmitButton extends StatelessWidget {
  /// Creates the button.
  const SubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  /// The text of the button, which takes as many lines as it needs.
  final String label;

  /// Whether the call of the form is on its way.
  final bool busy;

  /// Submits the form.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // In an app that asks for less motion, nothing spins: the button is
    // disabled and keeps its label.
    final spins = busy && !MediaQuery.disableAnimationsOf(context);
    return FilledButton(
      // A button that spins keeps its colour.
      onPressed: !busy
          ? onPressed
          : spins
          ? () {}
          : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The label keeps its place, so that the button keeps its size.
          Visibility.maintain(
            visible: !spins,
            child: Text(label, textAlign: TextAlign.center),
          ),
          if (spins)
            // In the colour that the theme of the app gives the label.
            Builder(
              builder: (context) => SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: DefaultTextStyle.of(context).style.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The action of a screen that leads to the other screen of the sign-in:
/// from the sign-in to the screen that creates an account, and from there
/// back.
///
/// It is a text button of the theme of the app with one colour of its own,
/// the accent of the colour scheme. A theme makes a text button quiet,
/// which suits what belongs to a field, such as the way to a forgotten
/// password. This action is the second way on of its screen, so it stands
/// out. Its shape, its text style, its padding and what a touch shows stay
/// those of the theme, and so does the colour of a button that takes no
/// tap, as while the form of the screen submits.
class OtherScreenAction extends StatelessWidget {
  /// Creates the action.
  const OtherScreenAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// The text of the action, which takes as many lines as it needs.
  final String label;

  /// Shows the other screen, or `null` while the action takes no tap.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.fromMap({
        // The theme has the colour of a button that takes no tap.
        WidgetState.disabled: null,
        WidgetState.any: Theme.of(context).colorScheme.secondary,
      }),
    ),
    onPressed: onPressed,
    child: Text(label, textAlign: TextAlign.center),
  );
}

/// Why the last call of a form failed, in the language of the app, or
/// nothing while [failure] is `null`. It takes its place smoothly, and a
/// screen reader announces it when it appears.
///
/// In debug mode it also shows what the provider of sign-in says to the
/// developer of the app, which is no text for a user.
class FailureMessage extends StatelessWidget {
  /// Creates the message of [failure].
  const FailureMessage(this.failure, {super.key});

  /// The failure, or `null` when the last call did not fail.
  final AuthFailure? failure;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    final message = failure == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _Failure(failure),
          );
    // An app that asks for less motion shows the message at once. It does
    // so without an AnimatedSize: one with a duration of zero fails an
    // assertion of Flutter when the size of its child changes.
    if (MediaQuery.disableAnimationsOf(context)) return message;
    return AnimatedSize(
      duration: Durations.short4,
      curve: Easing.emphasizedDecelerate,
      alignment: Alignment.topCenter,
      child: message,
    );
  }
}

/// The box with the text of [failure]: a card as the theme of the app has
/// its cards, in a tint of the colour that the theme has for an error.
class _Failure extends StatelessWidget {
  const _Failure(this.failure);

  final AuthFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hint = kDebugMode ? failure.developerHint : null;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card.outlined(
        // In the theme of any app, the card is as wide as the form.
        margin: EdgeInsets.zero,
        color: Color.alphaBlend(
          colors.error.withValues(alpha: 0.08),
          colors.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                // The icon grows with the first line of the text next to
                // it.
                size: MediaQuery.textScalerOf(context).scale(20),
                color: colors.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authFailureText(context, failure.reason),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 6),
                      // As a path, it is not much larger than usual.
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.5,
                        child: Text(
                          hint,
                          // The monospaced font of the device: Android has
                          // it under the first name, and iOS under the
                          // next.
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontFamilyFallback: const ['Menlo', 'Courier'],
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The text of the app for [reason], the reason of a failure of sign-in.
///
/// It has a text for every reason: a reason that the app gets later has
/// none here, and the app does not compile until it has.
String authFailureText(BuildContext context, AuthFailureReason reason) =>
    switch (reason) {
      AuthFailureReason.invalidCredentials => {{{text_failure_credentials}}},
      AuthFailureReason.emailInUse => {{{text_failure_email_in_use}}},
      AuthFailureReason.weakPassword => {{{text_failure_weak_password}}},
      AuthFailureReason.invalidEmail => {{{text_email_invalid}}},
      AuthFailureReason.userDisabled => {{{text_failure_disabled}}},
      AuthFailureReason.tooManyAttempts =>
        {{{text_failure_too_many_attempts}}},
      AuthFailureReason.network => {{{text_failure_no_network}}},
      AuthFailureReason.recentSignInRequired =>
        {{{text_failure_recent_sign_in}}},
      AuthFailureReason.notConfigured => {{{text_failure_not_set_up}}},
      AuthFailureReason.unknown => {{{text_failure_unknown}}},
    };

/// An email address on a line of its own, as a page shows the address that
/// a message went to: a text of the app has no place for it. It is a card
/// as the theme of the app has its cards.
class EmailAddress extends StatelessWidget {
  /// Creates the widget of [address].
  const EmailAddress(this.address, {super.key});

  /// The address.
  final String address;

  @override
  Widget build(BuildContext context) => Card.outlined(
    // In the theme of any app, the card is as wide as the form.
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: const Icon(Icons.mail_outline_rounded),
      // A long address takes more lines.
      title: Text(address),
    ),
  );
}
