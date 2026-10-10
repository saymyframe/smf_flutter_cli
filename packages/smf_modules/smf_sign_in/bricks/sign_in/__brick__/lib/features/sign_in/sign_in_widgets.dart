import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';

/// The symbol of the app in its cell, as an element of the periodic table
/// has one: the first letters of the first two words of its name, or the
/// first two letters of a name of one word.
const _appSymbol = {{{app_symbol}}};

/// The number in the cell of the app: how many letters and digits its name
/// has.
const _appNumber = {{app_number}};

/// The font of the number of a cell and of what explains a failure to the
/// developer of the app: the monospaced font of the device, whose name
/// differs between the platforms.
const _monospace = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
);

/// The side of the cell above the title of a page, the side of the cells of
/// the table next to it, and the space between two of them.
const _cellSide = 88.0;
const _smallCellSide = 40.0;
const _cellGap = 8.0;

/// A page of the sign-in of the app: the cell of the app among the cells of
/// a table, its [title] and its [intro], and its [children] one below the
/// other, such as the fields and the buttons of a form.
///
/// The page scrolls when it is too small for them, as with the keyboard
/// open or a large text size, and is no wider than a phone. Its parts rise
/// in one after another, once, and are there at once in an app that asks
/// for less motion. Over another page, it has an app bar with the button
/// that leads back.
class AuthPage extends StatefulWidget {
  /// Creates the page.
  const AuthPage({
    required this.title,
    required this.intro,
    required this.children,
    this.icon,
    super.key,
  });

  /// The title of the page, which a screen reader announces as a header.
  final String title;

  /// What the page says below its title.
  final String intro;

  /// The icon in the cell of the page, in place of the symbol of the app:
  /// for a page that tells that something is done.
  final IconData? icon;

