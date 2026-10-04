import 'package:flutter/material.dart';

/// The screen that the first guard of the fixture shows in place of the
/// other screens of the app while its gate is closed.
{{{smf_router__screen_annotations__fake_gate__fixture_gate_screen}}}
class FixtureGateScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureGateScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// A screen below the gate screen, which the first guard of the fixture
/// lets the user see too while its gate is closed.
{{{smf_router__screen_annotations__fake_gate__fixture_gate_step_screen}}}
class FixtureGateStepScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureGateStepScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// The screen that the second guard of the fixture shows while its gate is
/// closed.
{{{smf_router__screen_annotations__fake_gate__fixture_second_gate_screen}}}
class FixtureSecondGateScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureSecondGateScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}
