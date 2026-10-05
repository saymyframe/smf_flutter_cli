import 'package:flutter/material.dart';

import 'onboarding_pages.dart';
import 'onboarding_status.dart';

/// The onboarding of the app, which the app shows on its first launch in
/// place of every other screen: the pages of [onboardingPages], with Skip
/// and Next below them, and Done on the last page.
///
/// Skip and Done finish the onboarding. The screen does not navigate, and
/// nothing navigates to it: the router shows it while the onboarding is not
/// finished, and then the screen that the app starts on. The next launches
/// of the app start there.
///
/// When something shows the screen although the onboarding is finished,
/// such as a link to its route, the onboarding starts again, as
/// [OnboardingStatus.restart] has it: Skip and Done then leave the screen.
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
    // again, so that the router leaves the screen once Skip or Done
    // finishes it. The router acts on that at once, which it must not do
    // while a frame is built.
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

  /// Shows the page after the one that the user sees.
  void _next() => _controller.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  @override
  Widget build(BuildContext context) {
    final pages = onboardingPages(context);
    final isLast = _page == pages.length - 1;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: pages,
              ),
            ),
            // A dot for each page, with the one of the page that the user
            // sees in the primary colour.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < pages.length; index++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _page
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
              ],
            ),
            // The buttons go one below the other when they do not fit
            // side by side, as with a large text size.
            Padding(
              padding: const EdgeInsets.all(16),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                overflowSpacing: 8,
                children: [
                  if (!isLast)
                    TextButton(
                      onPressed: onboardingStatus.complete,
                      child: Text({{{text_skip}}}),
                    ),
                  FilledButton(
                    onPressed: isLast ? onboardingStatus.complete : _next,
                    child: Text(isLast ? {{{text_done}}} : {{{text_next}}}),
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
