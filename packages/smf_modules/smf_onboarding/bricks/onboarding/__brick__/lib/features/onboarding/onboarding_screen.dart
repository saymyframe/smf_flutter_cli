import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/onboarding/onboarding_steps.dart';
import 'onboarding_pages.dart';
import 'onboarding_status.dart';

/// The onboarding of the app, which the app shows on its first launch in
/// place of every other screen: the pages of [onboardingPages], with the
/// steps that the modules of the app add, [appOnboardingSteps], before the
/// last of them. Skip is above the pages, and below them are a mark for
/// each page and a button that leads to the next page and, on the last
/// one, into the app.
///
/// A step is a page in the look of the others, with the icon of the step
/// in its cell. On the page of a step, the button below the pages is the
/// action of the step: it calls the function of the step, spins until the
/// future of that function completes, or takes no tap until then in an app
/// that asks for less motion, and then shows the next page, also when the
/// future fails. A step may have a second button below it, which
/// goes on without the action. Skip skips the steps too.
///
/// Skip and the last button finish the onboarding. The screen does not
/// navigate, and nothing navigates to it: the router shows it while the
/// onboarding is not finished, and then the screen that the app starts on.
/// The next launches of the app start there.
///
/// A navigation to the route of the screen once the onboarding is
/// finished, such as a link, shows the screen that the app starts on too,
/// or the target of another guard of the app while that one does not
/// allow. Only [OnboardingStatus.restart] shows the onboarding again.
{{{smf_router__screen_annotations__onboarding__onboarding_screen}}}
class OnboardingScreen extends StatefulWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();

  /// The steps that the screen shows: those of [appOnboardingSteps] whose
  /// showIf keeps them when the screen opens. A step stays while the
  /// screen is shown, also once its showIf would leave it out.
  late final List<OnboardingStep> _steps = [
    for (final step in appOnboardingSteps)
      if (step.showIf?.call() ?? true) step,
  ];

  /// The index of the page that the user sees.
  var _page = 0;

  /// Whether the action of a step runs: until its future completes, the
  /// pages stay where they are and the buttons of the step take no tap.
  var _running = false;

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

  /// Calls the action of [step] with the context of the screen, and shows
  /// the next page once its future completes, also when it fails: the error
  /// goes on to the handlers of the errors of the app that nothing caught.
  Future<void> _run(OnboardingStep step) async {
    setState(() => _running = true);
    try {
      await step.run(context);
    } finally {
      if (mounted) {
        setState(() => _running = false);
        _next();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final own = onboardingPages(context);
    // The steps come before the last page of the list.
    final first = own.isEmpty ? 0 : own.length - 1;
    final pages = [
      ...own.take(first),
      for (final step in _steps)
        OnboardingPage(
          icon: step.icon,
          title: step.title(context),
          text: step.text(context),
        ),
      ...own.skip(first),
    ];
    final isLast = _page == pages.length - 1;
    // The step whose page the user sees, if it is one.
    final step = _page >= first && _page < first + _steps.length
        ? _steps[_page - first]
        : null;
    // While the action of a step runs, its button spins, but not in an app
    // that asks for less motion, where it takes no tap instead.
    final spins = _running && !MediaQuery.disableAnimationsOf(context);
    // What the button below the pages does, and what it says.
    final VoidCallback? onPressed;
    final String label;
    if (step == null) {
      onPressed = isLast ? onboardingStatus.complete : _next;
      label = isLast ? {{{text_done}}} : {{{text_next}}};
    } else {
      // A button that spins keeps its colour and does nothing.
      onPressed = _running ? (spins ? () {} : null) : () => _run(step);
      label = step.action(context);
    }
    // The steps with a second button, which is below the button of the
    // pages while the page of its step is shown.
    final withLater = [
      for (final other in _steps)
        if (other.later != null) other,
    ];
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
                // The pages stay where they are while the action of a step
                // runs.
                child: IgnorePointer(
                  ignoring: _running,
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                // The labels of the buttons grow only by half with the text
                // size of the device: the pages take the room that the
                // buttons leave, and would have none left on a small phone.
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.5,
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
                        onPressed: onPressed,
                        child: AnimatedSwitcher(
                          duration: fade,
                          child: _ButtonLabel(
                            label,
                            spins: spins,
                            key: ValueKey<Object>(step ?? isLast),
                          ),
                        ),
                      ),
                      // The second button of a step, in a place of the height
                      // of the tallest of them, so that the pages keep their
                      // height from page to page. Only the one of the step
                      // whose page is shown is on the screen: the others take
                      // no tap and no focus.
                      if (withLater.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IndexedStack(
                            alignment: Alignment.center,
                            index: step?.later == null
                                ? withLater.length
                                : withLater.indexOf(step!),
                            children: [
                              for (final other in withLater)
                                TextButton(
                                  onPressed: _running ? null : _next,
                                  child: Text(other.later!(context)),
                                ),
                              const SizedBox.shrink(),
                            ],
                          ),
                        ),
                    ],
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

/// The label of the button below the pages, or what spins in its place
/// while the action of a step runs.
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.label, {required this.spins, super.key});

  final String label;
  final bool spins;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      // The label keeps its place, so that the button keeps its size.
      Visibility.maintain(visible: !spins, child: Text(label)),
      if (spins)
        // In the colour that the button gives its label.
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: DefaultTextStyle.of(context).style.color,
          ),
        ),
    ],
  );
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
