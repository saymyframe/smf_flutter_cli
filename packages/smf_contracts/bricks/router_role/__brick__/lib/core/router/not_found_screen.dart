import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_router.dart';

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

/// The screen that the router shows for a location that it cannot show:
/// one that no route of the app matches, such as a link to a page that the
/// app does not have, and one without a value that its route requires.
///
/// It shows the cell of the app next to an empty cell, the page that is not
/// there, says so in the language of the app, and its button shows the
/// screen that the app starts on. Every router of the app shows this screen
/// as `const NotFoundScreen()`, so change its look here, and keep its
/// constructor `const` and without arguments.
class NotFoundScreen extends StatelessWidget {
  /// Creates the screen.
  const NotFoundScreen({super.key});

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A picture, which a screen reader passes over.
                  const ExcludeSemantics(child: _Cells()),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    namesRoute: true,
                    // The title grows at most by half with a larger text.
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.5,
                      child: Text(
                        {{{text_not_found_title}}},
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    child: Material(
                      color: colors.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: colors.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => appRouter.navigatorOf(context).goToStart(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                // The label grows at most by half, so that
                                // its words keep to the width of a phone.
                                child: MediaQuery.withClampedTextScaling(
                                  maxScaleFactor: 1.5,
                                  child: Text(
                                    {{{text_not_found_action}}},
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// The cell of the app, as an element of a table, among smaller cells, next
/// to an empty cell with a dashed edge and a question mark: the page that
/// is not there.
///
/// The letters are part of the picture, so they keep their size with a
/// larger text.
class _Cells extends StatelessWidget {
  const _Cells();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget cell(
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
        width: 252,
        height: 156,
        child: Stack(
          children: [
            cell(0, 18, 40, fill: colors.secondaryContainer),
            cell(168, 0, 28, edge: colors.outline),
            cell(218, 122, 34, fill: colors.tertiaryContainer),
            // The cell of the app.
            Positioned(
              left: 40,
              top: 20,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  border: Border.all(color: colors.onSurface, width: 1.5),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 7,
                      right: 10,
                      child: Text(
                        '$_appNumber',
                        style: _mono.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        _appSymbol,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontSize: 54,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -2,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The empty cell of the page that is not there.
            Positioned(
              left: 168,
              top: 44,
              child: CustomPaint(
                painter: _DashedEdge(colors.outline),
                child: SizedBox.square(
                  dimension: 72,
                  child: Center(
                    child: Text(
                      '?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a dashed edge around the box that it is given, in [color].
class _DashedEdge extends CustomPainter {
  const _DashedEdge(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final edge = (Offset.zero & size).deflate(0.75);
    for (final (from, to) in [
      (edge.topLeft, edge.topRight),
      (edge.topRight, edge.bottomRight),
      (edge.bottomRight, edge.bottomLeft),
      (edge.bottomLeft, edge.topLeft),
    ]) {
      final length = (to - from).distance;
      final along = (to - from) / length;
      for (var start = 0.0; start < length; start += dash + gap) {
        canvas.drawLine(
          from + along * start,
          from + along * math.min(start + dash, length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdge oldDelegate) => oldDelegate.color != color;
}
