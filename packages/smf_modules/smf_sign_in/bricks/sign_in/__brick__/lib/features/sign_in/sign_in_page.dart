import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The symbol of the app in its cell, as an element of the periodic table
/// has one: the first letters of the first two words of its name, or the
/// first two letters of a name of one word.
const _appSymbol = {{{app_symbol}}};

/// The number in the cell of the app: how many letters and digits its name
/// has.
const _appNumber = {{app_number}};

/// The font of the number of a cell: the monospaced font of the device,
/// whose name differs between the platforms.
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
      // The entrance starts when the page is first built. A widget test
      // that starts the app in real time, as with tester.runAsync(), does
      // so once in its file: when a second test of the file starts the app
      // again, the time of this animation runs backwards, and Flutter
      // fails an assertion.
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
                          // The title is large already. It grows only
                          // by half with the text size of the device, so
                          // that no word of it breaks on a narrow phone.
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
                  PositionedDirectional(
                    top: 6,
                    end: 8,
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
