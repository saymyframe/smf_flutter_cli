import 'package:flutter/material.dart';

import '../../core/router/navigation.dart';

/// The start screen of the fixture: it navigates with the facade.
{{{smf_router__screen_annotations__fake_feature__fixture_home_screen}}}
class FixtureHomeScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => context.nav.fakeFeature.details(id: 1).go(),
              child: const Text('Go'),
            ),
            TextButton(
              onPressed: () async {
                await context.nav.fakeFeature.details(id: 2, tab: 'a').push<void>();
              },
              child: const Text('Push'),
            ),
            TextButton(
              onPressed: () => context.nav.fakeFeature.details(id: 3).replace(),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
}
