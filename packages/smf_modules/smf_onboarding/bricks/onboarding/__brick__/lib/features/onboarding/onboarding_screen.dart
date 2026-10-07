import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onboarding_pages.dart';
import 'onboarding_status.dart';

/// The onboarding of the app, which the app shows on its first launch in
/// place of every other screen: the pages of [onboardingPages], with Skip
/// above them, and below them a mark for each page and a button that leads
/// to the next page and, on the last one, into the app.
///
/// Skip and the last button finish the onboarding. The screen does not
/// navigate, and nothing navigates to it: the router shows it while the
/// onboarding is not finished, and then the screen that the app starts on.
/// The next launches of the app start there.
///
/// When something shows the screen although the onboarding is finished,
/// such as a link to its route, the onboarding starts again, as
/// [OnboardingStatus.restart] has it: Skip and the last button then leave
/// the screen.
{{{smf_router__screen_annotations__onboarding__onboarding_screen}}}
class OnboardingScreen extends StatefulWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();

  /// The index of the page that the user sees.
  var _page = 0;

  @override
  void initState() {
    super.initState();
    // The router shows the screen while the onboarding is not finished.
    // Shown although it is finished, the screen starts the onboarding
    // again, so that the router leaves the screen once Skip or the last
    // button finishes it. The router acts on that at once, which it must
    // not do while a frame is built.
    if (onboardingStatus.completed.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onboardingStatus.restart();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shows the page after the one that the user sees: at once in an app
  /// that asks for less motion.
  void _next() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(
        duration: Durations.long2,
        curve: Easing.emphasizedDecelerate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = onboardingPages(context);
    final isLast = _page == pages.length - 1;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // How long Skip and the label of the button take to change with the
    // page: no time in an app that asks for less motion.
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Durations.short4;
    // The colour that the background has reached on the last page.
    final end = Color.alphaBlend(
      colors.secondaryContainer.withValues(alpha: 0.6),
      colors.surface,
    );
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => ColoredBox(
          color: Color.lerp(
            colors.surface,
            end,
            pages.length < 2
                ? 0
                : (OnboardingPageScope.turnedOf(_controller) /
                          (pages.length - 1))
                      .clamp(0, 1),
          )!,
          child: child,
        ),
        child: SafeArea(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    // Skip fades away on the last page, where a tap no
                    // longer reaches it, and is gone once it has faded.
                    child: IgnorePointer(
                      ignoring: isLast,
                      child: AnimatedSwitcher(
                        duration: fade,
                        child: isLast
                            ? const SizedBox.shrink()
                            : TextButton(
                                onPressed: onboardingStatus.complete,
                                child: Text({{{text_skip}}}),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) {
                    HapticFeedback.selectionClick();
                    setState(() => _page = page);
                  },
                  children: [
                    for (final (index, page) in pages.indexed)
                      OnboardingPageScope(
                        index: index,
                        controller: _controller,
                        child: page,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _PageMarks(
                        controller: _controller,
                        count: pages.length,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isLast ? onboardingStatus.complete : _next,
                      child: AnimatedSwitcher(
                        duration: fade,
                        child: Text(
                          isLast ? {{{text_done}}} : {{{text_next}}},
                          key: ValueKey(isLast),
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

/// A mark for each of [count] pages, with the one of the page that the user
/// sees stretched and in the primary colour. The marks follow the pages
/// while they turn.
class _PageMarks extends StatelessWidget {
  const _PageMarks({required this.controller, required this.count});

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final turned = OnboardingPageScope.turnedOf(controller);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < count; index++)
                _mark(
                  colors,
                  // How much the mark is that of the page on the screen.
                  (1 - (turned - index).abs()).clamp(0, 1),
                ),
            ],
          );
        },
      ),
    );
  }

  /// A mark that is [current] of the way from that of another page to that
  /// of the page on the screen.
  Widget _mark(ColorScheme colors, double current) => Container(
    margin: const EdgeInsets.only(right: 6),
    height: 8,
    width: lerpDouble(8, 28, current),
    decoration: BoxDecoration(
      color: Color.lerp(
        colors.onSurface.withValues(alpha: 0.16),
        colors.primary,
        current,
      ),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
