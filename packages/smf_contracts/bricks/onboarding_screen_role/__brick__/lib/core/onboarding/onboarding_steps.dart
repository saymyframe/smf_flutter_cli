import 'package:flutter/widgets.dart';

/// A step of the onboarding, such as a page that asks for a permission: an
/// icon, a title, a text, and a button whose action is [run].
///
/// The onboarding shows each step of [appOnboardingSteps] on a page of its
/// own, in the order of the list, unless [showIf] returns `false` when the
/// onboarding opens. Skipping the onboarding skips its steps too.
final class OnboardingStep {
  /// Creates a step with [icon], [title] and [text], whose button [action]
  /// calls [run], and with a second button [later] if it is set.
  const OnboardingStep({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.run,
    this.later,
    this.showIf,
  });

  /// The icon of the page of the step.
  final IconData icon;

  /// Returns the title of the page in the language of the app, for the
  /// context of the widget that shows it. That widget calls it each time it
  /// builds, so the text follows the language of the app.
  final String Function(BuildContext context) title;

  /// Returns the text of the page below its title, as [title] does.
  final String Function(BuildContext context) text;

  /// Returns the label of the button that calls [run], as [title] does.
  final String Function(BuildContext context) action;

  /// What the button [action] does, such as asking for a permission. The
  /// onboarding goes on to its next page once the future completes, also
  /// when it fails.
  final Future<void> Function() run;

  /// Returns the label of the button that goes on to the next page without
  /// calling [run], as [title] does, or is `null` for a step without that
  /// button.
  final String Function(BuildContext context)? later;

  /// Whether the onboarding shows the step, which it asks once when it
  /// opens, or `null` for a step that it always shows.
  final bool Function()? showIf;
}

/// The steps of the onboarding, in the order in which it shows them.
const List<OnboardingStep> appOnboardingSteps = [
{{{steps}}}
];
{{{labels}}}
