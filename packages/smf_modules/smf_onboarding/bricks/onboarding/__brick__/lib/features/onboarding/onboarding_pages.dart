import 'package:flutter/material.dart';

/// The pages of the onboarding, in the order in which the user goes through
/// them: a welcome with the name of the app, and a page that ends it.
///
/// To change what the onboarding shows, change this list. A page is any
/// widget, such as an [OnboardingPage]. The screen of the onboarding shows
/// them one at a time, and adds Skip, Next and Done below them.
List<Widget> onboardingPages(BuildContext context) => [
  OnboardingPage(
    icon: Icons.waving_hand_outlined,
    title: '{{app_name.titleCase()}}',
    text: {{{text_welcome}}},
  ),
  OnboardingPage(
    icon: Icons.check_circle_outline,
    title: {{{text_ready_title}}},
    text: {{{text_ready}}},
  ),
];

/// A page of the onboarding: an icon, a title and a text below them, in the
/// middle of the page. It scrolls when the page is too small for them, as
/// with a large text size on a small phone. A screen reader announces the
/// title as a header.
class OnboardingPage extends StatelessWidget {
  /// Creates the page.
  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.text,
    super.key,
  });

  /// The icon at the top of the page.
  final IconData icon;

  /// The title of the page.
  final String title;

  /// What the page says below its title.
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
