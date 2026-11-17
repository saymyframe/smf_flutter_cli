import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows the sheet with [address] over the screen of [context] where no
/// mail app opens a new mail, such as on the iOS simulator, which has no
/// Mail: the user copies the address and writes from their own email.
///
/// It is a sheet on the navigator at the root of the app, so it shows over
/// the main navigation too. It stays below the status bar, also where it
/// takes the whole height of a small phone, and comes at once in an app that
/// asks for less motion. Edit the texts among those of the email_feedback
/// module.
Future<void> showEmailFeedbackSheet(BuildContext context, String address) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      // A sheet that may take the whole height starts below the status bar.
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) => _AddressSheet(address: address),
    );

/// What the sheet shows: why, the address, and a button that copies it. It
/// scrolls where it does not fit.
class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.address});

  /// The address that the user writes to.
  final String address;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  /// Whether the user copied the address.
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.address));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: _WholeWords(
                {{{text_no_mail_title}}},
                style: theme.textTheme.headlineSmall,
                maxScaleFactor: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _WholeWords(
              {{{text_no_mail_text}}},
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            // The address in a field of its own, which the user may also
            // select. It grows at most by half and stays on one line: where
            // it does not fit, it is as large as the line allows.
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: SelectionArea(
                  child: _WholeWords(
                    widget.address,
                    style: theme.textTheme.titleMedium,
                    maxScaleFactor: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _copy,
              // A screen reader reads "Address copied" once it comes.
              child: Semantics(
                liveRegion: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      // The label grows at most by half.
                      child: _WholeWords(
                        _copied ? {{{text_copied}}} : {{{text_copy}}},
                        textAlign: TextAlign.center,
                        maxScaleFactor: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text that keeps its words whole: it breaks between its words and never
/// inside one. A space, a tab or a line break parts two words, and a
/// no-break space keeps the two words around it together as one.
///
/// It grows with the text size of the device, by [maxScaleFactor] at most.
/// Where its longest word would still not fit the width that the text has,
/// as on a narrow phone with a large text size, the text is as large as
/// that word allows.
class _WholeWords extends StatelessWidget {
  const _WholeWords(
    this.text, {
    this.style,
    this.textAlign,
    this.maxScaleFactor = double.infinity,
  });

  /// The text.
  final String text;

  /// The style of the text, over that of the text around it. With none, the
  /// text is as the text around it, as the label of a button is in the style
  /// that the theme of the app gives the button.
  final TextStyle? style;

  /// How the lines of the text are aligned.
  final TextAlign? textAlign;

  /// By how much the text grows at most with the text size of the device.
  final double maxScaleFactor;

  @override
  Widget build(BuildContext context) {
    // The style in which a Text paints: over that of the text around it, and
    // bold for a user who asks for bold text.
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
        // The words of the text, between its white spaces, where a line may
        // break: every one but a no-break space, which keeps the words
        // around it together.
        final words = text.split(RegExp(r'[^\S\u00A0\u2007\u202F]+'));
        // How wide the longest word is in a font of [size].
        double widestAt(double size) {
          var widest = 0.0;
          for (final word in words) {
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
        // In a few steps: the text size of a device may grow a small font by
        // more than a large one.
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
