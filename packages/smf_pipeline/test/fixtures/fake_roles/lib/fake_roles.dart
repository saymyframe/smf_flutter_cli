/// Roles of a third-party package, their provider and a module that uses
/// them, for the tests of the SMF pipeline. Not modules to use.
///
/// The two roles take the same data type, `String`, so a run with data for
/// both shows that the pipeline keeps the data of roles apart by role, not
/// by type. One module provides both roles.
///
/// The badge role publishes a condition that routes of an app ask for, so
/// that two fixture features meet through it: one asks for it on its
/// routes, and the other has the guard that stands for it.
///
/// The clock has a mode option, `--clock-hours`: an app with a clock of 12
/// hours is another app than one with a clock of 24, so the tests build
/// both.
library;

import 'package:fake_roles/bundles/badge_role_bundle.dart';
import 'package:fake_roles/bundles/clock_role_bundle.dart';
import 'package:fake_roles/bundles/fake_clock_badge_bundle.dart';
import 'package:fake_roles/bundles/fake_clock_user_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The clock role; see [ClockRole].
const clockRole = ClockRole._();

/// The badge role; see [BadgeRole].
const badgeRole = BadgeRole._();

String _literals(RoleHookInput<String> input) =>
    [for (final data in input.data) SmfNames.dartString(data.value)].join(', ');

/// A role of a third-party package: the clock of the app, with the time
/// zones the modules ask for as data and the ticks of the modules as a
/// socket.
///
/// The clock shows 24 hours or 12, as [hoursOption] says. The value reaches
/// the code of the app in three ways:
/// - the template of the role writes it into the file of the role as the
///   constant `clockHours` (see [clockImport]);
/// - a provider reads it in its render hook with [hoursIn], for the code of
///   `Clock.hourOf`;
/// - a module that only uses the role has no render hook, so its code is
///   the same in every app and reads `clockHours` when the app runs.
final class ClockRole extends Role<String> {
  const ClockRole._();

  /// `--clock-hours`, how many hours the clock shows: 24, the default, or
  /// 12.
  static const hoursOption = RoleOption.mode(
    name: 'clock-hours',
    help: 'How many hours the clock of the app shows: 24, the default, or '
        '12.',
    values: ['24', '12'],
  );

  /// The import of the file of the role, which has `Clock` and the
  /// constant `clockHours`.
  static const clockImport = ImportRef.app('core/clock/clock.dart');

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
  List<RoleOption> get options => const [hoursOption];

  @override
  RoleInterface get interface => const RoleInterface(
        files: ['lib/core/clock/clock.dart'],
        symbols: [createClock],
      );

  @override
  RoleTemplate<String> get template => const _ClockTemplate();

  /// How many hours the clock of the app shows, 24 or 12: the choice of
  /// the role in [input], the input of a render hook of the role or of its
  /// provider.
  int hoursIn(RoleHookInput<String> input) =>
      int.parse(input.choice! as String);
}

/// Writes the hours of the clock into the file of the role.
///
/// Its choice is the value of [ClockRole.hoursOption]: the one given, or
/// the first, which it offers first when it asks.
final class _ClockTemplate extends RoleTemplate<String> {
  const _ClockTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(clockRoleBundle)];

  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async {
    const option = ClockRole.hoursOption;
    final values = option.allowed!;
    final given = context.option(option.name);
    if (given != null) return given;
    final environment = context.environment;
    if (!environment.interactive) return values.first;
    return environment.prompter.select(
      'How many hours does the clock show?',
      values,
      defaultValue: values.first,
    );
  }

  @override
  Map<String, String> optionsOf(Object? choice) =>
      {ClockRole.hoursOption.name: choice! as String};

  @override
  RoleOutput render(RoleHookInput<String> input) => RoleOutput(
        vars: {
          'zones': _literals(input),
          'clock_hours': clockRole.hoursIn(input),
        },
      );
}

/// A role of a third-party package with the same data type as [ClockRole]:
/// a badge with the labels the modules ask for.
///
/// It publishes a condition for the routes of an app, [holder]: a feature
/// asks for it on a route, and another module stands for it with a guard,
/// and each knows only this role.
final class BadgeRole extends Role<String> {
  const BadgeRole._();

  /// What a user needs for the routes of the holders of a badge. A module
  /// that requires the role says whether the user holds one, with a guard
  /// of the routes that stands for the condition.
  static const holder = RouteCondition(badgeRole, 'holder');

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
///
/// Its clock keeps each time zone in a file of its own, see
/// [_FakeClockProvider].
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
          _FakeClockProvider(),
          RoleProvider.plain(badgeRole),
        ],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      [BrickContribution(fakeClockBadgeBundle)];
}

/// Generates a file for each time zone that the modules of the app ask
/// for, `lib/core/clock/zones/zone_<n>.dart` with the constant
/// `clockZone<n>`, and gives the brick of the module the constants, with the
/// imports of their files. A brick has the same files in every app, so only
/// the render hook can generate as many files as the app has zones.
///
/// It also gives the brick the code of `Clock.hourOf` for the hours that
/// the role chose, so the clock of an app has the code of its own hours
/// only.
final class _FakeClockProvider extends RoleProvider<String> {
  const _FakeClockProvider();

  @override
  Role<String> get role => clockRole;

  @override
  RoleOutput render(RoleHookInput<String> input) {
    final zones = [
      for (final (index, data) in input.data.indexed)
        (number: index + 1, name: data.value),
    ];
    return RoleOutput(
      vars: {
        'hour_of': switch (clockRole.hoursIn(input)) {
          12 => '(time.hour + 11) % 12 + 1',
          _ => 'time.hour',
        },
        'zone_constants': Fragment(
          [for (final zone in zones) 'clockZone${zone.number}'].join(', '),
          imports: [
            for (final zone in zones)
              ImportRef.app('core/clock/zones/zone_${zone.number}.dart'),
          ],
        ),
      },
      files: {
        for (final zone in zones)
          'lib/core/clock/zones/zone_${zone.number}.dart':
              '/// A time zone that a module of the app asked for (fixture).\n'
                  'const clockZone${zone.number} = '
                  '${SmfNames.dartString(zone.name)};\n',
      },
    );
  }
}

/// A module that works with the clock and the badge when they are present:
/// it contributes data to both roles, and code that refers to their
/// symbols only under `when` or, in its brick, under the presence flag
/// `{{#has_badge}}` or as the value of a variable for an app with the
/// clock.
///
/// It has no render hook, so it cannot know the hours that the clock role
/// chose when the app is generated. Its code for an app with the clock
/// reads the constant of the role and branches on it when the app runs.
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
        BrickContribution(
          fakeClockUserBundle,
          vars: {
            // One line of the template for the apps with the clock and for
            // those without it; only the first get the import.
            'clock_zones': RoleVar(
              clockRole,
              present: Fragment(
                'createClock().zones',
                imports: [ClockRole.createClock.importRef],
              ),
              absent: 'const <String>[]',
            ),
            // The same code for a clock of 24 hours and for one of 12.
            'clock_hour': RoleVar(
              clockRole,
              present: Fragment(
                'clockHours == 12 '
                r"? '${createClock().hourOf(time)} "
                r"${time.hour < 12 ? 'AM' : 'PM'}' "
                r": '${createClock().hourOf(time)}:00'",
                imports: [
                  ClockRole.createClock.importRef,
                  ClockRole.clockImport,
                ],
              ),
              absent: r"'${time.hour}:00'",
            ),
          },
        ),
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
