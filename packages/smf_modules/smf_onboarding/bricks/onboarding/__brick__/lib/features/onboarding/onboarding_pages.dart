import 'package:flutter/material.dart';

/// The pages of the onboarding, in the order in which the user goes through
/// them: a welcome with the name of the app, and a page that ends it.
///
/// To change what the onboarding shows, change this list. A page is any
/// widget, such as an [OnboardingPage]. The screen of the onboarding shows
/// them one at a time, with Skip above them and, below them, a mark for
/// each page and the button that leads on.
List<Widget> onboardingPages(BuildContext context) => [
  OnboardingPage(
    symbol: {{{symbol}}},
    title: '{{app_name.titleCase()}}',
    text: {{{text_welcome}}},
  ),
  OnboardingPage(
    icon: Icons.check_rounded,
    title: {{{text_ready_title}}},
    text: {{{text_ready}}},
  ),
];

/// What a page of the onboarding knows of the pages around it: its place
/// among them, and the controller that tells how far the user has turned
/// them. The screen of the onboarding puts one around each page, so that
/// the parts of a page can move at their own pace while the pages turn.
class OnboardingPageScope extends InheritedWidget {
  /// Creates the scope of the page at [index].
  const OnboardingPageScope({
    required this.index,
    required this.controller,
    required super.child,
    super.key,
  });

  /// The place of the page among the pages, from zero.
  final int index;

  /// The controller of the pages.
  final PageController controller;

  /// The scope of the page around [context], or `null` for a page that is
  /// shown outside the screen of the onboarding.
  static OnboardingPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingPageScope>();

  /// How far the user has turned the pages of [controller], in pages: zero
  /// on the first page, one on the second, and a fraction in between while
  /// they turn. Before the pages are first laid out, it is the page that
  /// they start on.
  ///
  /// The controller knows its page from the first layout on, also right
  /// after its pages got a new scroll position, as when the language of the
  /// device changes: a page that is built then stays where it is.
  static double turnedOf(PageController controller) =>
      (controller.hasClients ? controller.page : null) ??
      controller.initialPage.toDouble();

  /// How far the pages are turned away from this page: zero while it is the
  /// one on the screen, up to one once the user has turned on to the next
  /// page, and down to minus one before the user has reached it.
  double get turned => (turnedOf(controller) - index).clamp(-1, 1);

  @override
  bool updateShouldNotify(OnboardingPageScope oldWidget) =>
      oldWidget.index != index || oldWidget.controller != controller;
}

/// A page of the onboarding: a cell of the periodic table with [symbol] or
/// [icon], among smaller cells, and a title and a text below them. The
/// cells and the texts move at their own pace while the pages turn. The
/// page scrolls when it is too small for them, as with a large text size on
/// a small phone. A screen reader announces the title as a header, and
/// passes over the cells, which are a picture.
class OnboardingPage extends StatelessWidget {
  /// Creates the page.
  const OnboardingPage({
    required this.title,
    required this.text,
    this.symbol,
    this.icon,
    super.key,
  }) : assert(symbol != null || icon != null, 'A page shows one of them.');

  /// The letters in the cell of the page, as an element has a symbol.
  final String? symbol;

  /// The icon in the cell of the page, when it has no [symbol].
  final IconData? icon;

  /// The title of the page.
  final String title;

  /// What the page says below its title.
  final String text;

  @override
  Widget build(BuildContext context) {
    final scope = OnboardingPageScope.maybeOf(context);
    if (scope == null) return _build(context, turned: 0, index: 0);
    return AnimatedBuilder(
      animation: scope.controller,
      builder: (context, _) =>
          _build(context, turned: scope.turned, index: scope.index),
    );
  }

