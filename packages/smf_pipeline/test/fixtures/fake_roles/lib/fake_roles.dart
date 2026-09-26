/// Roles of a third-party package, their provider and a module that uses
/// them, for the tests of the SMF pipeline. Not modules to use.
///
/// The two roles take the same data type, `String`, so a run with data for
/// both shows that the pipeline keeps the data of roles apart by role, not
/// by type. One module provides both roles.
library;

import 'package:fake_roles/bundles/badge_role_bundle.dart';
import 'package:fake_roles/bundles/clock_role_bundle.dart';
import 'package:fake_roles/bundles/fake_clock_badge_bundle.dart';
import 'package:fake_roles/bundles/fake_clock_user_bundle.dart';
import 'package:smf_contracts/lego.dart';

/// The clock role; see [ClockRole].
const clockRole = ClockRole._();

/// The badge role; see [BadgeRole].
const badgeRole = BadgeRole._();

String _literals(RoleHookInput<String> input) =>
    [for (final data in input.data) SmfNames.dartString(data.value)].join(', ');

/// A role of a third-party package: the clock of the app, with the time
/// zones the modules ask for as data and the ticks of the modules as a
/// socket.
final class ClockRole extends Role<String> {
  const ClockRole._();

  /// Statements that run on every tick, in `tick()`.
  static const ticks = SocketRef<CodeSocket>.role(
    clockRole,
    'ticks',
    CodeSocket(),
  );

  /// `Clock createClock()`, which every provider generates.
  static const createClock = RequiredFunction(
    'createClock',
    path: 'lib/core/clock/clock_factory.dart',
    returnType: 'Clock',
  );

  @override
  String get id => 'clock';

  @override
  String get description => 'Clock (fixture)';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  List<SocketRef> get sockets => const [ticks];

  @override
  RoleInterface get interface => const RoleInterface(
        files: ['lib/core/clock/clock.dart'],
        symbols: [createClock],
      );

  @override
  RoleTemplate<String> get template => const _ClockTemplate();
}

final class _ClockTemplate extends RoleTemplate<String> {
  const _ClockTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(clockRoleBundle)];

  @override
  RoleOutput render(RoleHookInput<String> input) =>
      RoleOutput(vars: {'zones': _literals(input)});
}

/// A role of a third-party package with the same data type as [ClockRole]:
/// a badge with the labels the modules ask for.
final class BadgeRole extends Role<String> {
  const BadgeRole._();

  /// `Badge createBadge()`, which every provider generates.
  static const createBadge = RequiredFunction(
    'createBadge',
    path: 'lib/core/badge/badge_factory.dart',
    returnType: 'Badge',
  );

  @override
  String get id => 'badge';

  @override
  String get description => 'Badge (fixture)';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleInterface get interface => const RoleInterface(
        files: ['lib/core/badge/badge.dart'],
        symbols: [createBadge],
      );

  @override
  RoleTemplate<String> get template => const _BadgeTemplate();
}

final class _BadgeTemplate extends RoleTemplate<String> {
  const _BadgeTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(badgeRoleBundle)];

  @override
  RoleOutput render(RoleHookInput<String> input) =>
      RoleOutput(vars: {'labels': _literals(input)});
}

/// The provider of both the clock and the badge role.
final class FakeClockBadgeModule extends SmfModule {
  /// Creates the module.
  const FakeClockBadgeModule();

  /// The id of the module.
  static const id = ModuleId('fake_clock_badge');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Clock and badge (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [
          RoleProvider.plain(clockRole),
          RoleProvider.plain(badgeRole),
        ],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(fakeClockBadgeBundle)];
}

/// A module that works with the clock and the badge when they are present:
/// it contributes data to both roles, and code that refers to their
/// symbols only under `when` or, in its brick, under the presence flag
/// `{{#has_badge}}`.
final class FakeClockUserModule extends SmfModule {
  /// Creates the module.
  const FakeClockUserModule();

  /// The id of the module.
  static const id = ModuleId('fake_clock_user');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Uses the clock and the badge (fixture)',
        kind: ModuleKinds.infrastructure,
        uses: {clockRole, badgeRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeClockUserBundle),
        clockRole.data("Europe/Kyiv's zone"),
        badgeRole.data('New'),
        const SocketContribution.code(
          ClockRole.ticks,
          Fragment(
            "debugPrint('tick');",
            imports: [ImportRef('package:flutter/foundation.dart')],
          ),
        ),
        SocketContribution.code(
          AppEntryRole.bootstrapLate,
          Fragment(
            'debugPrint(createBadge().labels.join());',
            imports: [
              const ImportRef('package:flutter/foundation.dart'),
              BadgeRole.createBadge.importRef,
            ],
          ),
          when: const {badgeRole},
        ),
      ];
}
