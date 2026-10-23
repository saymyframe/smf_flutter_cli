import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The font of a key of `.env` and of a hint for the developer: the
/// monospaced font of the device, whose name differs between the
/// platforms.
const monospace = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
);

/// The white space at which a line of text may break: every white space but
/// the no-break spaces.
final RegExp _breaks = RegExp(r'[^\S\u00A0\u2007\u202F]+');

/// A text that keeps its words whole: it breaks between its words and never
/// inside one.
///
/// A word is what stands between two spaces at which a line may break, such
/// as a space, a tab or a line break. A no-break space keeps the words on
/// each side of it together, as in a price that the store gives.
///
/// It grows with the text size of the device, by [maxScaleFactor] at most.
/// Where its longest word would still not fit the width that the text has,
/// as on a narrow phone with a large text size, the text is as large as
/// that word allows.
class PaywallWords extends StatelessWidget {
  /// Creates the text.
  const PaywallWords(
    this.text, {
    this.style,
    this.textAlign,
    this.maxScaleFactor = double.infinity,
    super.key,
  });

  /// The text.
  final String text;

  /// The style of the text, over that of the text around it. With none,
  /// the text is as the text around it, as the label of a button is in the
  /// style that the theme of the app gives the button.
  final TextStyle? style;

  /// How the lines of the text are aligned.
  final TextAlign? textAlign;

  /// By how much the text grows at most with the text size of the device.
  final double maxScaleFactor;

  @override
  Widget build(BuildContext context) {
    // The style in which a Text paints: over that of the text around it,
    // and bold for a user who asks for bold text.
    var style = DefaultTextStyle.of(context).style.merge(this.style);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: maxScaleFactor);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        );
        // How wide the longest word is in a font of [size].
        double widestAt(double size) {
          var widest = 0.0;
          for (final word in text.split(_breaks)) {
            painter
              ..text = TextSpan(
                text: word,
                style: style.copyWith(fontSize: size),
              )
              ..layout();
            if (painter.width > widest) widest = painter.width;
          }
          return widest;
        }

        // The size of a text of Flutter whose style gives none.
        var size = style.fontSize ?? 14;
        var widest = widestAt(size);
        // In a few steps: the text size of a device may grow a small font
        // by more than a large one.
        for (var step = 0; step < 4 && widest > room && room > 0; step++) {
          // A little smaller than the width allows, so that the rounding of
          // the layout breaks no word.
          size *= room / widest * 0.98;
          widest = widestAt(size);
        }
        painter.dispose();
        return Text(
          text,
          style: style.copyWith(fontSize: size),
          textAlign: textAlign,
          textScaler: scaler,
        );
      },
    );
  }
}

/// Lets [child] fade in and rise while [animation] runs, later for a higher
/// [order].
class Rise extends StatelessWidget {
  /// Creates the part [order] of an entrance.
  const Rise({
    required this.animation,
    required this.order,
    required this.child,
    super.key,
  });

  /// The entrance, from 0 to 1.
  final Animation<double> animation;

  /// The place of [child] in the entrance: a part of a higher order comes
  /// in later.
  final int order;

  /// What comes in.
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

/// Whether a button whose call is on its way spins. In an app that asks for
/// less motion, nothing spins: the button is disabled and keeps its label.
bool _spins(BuildContext context, {required bool busy}) =>
    busy && !MediaQuery.disableAnimationsOf(context);

/// What a tap on a button does while its call may be on its way: a button
/// that spins keeps its colour and does nothing, and one that is busy
/// without spinning takes no tap.
VoidCallback? _whileBusy(
  VoidCallback? onPressed, {
  required bool busy,
  required bool spins,
}) {
  if (!busy) return onPressed;
  return spins ? () {} : null;
}

/// The label of a button, or what spins in its place while the call of the
/// button is on its way. A new label fades in where the old one was.
class _BusyLabel extends StatelessWidget {
  const _BusyLabel(this.label, {required this.spins, this.spinnerSize = 22});

  final String label;
  final bool spins;
  final double spinnerSize;