  /// The page at [index] while the pages are [turned] away from it.
  Widget _build(
    BuildContext context, {
    required double turned,
    required int index,
  }) {
    final theme = Theme.of(context);
    // The texts leave faster than the page, and fade as they go.
    final shown = (1 - turned.abs() * 1.6).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 280),
                    child: ExcludeSemantics(
                      child: _Cells(
                        mirrored: index.isOdd,
                        turned: turned,
                        number: index + 1,
                        symbol: symbol,
                        icon: icon,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
                  child: Opacity(
                    opacity: shown,
                    child: Transform.translate(
                      offset: Offset(-turned * 56, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: theme.textTheme.displaySmall,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// The picture of a page: the cell of the page in the middle, over a grid
/// that fades at its edges, with smaller cells around it. They come in
/// once, when the page is first shown, and each moves at its own pace while
/// the pages turn.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.turned,
    required this.number,
    required this.mirrored,
    this.symbol,
    this.icon,
  });

  /// How far the pages are turned away from the page of the picture.
  final double turned;

  /// The number in the corner of the cell of the page.
  final int number;

  /// Whether the smaller cells are on the other side, as on every other
  /// page, so that two pages in a row do not look the same.
  final bool mirrored;

  final String? symbol;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The smaller cells: where each is, its size, its colour, whether it is
    // only an outline, and how far it moves while the page turns.
    final around = [
      (
        at: const Alignment(-0.74, -0.50),
        size: 60.0,
        color: colors.secondaryContainer,
        outlined: false,
        travel: 120.0,
      ),
      (
        at: const Alignment(0.80, -0.70),
        size: 44.0,
        color: colors.outline,
        outlined: true,
        travel: 190.0,
      ),
      (
        at: const Alignment(0.72, 0.56),
        size: 68.0,
        color: colors.primaryContainer,
        outlined: false,
        travel: 90.0,
      ),
      (
        at: const Alignment(-0.60, 0.70),
        size: 40.0,
        color: colors.tertiaryContainer,
        outlined: false,
        travel: 160.0,
      ),
      (
        at: const Alignment(-0.08, -0.90),
        size: 30.0,
        color: colors.outline,
        outlined: true,
        travel: 230.0,
      ),
      (
        at: const Alignment(0.22, 0.92),
        size: 26.0,
        color: colors.secondary,
        outlined: false,
        travel: 250.0,
      ),
    ];
    // The smaller cells fade as the page leaves.
    final leaving = (1 - turned.abs()).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // An app that asks for less motion shows the picture at once.
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 1000),
      builder: (context, entered, _) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: Curves.easeOut.transform(entered),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const RadialGradient(
                  radius: 0.52,
                  colors: [Colors.white, Colors.transparent],
                  stops: [0.25, 1],
                ).createShader(bounds),
                child: CustomPaint(
                  painter: _GridPainter(
                    color: colors.outlineVariant,
                    shift: -turned * 36,
                  ),
                ),
              ),
            ),
          ),
          for (final (order, cell) in around.indexed)
            Align(
              alignment: mirrored ? Alignment(-cell.at.x, cell.at.y) : cell.at,
              child: _entering(
                entered,
                order: order + 1,
                opacity: leaving,
                offset: Offset(-turned * cell.travel, 0),
                child: Container(
                  width: cell.size,
                  height: cell.size,
                  decoration: BoxDecoration(
                    color: cell.outlined ? null : cell.color,
                    border: cell.outlined
                        ? Border.all(color: cell.color)
                        : null,
                  ),
                ),
              ),
            ),
          _entering(
            entered,
            order: 0,
            opacity: 1,
            offset: Offset(-turned * 28, 0),
            scale: 1 - turned.abs() * 0.14,
            angle: turned * 0.07,
            child: _Cell(number: number, symbol: symbol, icon: icon),
          ),
        ],
      ),
    );
  }

  /// [child] as it comes in while [entered] grows, later for a higher
  /// [order]: it fades in and settles from below and from a smaller size.
  Widget _entering(
    double entered, {
    required int order,
    required double opacity,
    required Offset offset,
    required Widget child,
    double scale = 1,
    double angle = 0,
  }) {
    final start = order * 0.09;
    final settled = Interval(
      start,
      (start + 0.5).clamp(0, 1),
      curve: Easing.emphasizedDecelerate,
    ).transform(entered);
    return Opacity(
      opacity: settled * opacity,
      child: Transform.translate(
        offset: offset + Offset(0, (1 - settled) * 28),
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale * (0.82 + 0.18 * settled),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The cell of a page: its [symbol], or its [icon] on the primary colour,
/// with [number] in its corner, as an element has one.
class _Cell extends StatelessWidget {
  const _Cell({required this.number, this.symbol, this.icon});

  final int number;
  final String? symbol;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filled = symbol == null;
    final ink = filled ? colors.onPrimary : colors.onSurface;
    // The letters and the number are part of the picture, in a cell of a
    // fixed size: they do not grow with the text size of the device.
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: 164,
        height: 164,
        decoration: BoxDecoration(
          color: filled ? colors.primary : colors.surfaceContainerLowest,
          border: Border.all(color: filled ? colors.primary : ink, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              right: 14,
              child: Text(
                '$number',
                // The monospaced font of the device: Android has it under
                // the first name, and iOS under the next.
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Menlo', 'Courier'],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
              ),
            ),
            Center(
              child: symbol == null
                  ? Icon(icon, size: 84, color: ink)
                  : Text(
                      symbol!,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 80,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -3,
                        color: ink,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid of square cells in [color], moved sideways by [shift].
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color, required this.shift});

  final Color color;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 52.0;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1;
    // The grid is centred, so that the cell of the page sits on its lines.
    final left = (size.width / 2 + shift) % cell;
    for (var x = left; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    final top = (size.height / 2) % cell;
    for (var y = top; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shift != shift;
}
