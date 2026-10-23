import 'package:flutter/material.dart';

import 'paywall_widgets.dart';

/// The name of the app, as the card shows it.
const _appName = '{{app_name.titleCase()}}';

/// The symbol of the app in its cell, as an element of the periodic table
/// has one: the first letters of the first two words of its name, or the
/// first two letters of a name of one word.
const _appSymbol = {{{app_symbol}}};

/// The number in the cell of the app: how many letters and digits its name
/// has.
const _appNumber = {{app_number}};

/// The colours of Say My Frame, which the card keeps in the light and in
/// the dark theme, as the start screen of SMF does.
const _brandGreen = Color(0xFF0F3326);
const _brandCream = Color(0xFFF1F1E8);
const _brandAccent = Color(0xFF4ADE80);

/// The side of the cell of the app in the card, the space between the cell
/// and the edges of the card, the side of a cell of the table on the right
/// of the card, the space between two of them, and their space from the
/// edges of the card.
const _cellSide = 76.0;
const _cardPadding = 22.0;
const _tableCell = 40.0;
const _tableGap = 8.0;
const _tableInset = 20.0;

/// The card in the colours of Say My Frame at the top of the paywall and of
/// the screen of the subscription: the app as an element of a table, its
/// name with `Premium` above it, and on the right the cells of a table that
/// light up one after another while [animation] runs and end in a cell in
/// the accent with the icon of premium access, which grows a little once:
/// the table unlocks.
///
/// With [badge], such as `Unlocked`, it shows the badge next to `Premium`.
/// A screen reader reads the name with `Premium` as a header.
class PremiumCard extends StatelessWidget {
  /// Creates the card.
  const PremiumCard({
    required this.animation,
    required this.premium,
    this.badge,
    super.key,
  });

  /// The entrance of the card, from 0 to 1.
  final Animation<double> animation;

  /// The text `Premium` in the language of the app.
  final String premium;

  /// The text of the badge next to `Premium`, or `null`.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = this.badge;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _brandGreen,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _TablePainter(animation)),
              ),
            ),
            PositionedDirectional(
              top: _tableInset,
              end: _tableInset,
              child: _UnlockCell(animation: animation),
            ),
            Padding(
              padding: const EdgeInsets.all(_cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ElementCell(),
                  const SizedBox(height: 40),
                  Semantics(
                    header: true,
                    label: '$_appName $premium',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // A label, which grows only by half with the
                            // text size of the device.
                            MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.5,
                              child: Text(
                                premium.toUpperCase(),
                                style: monospace.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                  color: _brandAccent,
                                ),
                              ),
                            ),
                            if (badge != null) _Badge(badge),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // The name is large already, so it grows only by
                        // half with the text size of the device.
                        PaywallWords(
                          _appName,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: _brandCream,
                            fontWeight: FontWeight.w600,
                          ),
                          maxScaleFactor: 1.5,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The badge of a [PremiumCard], such as `Unlocked`: the text in the
/// accent of Say My Frame in a pill of that accent.
class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _brandAccent.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _brandAccent.withValues(alpha: 0.5)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: _brandAccent),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _brandAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The cell of the app, with its symbol and its number, as the mark of Say
/// My Frame has one.
///
/// It is a picture of the app, whose name the card tells below it. So its
/// letters keep their size when the text of the device is larger, and a
/// screen reader passes it by.
class _ElementCell extends StatelessWidget {
  const _ElementCell();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: Container(
          width: _cellSide,
          height: _cellSide,
          decoration: BoxDecoration(
            color: _brandGreen,
            border: Border.all(color: _brandCream, width: 1.5),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: 5,
                end: 7,
                child: Text(
                  '$_appNumber',
                  style: monospace.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _brandCream,
                  ),
                ),
              ),
              Center(
                child: Text(
                  _appSymbol,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.2,
                    color: _brandCream,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cell at the top of the table of a [PremiumCard]: it fills with the
/// accent of Say My Frame once the other cells lit up, with the icon of
/// premium access, which grows a little and back once.
class _UnlockCell extends StatelessWidget {
  const _UnlockCell({required this.animation});

  final Animation<double> animation;

  /// When the cell fills, and when it grows and comes back, in the
  /// entrance of the card.
  static const _fill = Interval(0.6, 0.78, curve: Curves.easeOut);
  static final _grow = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 1.06).chain(CurveTween(curve: Curves.easeOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.06, end: 1).chain(CurveTween(curve: Curves.easeIn)),
      weight: 1,
    ),
  ]).chain(CurveTween(curve: const Interval(0.74, 1)));

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final filled = _fill.transform(animation.value);
        return Transform.scale(
          scale: _grow.transform(animation.value),
          child: Container(
            width: _tableCell,
            height: _tableCell,
            decoration: BoxDecoration(
              color: _brandAccent.withValues(alpha: filled),
              border: Border.all(
                color: _brandCream.withValues(alpha: 0.14 + 0.86 * filled),
              ),
            ),
            child: Opacity(
              opacity: filled,
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 24,
                color: _brandGreen,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The cells of a table on the right of a [PremiumCard], but for the cell
/// at its top right, which [_UnlockCell] is: outlines, some of which light
/// up one after another while [animation] runs.
class _TablePainter extends CustomPainter {
  _TablePainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  /// The cells that light up, by column from the right and row from the
  /// top, each with its colour and the order in which it lights up.
  static const _lit = <(int, int, Color, int)>[
    (2, 1, Color(0x33F1F1E8), 0),
    (1, 2, Color(0x664ADE80), 1),
    (3, 0, Color(0x1FF1F1E8), 2),
    (1, 1, Color(0x994ADE80), 3),
    (0, 1, Color(0x33F1F1E8), 4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var column = 0; column < 4; column++) {
      for (var row = 0; row < 3; row++) {
        // The cell at the top right is the cell that unlocks.
        if (column == 0 && row == 0) continue;
        final rect = Rect.fromLTWH(
          size.width - _tableInset - _tableCell - column * (_tableCell + _tableGap),
          _tableInset + row * (_tableCell + _tableGap),
          _tableCell,
          _tableCell,
        );
        // A narrow card has no room for every column: it leaves out those
        // that would reach the cell of the app on its left.
        if (rect.left < _cardPadding + _cellSide + _tableGap) continue;
        // The outlines fade towards the cell of the app.
        outline.color = _brandCream.withValues(alpha: 0.14 - column * 0.03);
        canvas.drawRect(rect, outline);
        for (final (litColumn, litRow, color, order) in _lit) {
          if (litColumn != column || litRow != row) continue;
          final start = 0.15 + order * 0.08;
          final shown = Interval(
            start,
            (start + 0.25).clamp(0, 1),
            curve: Curves.easeOut,
          ).transform(animation.value);
          canvas.drawRect(
            rect,
            Paint()..color = color.withValues(alpha: color.a * shown),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TablePainter oldDelegate) =>
      oldDelegate.animation != animation;
}