  @override
  Widget build(BuildContext context) {
    final text = PaywallWords(
      label,
      key: ValueKey(label),
      textAlign: TextAlign.center,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // The label keeps its place, so that the button keeps its size.
        Visibility.maintain(
          visible: !spins,
          child: MediaQuery.disableAnimationsOf(context)
              ? text
              : AnimatedSwitcher(duration: Durations.short4, child: text),
        ),
        if (spins)
          // In the colour that the button gives its label.
          SizedBox.square(
            dimension: spinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: DefaultTextStyle.of(context).style.color,
            ),
          ),
      ],
    );
  }
}

/// The button of the paywall that buys the selected plan, as wide as the
/// paywall. While the purchase is on its way, it shows that it is [busy]
/// and does nothing.
///
/// It spins for as long as the purchase takes, and after a purchase that
/// gave premium access until the router closes the paywall. So a widget
/// test that waits for the paywall with `pumpAndSettle()` returns only once
/// it is closed: until then, such a test pumps frames one at a time.
class PurchaseButton extends StatelessWidget {
  /// Creates the button.
  const PurchaseButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  /// The text of the button, which keeps its words whole.
  final String label;

  /// Whether the purchase is on its way.
  final bool busy;

  /// Buys the selected plan, or `null` while the button takes no tap, as
  /// while the plans load or a restore is on its way.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final spins = _spins(context, busy: busy);
    return FilledButton(
      onPressed: _whileBusy(onPressed, busy: busy, spins: spins),
      child: _BusyLabel(label, spins: spins),
    );
  }
}

/// A link of the paywall below its button, such as the one that restores
/// purchases: a small text button of the theme of the app. While its call
/// is on its way, it shows that it is [busy] and does nothing.
class PaywallLink extends StatelessWidget {
  /// Creates the link.
  const PaywallLink({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  /// The text of the link.
  final String label;

  /// Whether the call of the link is on its way.
  final bool busy;

  /// What the link does, or `null` while it takes no tap.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final spins = _spins(context, busy: busy);
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: Theme.of(context).textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, 40),
      ),
      onPressed: _whileBusy(onPressed, busy: busy, spins: spins),
      child: _BusyLabel(label, spins: spins, spinnerSize: 16),
    );
  }
}

/// The card of a plan on the paywall: a radio dot, the [name] of the plan,
/// its [price], the most prominent text of the card, with what follows it,
/// and what its intro offer gives, if it has one.
///
/// The selected card has a border and a tint in the accent of the theme of
/// the app, `colorScheme.secondary`, and the others a hairline. A screen
/// reader reads a card as one button of a group of which one is selected.
class PlanCard extends StatelessWidget {
  /// Creates the card.
  const PlanCard({
    required this.name,
    required this.price,
    required this.suffix,
    required this.offer,
    required this.badge,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// The name of the plan.
  final String name;

  /// The price of the plan as the store gives it.
  final String price;

  /// What follows the price, such as `/ month`, or `null`.
  final String? suffix;

  /// What the intro offer of the plan gives, or `null` for a plan without
  /// one.
  final String? offer;

  /// The text of the badge of the plan, such as `Best value`, or `null`.
  final String? badge;

  /// Whether the plan is the selected one.
  final bool selected;

  /// Selects the plan, or `null` while the card takes no tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.secondary;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Durations.short4;
    final badge = this.badge;
    final offer = this.offer;
    final radius = BorderRadius.circular(20);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: [name, [price, ?suffix].join(' '), ?offer, ?badge].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duration,
        curve: Easing.standard,
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(accent.withValues(alpha: 0.08), colors.surface)
              : colors.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(
            color: selected ? accent : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              // The border of a selected card is wider, and the content of
              // the card stays where it is.
              padding: EdgeInsets.all(selected ? 15 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _RadioDot(selected: selected, duration: duration),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The badge follows the name, and goes below it
                        // where both do not fit one line.
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // No larger than the price, which grows only by
                            // half too.
                            PaywallWords(
                              name,
                              style: theme.textTheme.titleMedium,
                              maxScaleFactor: 1.5,
                            ),
                            ?switch (badge) {
                              final badge? => Pill(badge, strong: true),
                              null => null,
                            },
                          ],
                        ),
                        const SizedBox(height: 4),
                        // The price grows only by half with the text size
                        // of the device, so that it keeps to its line.
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.5,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: price,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                                // The price and what follows it stay on
                                // one line.
                                if (suffix case final suffix?)
                                  TextSpan(
                                    text: '\u00A0'
                                        '${suffix.replaceAll(' ', '\u00A0')}',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (offer != null) ...[
                          const SizedBox(height: 10),
                          Pill(offer),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dot of a [PlanCard] that tells whether the plan is selected: a ring
/// in the accent of the theme with a dot inside for the selected plan, and
/// a ring of the outline for the others.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.duration});

  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: duration,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.secondary : Colors.transparent,
        border: Border.all(
          color: selected ? colors.secondary : colors.outline,
          width: 1.5,
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: duration,
          width: selected ? 8 : 0,
          height: selected ? 8 : 0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.onSecondary,
          ),
        ),
      ),
    );
  }
}

