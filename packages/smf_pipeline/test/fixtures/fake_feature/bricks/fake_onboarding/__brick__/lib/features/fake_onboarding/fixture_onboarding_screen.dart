import 'package:flutter/material.dart';

import '../../core/onboarding/onboarding_steps.dart';

/// The onboarding of the fixture: a first page of its own, a page for each
/// step of [appOnboardingSteps] that its showIf keeps when the screen
/// opens, in the order of the list, and a last page of its own. The pages
/// turn with a swipe, and the button of the action of a step, or that of
/// its later, shows the next page.
{{{smf_router__screen_annotations__fake_onboarding__fixture_onboarding_screen}}}
class FixtureOnboardingScreen extends StatefulWidget {
  /// Creates the screen.
  const FixtureOnboardingScreen({super.key});

  @override
  State<FixtureOnboardingScreen> createState() =>
      _FixtureOnboardingScreenState();
}

class _FixtureOnboardingScreenState extends State<FixtureOnboardingScreen> {
  final _controller = PageController();

  /// The steps that the screen shows: those of [appOnboardingSteps] that
  /// their showIf keeps when the screen opens. A step stays while the
  /// screen is shown, also once its showIf would leave it out.
  late final List<OnboardingStep> _steps = [
    for (final step in appOnboardingSteps)
      if (step.showIf?.call() ?? true) step,
  ];

  /// Whether the action of a step runs, while the buttons of the steps take
  /// no tap.
  var _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shows the page after the one that the user sees.
  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Calls the action of [step] and shows the next page once its future
  /// completes, also when it fails: the error goes on to the handlers of
  /// the uncaught errors of the app.
  Future<void> _run(OnboardingStep step) async {
    setState(() => _running = true);
    try {
      await step.run();
    } finally {
      if (mounted) {
        setState(() => _running = false);
        _next();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageView(
        controller: _controller,
        children: [
          const _OwnPage('The onboarding of the fixture'),
          for (final step in _steps)
            _StepPage(
              step: step,
              onAction: _running ? null : () => _run(step),
              onLater: _running ? null : _next,
            ),
          const _OwnPage('The onboarding of the fixture is over'),
        ],
      ),
    ),
  );
}

/// A page of the onboarding of the fixture itself, with [title].
class _OwnPage extends StatelessWidget {
  const _OwnPage(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Center(child: Text(title));
}

/// The page of [step]: its icon, its title as a header for a screen
/// reader, its text, the button of its action, which calls [onAction], and
/// that of its later, if it has one, which calls [onLater]. The labels are
/// read each time the page builds, so they follow the language of the app.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.onAction,
    required this.onLater,
  });

  final OnboardingStep step;
  final VoidCallback? onAction;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final later = step.later;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(step.icon, size: 48),
          const SizedBox(height: 16),
          // A node of its own, which a screen reader announces as a header.
          Semantics(
            container: true,
            header: true,
            child: Text(step.title(context)),
          ),
          const SizedBox(height: 8),
          Text(step.text(context)),
          const SizedBox(height: 24),
          FilledButton(onPressed: onAction, child: Text(step.action(context))),
          if (later != null)
            TextButton(onPressed: onLater, child: Text(later(context))),
        ],
      ),
    );
  }
}
