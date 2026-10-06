import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'destination.dart';

/// The least height of the bar above the inset of the device. The bar grows
/// when a label needs more.
const double _barHeight = 64;

/// The most that the text size of the device scales the label of a tab. A
/// long press on a tab shows its label in a tooltip, at the full text size.
const double _maxLabelScale = 1.3;

/// The main navigation of the app: the screen of the selected destination,
/// and below it a bar with a tab for each destination.
///
/// With one destination there is nothing to switch to, so the bar is
/// hidden and the screen fills the app.
class AppShell extends StatelessWidget {
  /// Creates the main navigation with [destinations], the one at
  /// [currentIndex] selected with [body] as its screen; selecting a tab
  /// calls [onSelect] with its index.
  const AppShell({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.body,
    super.key,
  });

  /// The tabs of the bar, in order.
  final List<Destination> destinations;

  /// The index of the selected destination.
  final int currentIndex;

  /// Selects the destination at the given index.
  final ValueChanged<int> onSelect;

  /// The screen of the selected destination.
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _BranchTransition(index: currentIndex, child: body),
        bottomNavigationBar: destinations.length < 2
            ? null
            : _TabBar(
                destinations: destinations,
                currentIndex: currentIndex,
                onTap: _tapped,
              ),
      );

  /// Selects the destination of the tab at [index], which the user tapped.
  /// The device gives a light tick when that tab is not the selected one.
  void _tapped(int index) {
    if (index != currentIndex) HapticFeedback.selectionClick();
    onSelect(index);
  }
}

/// The bar at the bottom: a tab for each destination, below a hairline.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  final List<Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A Material of its own, so that the ink of a tab shows on the bar and
    // stays inside it.
    return Material(
      color: NavigationBarTheme.of(context).backgroundColor ?? colors.surface,
      shape: Border(top: BorderSide(color: colors.outlineVariant)),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (index, destination) in destinations.indexed)
              Expanded(
                child: _Tab(
                  destination: destination,
                  selected: index == currentIndex,
                  onTap: () => onTap(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The tab of [destination]: its icon over its label. When it becomes the
/// selected one, both take the colour of the selected destination, and
/// neither changes its size.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Read here each time the tab builds, so the label follows the language
    // of the app.
    final label = destination.label(context);
    // The colours that the theme of the app gives the icons of a navigation
    // bar, or else its primary colour for the selected tab.
    final ofTheme = NavigationBarTheme.of(context).iconTheme;
    final color = selected
        ? ofTheme?.resolve(const {WidgetState.selected})?.color ??
            colors.primary
        : ofTheme?.resolve(const {})?.color ?? colors.onSurfaceVariant;
    // For a user who asks the device for less motion, the tab changes at
    // once.
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Durations.medium2;
    // One node for a screen reader: a button with the label of the
    // destination, selected or not.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        preferBelow: false,
        verticalOffset: 40,
        child: InkResponse(
          onTap: onTap,
          radius: 44,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _barHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ExcludeSemantics(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: duration,
                  builder: (context, color, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(destination.icon, size: 24, color: color),
                      const SizedBox(height: 4),
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: _maxLabelScale,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [child], the screen of the destination at [index], and lets it
/// fade in while it rises a little, once, when the destination changes.
class _BranchTransition extends StatefulWidget {
  const _BranchTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchTransition> createState() => _BranchTransitionState();
}

class _BranchTransitionState extends State<_BranchTransition>
    with SingleTickerProviderStateMixin {
  /// At its end while no destination changes, where the screen is shown as
  /// it is.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Durations.medium2,
    value: 1,
  );

  @override
  void didUpdateWidget(_BranchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    // For a user who asks the device for less motion, the screen is shown
    // at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final shown =
              Easing.emphasizedDecelerate.transform(_controller.value);
          return Opacity(
            opacity: shown,
            child: Transform.translate(
              offset: Offset(0, (1 - shown) * 10),
              child: child,
            ),
          );
        },
        child: widget.child,
      );
}