/// A short text in a pill, such as what an intro offer gives: in the
/// container colour of the accent, or with [strong] in the accent itself.
class Pill extends StatelessWidget {
  /// Creates the pill of [text].
  const Pill(this.text, {this.strong = false, super.key});

  /// The text of the pill.
  final String text;

  /// Whether the pill is in the accent of the theme rather than in its
  /// container colour.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: strong ? colors.secondary : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        // A label, which grows only by half with the text size of the
        // device.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: strong ? colors.onSecondary : colors.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// What the paywall shows in the place of a plan while the plans load: a
/// card of the size of a plan with grey bars, which does not move, so that
/// the paywall settles.
class PlanSkeleton extends StatelessWidget {
  /// Creates the skeleton.
  const PlanSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.outlineVariant, width: 1.5),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                bar(96, 14),
                const SizedBox(height: 12),
                bar(140, 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The message of the paywall after a call: why it failed, or what it tells
/// the user, or nothing while both are `null`. It takes its place smoothly,
/// and a screen reader announces it when it appears.
///
/// In debug mode it also shows what the provider of purchases says to the
/// developer of the app about a failure, which is no text for a user.
class PaywallMessage extends StatelessWidget {
  /// Creates the message.
  const PaywallMessage({required this.text, required this.failed, this.hint,
      super.key});

  /// The text of the message for the user, or `null` for none.
  final String? text;

  /// Whether the message tells of a failure, in the colours that the theme
  /// has for an error, rather than of a notice.
  final bool failed;

  /// What the provider of purchases says to the developer of the app.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final message = text == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _MessageCard(text: text, failed: failed, hint: hint),
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

/// The box of a [PaywallMessage]: a card in a tint of the colour that the
/// theme has for an error, or of its accent for a notice.
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.text,
    required this.failed,
    required this.hint,
  });

  final String text;
  final bool failed;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = failed ? colors.error : colors.secondary;
    final hint = kDebugMode ? this.hint : null;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        color: Color.alphaBlend(tone.withValues(alpha: 0.08), colors.surface),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                failed ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                // The icon grows with the first line of the text next to it.
                size: MediaQuery.textScalerOf(context).scale(20),
                color: tone,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
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
                          style: monospace.copyWith(
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

/// A note for the developer of the app, which only a debug build shows, in
/// English: what the provider of purchases says is missing, and the keys of
/// `.env` that the paywall cannot link to, each of which a tap copies.
class DeveloperNote extends StatelessWidget {
  /// Creates the note, which shows nothing without a [hint] and [keys].
  const DeveloperNote({required this.hint, required this.keys, super.key});

  /// What the provider of purchases says to the developer of the app, such
  /// as the key that it lacks, or `null`.
  final String? hint;

  /// The keys of `.env` whose values the paywall cannot link to.
  final List<String> keys;

  /// Copies [key] and says so.
  Future<void> _copy(BuildContext context, String key) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: key));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Copied: $key')));
  }

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    if (!kDebugMode || (hint == null && keys.isEmpty)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final small = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code_rounded, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For the developer',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text('Purchases are not set up yet:', style: small),
            const SizedBox(height: 4),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Text(
                hint,
                style: monospace.copyWith(
                  fontSize: 12,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
          if (keys.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Fill in these values in .env, so that the paywall links to '
              'your pages:',
              style: small,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in keys)
                  Semantics(
                    button: true,
                    child: Material(
                      color: colors.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _copy(context, key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                // A key grows only by half, so that it
                                // keeps to a line of its own.
                                child: MediaQuery.withClampedTextScaling(
                                  maxScaleFactor: 1.5,
                                  child: Text(
                                    key,
                                    style: monospace.copyWith(
                                      fontSize: 12,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text('Only a debug build shows this note.', style: small),
        ],
      ),
    );
  }
}