  /// What the page shows below its texts.
  final List<Widget> children;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  /// Lets the parts of the page rise in one after another, once.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // An app that asks for less motion shows the page at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Whether a page below this one is there to go back to.
    final back = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return Scaffold(
      appBar: back ? AppBar() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, back ? 8 : 32, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rise(
                    animation: _entrance,
                    order: 0,
                    child: _Cells(animation: _entrance, icon: widget.icon),
                  ),
                  const SizedBox(height: 32),
                  _Rise(
                    animation: _entrance,
                    order: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          // The title is large already, so it grows only
                          // by half with the text size of the device, and
                          // a word of it stays on one line.
                          child: MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.5,
                            child: Text(
                              widget.title,
                              style: theme.textTheme.headlineLarge,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.intro,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  for (final (index, child) in widget.children.indexed)
                    _Rise(animation: _entrance, order: 2 + index, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets [child] fade in and rise while [animation] runs, later for a higher
/// [order].
class _Rise extends StatelessWidget {
  const _Rise({
    required this.animation,
    required this.order,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (order * 0.08).clamp(0.0, 0.5);
    final curve = Interval(
      start,
      start + 0.5,
      curve: Easing.emphasizedDecelerate,
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final shown = curve.transform(animation.value);
        return Opacity(
          opacity: shown,
          child: Transform.translate(
            offset: Offset(0, (1 - shown) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// The picture of a page: the cell of the app, or a cell with [icon], as an
/// element of a table, and next to it the cells of that table, some of
/// which light up one after another while [animation] runs.
///
/// It is a picture, so a screen reader passes over it.
class _Cells extends StatelessWidget {
  const _Cells({required this.animation, this.icon});

  final Animation<double> animation;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: _cellSide,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TablePainter(
                  animation,
                  outline: colors.outlineVariant,
                  // The cells that light up, by column from the cell of
                  // the page and row from the top, in the order in which
                  // they do.
                  lit: [
                    (0, 1, colors.secondaryContainer),
                    (1, 0, colors.tertiaryContainer),
                    (2, 1, colors.primaryContainer),
                    (3, 0, colors.secondary),
                  ],
                ),
              ),
            ),
            _Cell(icon: icon),
          ],
        ),
      ),
    );
  }
}

/// The cell of a page: the symbol of the app with its number in the corner,
/// as an element has them, or [icon] on the primary colour.
class _Cell extends StatelessWidget {
  const _Cell({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = this.icon;
    // The letters and the number are part of the picture, in a cell of a
    // fixed size: they do not grow with the text size of the device.
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: _cellSide,
        height: _cellSide,
        decoration: BoxDecoration(
          color: icon == null ? colors.surfaceContainerLowest : colors.primary,
          border: Border.all(
            color: icon == null ? colors.onSurface : colors.primary,
            width: 1.5,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: 44, color: colors.onPrimary)
            : Stack(
                children: [
                  Positioned(
                    top: 6,
                    right: 8,
                    child: Text(
                      '$_appNumber',
                      style: _monospace.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      _appSymbol,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 42,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.5,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The cells of a table to the right of the cell of a page, in two rows:
/// outlines that fade towards the edge, of which the cells of [lit] fill
/// with their colours one after another while [animation] runs.
class _TablePainter extends CustomPainter {
  _TablePainter(this.animation, {required this.outline, required this.lit})
    : super(repaint: animation);

  final Animation<double> animation;

  /// The colour of the outline of a cell.
  final Color outline;

  /// The cells that light up, each with its column, its row and its colour,
  /// in the order in which they do.
  final List<(int, int, Color)> lit;

  /// How many columns of cells the widest page has.
  static const _columns = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var column = 0; column < _columns; column++) {
      final left = _cellSide + _cellGap + column * (_smallCellSide + _cellGap);
      // A narrow page has no room for every column.
      if (left + _smallCellSide > size.width) break;
      for (var row = 0; row < 2; row++) {
        final rect = Rect.fromLTWH(
          left,
          row * (_smallCellSide + _cellGap),
          _smallCellSide,
          _smallCellSide,
        );
        for (final (order, (litColumn, litRow, color)) in lit.indexed) {
          if (litColumn != column || litRow != row) continue;
          final start = 0.2 + order * 0.12;
          final shown = Interval(
            start,
            start + 0.3,
            curve: Curves.easeOut,
          ).transform(animation.value);
          canvas.drawRect(
            rect,
            Paint()..color = color.withValues(alpha: color.a * shown),
          );
        }
        // The outlines fade towards the edge of the page.
        line.color = outline.withValues(
          alpha: outline.a * (1 - column / _columns),
        );
        canvas.drawRect(rect.deflate(0.5), line);
      }
    }
  }

  @override
  bool shouldRepaint(_TablePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.outline != outline ||
      !listEquals(oldDelegate.lit, lit);
}

/// A field of a form with its [label] above it. The label takes as many
/// lines as it needs, and a screen reader announces it with the field.
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

/// The look of a field of the sign-in: a box in the colours of the theme of
/// the app, with a thin line around it that tells whether the field has the
/// focus or a mistake.
InputDecoration _fieldDecoration(BuildContext context, {Widget? suffixIcon}) {
  final colors = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    filled: true,
    fillColor: colors.surfaceContainerLow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(colors.outlineVariant),
    enabledBorder: border(colors.outlineVariant),
    focusedBorder: border(colors.primary, width: 1.5),
    errorBorder: border(colors.error),
    focusedErrorBorder: border(colors.error, width: 1.5),
    // The text of a mistake takes the lines that it needs.
    errorMaxLines: 5,
    suffixIcon: suffixIcon,
    // The button in a field keeps its colour when the field has a mistake.
    suffixIconColor: colors.onSurfaceVariant,
  );
}

/// The field of the email address of a form. It tells the form of an
/// address that is missing or that has no `@`: whether the address is one,
/// the provider of sign-in knows.
class EmailField extends StatelessWidget {
  /// Creates the field.
  const EmailField({
    required this.controller,
    required this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  /// The controller of the address.
  final TextEditingController controller;

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
        decoration: _fieldDecoration(context),
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
    super.key,
  });

  /// The controller of the password.
  final TextEditingController controller;

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
        decoration: _fieldDecoration(
          context,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
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
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
        ],
      ),
    );
  }
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
    // An app that asks for less motion shows the message at once.
    if (MediaQuery.disableAnimationsOf(context)) return message;
    return AnimatedSize(
      duration: Durations.short4,
      curve: Easing.emphasizedDecelerate,
      alignment: Alignment.topCenter,
      child: message,
    );
  }
}

/// The box with the text of [failure]: a tint of the colour that the theme
/// has for an error, with a thin line around it.
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.error.withValues(alpha: 0.08),
            colors.surface,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              // The icon grows with the first line of the text next to it.
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
                        style: _monospace.copyWith(
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
/// a message went to: a text of the app has no place for it.
class EmailAddress extends StatelessWidget {
  /// Creates the widget of [address].
  const EmailAddress(this.address, {super.key});

  /// The address.
  final String address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mail_outline_rounded,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          // A long address takes more lines.
          Expanded(
            child: Text(
              address,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
