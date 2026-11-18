// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'update_status.dart';

/// The symbol of the app in its cell, as an element of the periodic table
/// has one: the first letters of the first two words of its name, or the
/// first two letters of a name of one word.
const _appSymbol = {{{app_symbol}}};

/// The number in the cell of the app: how many letters and digits its name
/// has.
const _appNumber = {{{app_number}}};

/// The monospaced font of the device, for the number of the cell.
const _mono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
);

/// The screen that the guard of the routes of the module shows in place of
/// the app while the version of the app is below the lowest version that
/// may run (see `updateStatus`).
///
/// It shows the cell of the app next to the same cell one step higher and
/// filled, the newer version, says why in the language of the app, and its
/// button opens the page of the app in its store. Once the user opened the
/// store from it, or the store did not open, which it says, it also offers
/// "Not now", which lets the user in for this launch, so that a lowest
/// version above the version in the store locks nobody out. It has no app
/// bar and no back button: the back button of the system leaves the app.
{{{smf_router__screen_annotations__update_required__update_required_screen}}}
class UpdateRequiredScreen extends StatelessWidget {
  /// Creates the screen.
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          // An app that asks for less motion shows the screen at once.
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Durations.long2,
          curve: Easing.emphasizedDecelerate,
          builder: (context, shown, child) => Opacity(
            opacity: shown,
            child: Transform.translate(
              offset: Offset(0, (1 - shown) * 16),
              child: child,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              child: ValueListenableBuilder<StoreVisit>(
                valueListenable: updateStatus.storeVisit,
                builder: (context, visit, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A picture, which a screen reader passes over.
                    const ExcludeSemantics(child: _Cells()),
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      namesRoute: true,
                      // The title grows at most by half with a larger text.
                      child: _WholeWords(
                        {{{text_title}}},
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                        maxScaleFactor: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: _WholeWords(
                        {{{text_body}}},
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // The button takes its look from the theme of the app.
                    ElevatedButton(
                      onPressed: updateStatus.openStore,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            // The label grows at most by half, so that its
                            // words keep to the width of a phone.
                            child: _WholeWords(
                              {{{text_update}}},
                              textAlign: TextAlign.center,
                              maxScaleFactor: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // The store opens outside the app.
                          const Icon(Icons.open_in_new_rounded, size: 18),
                        ],
                      ),
                    ),
                    if (visit == StoreVisit.failed) ...[
                      const SizedBox(height: 12),
                      // A screen reader reads the failure once it comes.
                      Semantics(
                        liveRegion: true,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: _WholeWords(
                            {{{text_store_failed}}},
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (visit != StoreVisit.none) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: updateStatus.continueForNow,
                        // The label grows at most by half, as that of
                        // "Update" does.
                        child: _WholeWords(
                          {{{text_later}}},
                          textAlign: TextAlign.center,
                          maxScaleFactor: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The cell of the app, as an element of a table, and the same cell one
/// step higher and filled, with an arrow up in place of its number: the
/// newer version of the app. Smaller cells around them, as on the other
/// screens of the app that show its cell.
///
/// The letters are part of the picture, so they keep their size with a
/// larger text.
class _Cells extends StatelessWidget {
  const _Cells();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget square(
      double left,
      double top,
      double side, {
      Color? fill,
      Color? edge,
    }) => Positioned(
      left: left,
      top: top,
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: fill,
          border: edge == null ? null : Border.all(color: edge),
        ),
      ),
    );

    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: 260,
        height: 156,
        child: Stack(
          children: [
            square(0, 4, 36, fill: colors.secondaryContainer),
            square(50, 12, 22, edge: colors.outline),
            square(226, 124, 32, fill: colors.tertiaryContainer),
            // The cell of the app as it is.
            Positioned(
              left: 14,
              top: 40,
              child: _Cell(
                fill: colors.surfaceContainerLowest,
                edge: colors.onSurface,
                ink: colors.onSurface,
                corner: Text(
                  '$_appNumber',
                  style: _mono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
            // The newer version: one step higher, filled.
            Positioned(
              left: 136,
              top: 0,
              child: _Cell(
                fill: colors.primary,
                edge: colors.primary,
                ink: colors.onPrimary,
                corner: Icon(
                  Icons.arrow_upward_rounded,
                  size: 16,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cell of 116 with the symbol of the app in [ink] on [fill], and
/// [corner] in its top right corner.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.fill,
    required this.edge,
    required this.ink,
    required this.corner,
  });

  final Color fill;
  final Color edge;
  final Color ink;
  final Widget corner;

  @override
  Widget build(BuildContext context) => Container(
    width: 116,
    height: 116,
    decoration: BoxDecoration(
      color: fill,
      border: Border.all(color: edge, width: 1.5),
    ),
    child: Stack(
      children: [
        Positioned(top: 7, right: 10, child: corner),
        Center(
          child: Text(
            _appSymbol,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 54,
              fontWeight: FontWeight.w500,
              letterSpacing: -2,
              color: ink,
            ),
          ),
        ),
      ],
    ),
  );
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
