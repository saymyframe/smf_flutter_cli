import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The name of the app, as the screen shows it.
const _appName = '{{app_name.titleCase()}}';

/// The symbol of the app in its cell, as an element of the periodic table
/// has one: the first letters of the first two words of its name, or the
/// first two letters of a name of one word.
const _appSymbol = {{{app_symbol}}};

/// The number in the cell of the app: how many letters and digits its name
/// has.
const _appNumber = {{app_number}};

/// The mark of Say My Frame, an image that `pubspec.yaml` declares among
/// the assets of the app. Flutter takes the file of the same name in `2.0x/`
/// or in `3.0x/` next to it on a screen with more pixels.
const _mark = 'lib/features/home/assets/smf_mark.png';

/// The colours of Say My Frame, which the card of the screen keeps in the
/// light and in the dark theme: it is the mark of what generated the app.
const _brandGreen = Color(0xFF0F3326);
const _brandCream = Color(0xFFF1F1E8);
const _brandAccent = Color(0xFF4ADE80);

/// The font of a path and of the number of a cell: the monospaced font of
/// the device, whose name differs between the platforms.
const _monospace = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
);

/// The side of the cell of the app in the card, and the space between the
/// cell and the edges of the card.
const _cellSide = 88.0;
const _cardPadding = 24.0;

/// The screen that the app starts on: a welcome to the developer of the app,
/// with what to do next. Replace its content with the first screen of the
/// app.
{{{smf_router__screen_annotations__home__home_screen}}}
class HomeScreen extends StatefulWidget {
  /// Creates the screen, which greets by the time that [now] tells.
  const HomeScreen({super.key, this.now = DateTime.now});

  /// Tells the time, for the greeting of the screen. A test gives a time of
  /// its own.
  final DateTime Function() now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Lets the parts of the screen rise in one after another, once.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // An app that asks for less motion shows the screen at once.
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

  /// Copies [code] and says so.
  Future<void> _copy(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = {{{text_copied}}};
    await Clipboard.setData(ClipboardData(text: code));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // As in the box of its step, the path is not much larger than
          // usual, so that a large text size leaves the snack bar room on
          // a small phone.
          content: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: Text('$copied: $code'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hour = widget.now().hour;
    final greeting = hour < 12
        ? {{{text_greeting_morning}}}
        : hour < 18
        ? {{{text_greeting_afternoon}}}
        : {{{text_greeting_evening}}};
    final steps = [
      (
        Icons.edit_outlined,
        {{{text_step_screen_title}}},
        {{{text_step_screen_text}}},
        'lib/features/home/home_screen.dart',
      ),
      (
        Icons.add_box_outlined,
        {{{text_step_feature_title}}},
        {{{text_step_feature_text}}},
        'lib/features/',
      ),
      (
        Icons.menu_book_outlined,
        {{{text_step_docs_title}}},
        {{{text_step_docs_text}}},
        'doc.saymyframe.com',
      ),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The screen has no app bar, so it tells the colour of the icons of
      // the status bar itself.
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            // The list ends above what covers the bottom of the screen,
            // such as the bar of the home gesture.
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _Rise(
                animation: _entrance,
                order: 0,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              _appName,
                              style: theme.textTheme.headlineLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        _mark,
                        width: 48,
                        height: 48,
                        semanticLabel: 'Say My Frame',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Rise(
                animation: _entrance,
                order: 1,
                child: _ReadyCard(
                  animation: _entrance,
                  title: {{{text_ready_title}}},
                  text: {{{text_ready_text}}},
                ),
              ),
              const SizedBox(height: 32),
              _Rise(
                animation: _entrance,
                order: 2,
                child: Semantics(
                  header: true,
                  child: Text(
                    {{{text_next_title}}},
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final (index, (icon, title, text, code)) in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Rise(
                    animation: _entrance,
                    order: 3 + index,
                    child: _StepCard(
                      icon: icon,
                      title: title,
                      text: text,
                      code: code,
                      onTap: () => _copy(code),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _Rise(
                animation: _entrance,
                order: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        _mark,
                        width: 20,
                        height: 20,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // With a large text size, the text takes more lines.
                    Flexible(
                      child: Text(
                        {{{text_footer}}},
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
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
    final start = order * 0.08;
    final curve = Interval(
      start,
      (start + 0.45).clamp(0, 1),
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

/// The card in the colours of Say My Frame that tells that the app is
/// ready, with the app as an element of a table whose cells light up.
class _ReadyCard extends StatelessWidget {
  const _ReadyCard({
    required this.animation,
    required this.title,
    required this.text,
  });

  final Animation<double> animation;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              child: CustomPaint(painter: _CellsPainter(animation)),
            ),
            Padding(
              padding: const EdgeInsets.all(_cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ElementTile(symbol: _appSymbol, number: _appNumber),
                  const SizedBox(height: 60),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: _brandCream,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _brandCream.withValues(alpha: 0.72),
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

/// A cell of the table of elements with [symbol] and [number], as the mark
/// of Say My Frame has one.
///
/// It is a picture of the app, whose name the screen tells above the card.
/// So its letters keep their size when the text of the device is larger,
/// and a screen reader passes it by.
class _ElementTile extends StatelessWidget {
  const _ElementTile({required this.symbol, required this.number});

  final String symbol;
  final int number;

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
              Positioned(
                top: 6,
                right: 8,
                child: Text(
                  '$number',
                  style: _monospace.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _brandCream,
                  ),
                ),
              ),
              Center(
                child: Text(
                  symbol,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 42,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -1.5,
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

/// The cells of a table of elements on the right of the card: outlines,
/// some of which light up one after another while [animation] runs.
class _CellsPainter extends CustomPainter {
  _CellsPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  /// The cells that light up, by column from the right and row from the
  /// top, each with its colour and the order in which it lights up.
  static const _lit = <(int, int, Color, int)>[
    (0, 0, _brandAccent, 0),
    (1, 1, Color(0x33F1F1E8), 1),
    (0, 2, Color(0x664ADE80), 2),
    (2, 0, Color(0x1FF1F1E8), 3),
    (3, 1, Color(0x14F1F1E8), 4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 44.0;
    const gap = 8.0;
    const inset = 20.0;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var column = 0; column < 4; column++) {
      for (var row = 0; row < 3; row++) {
        final rect = Rect.fromLTWH(
          size.width - inset - cell - column * (cell + gap),
          inset + row * (cell + gap),
          cell,
          cell,
        );
        // A narrow card has no room for every column: it leaves out those
        // that would reach the cell of the app on its left.
        if (rect.left < _cardPadding + _cellSide + gap) continue;
        // The outlines fade towards the text on the left.
        outline.color = _brandCream.withValues(alpha: 0.14 - column * 0.035);
        canvas.drawRect(rect, outline);
        for (final (litColumn, litRow, color, order) in _lit) {
          if (litColumn != column || litRow != row) continue;
          final start = 0.25 + order * 0.1;
          final shown = Interval(
            start,
            (start + 0.3).clamp(0, 1),
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
  bool shouldRepaint(_CellsPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

/// A step for the developer of the app: what to do, and the path or the
/// address that it is about, which a tap copies.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.code,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      // In the theme of any app, the card is as wide as what is above it,
      // and the response to a tap keeps to its corners.
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // A screen reader announces the card as one button.
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        // A long path takes more lines, which break at its
                        // slashes while the text is not much larger than
                        // usual.
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.5,
                          child: Text(
                            code,
                            style: _monospace.copyWith(
                              fontSize: 12.5,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
