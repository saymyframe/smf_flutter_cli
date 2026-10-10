import 'package:flutter/material.dart';

/// A screen of the second fixture feature for the holders of a badge: its
/// route asks for the condition of the fixture badge role, which a guard
/// of another module stands for in an app that has one.
{{{smf_router__screen_annotations__fake_second__fixture_members_screen}}}
class FixtureMembersScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureMembersScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// A screen below the screen for the holders of a badge, whose route asks
/// for the same condition by being below that route.
{{{smf_router__screen_annotations__fake_second__fixture_member_card_screen}}}
class FixtureMemberCardScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureMemberCardScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// A screen for the holders of a badge below the screen outside the main
/// navigation, which is for everyone: its route asks for the condition by
/// itself.
{{{smf_router__screen_annotations__fake_second__fixture_vault_screen}}}
class FixtureVaultScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureVaultScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// A screen for the holders of a senior badge: its route asks for the
/// second condition of the fixture badge role.
{{{smf_router__screen_annotations__fake_second__fixture_lounge_screen}}}
class FixtureLoungeScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureLoungeScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// A screen below the screen for the holders of a senior badge, for those
/// who hold both badges: its route asks for the first condition itself,
/// and for the second by being below that route.
{{{smf_router__screen_annotations__fake_second__fixture_lounge_seat_screen}}}
class FixtureLoungeSeatScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureLoungeSeatScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}
