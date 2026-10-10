@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'router_vm.dart';
import 'support.dart';

/// A role that publishes conditions for the routes, as a role that knows
/// who the user is publishes the account that some screens need.
final class _ClubRole extends Role<NoDsl> {
  const _ClubRole();

  @override
  String get id => 'club';

  @override
  String get description => 'Club';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;
}

const _clubRole = _ClubRole();

/// What the rooms of the members need.
const _member = RouteCondition(_clubRole, 'member');

/// What the lounge needs besides.
const _paid = RouteCondition(_clubRole, 'paid');

/// The condition of the lounge, created anew: not the constant itself.
RouteCondition _clubPaid() => RouteCondition(_paid.role, ['pa', 'id'].join());

/// A condition that no guard of the tests stands for.
const _invited = RouteCondition(_clubRole, 'invited');

ScreenRef _screen(String name, String feature) => ScreenRef(
      name,
      import: ImportRef.app(
        'features/$feature/${SmfNames.snakeCaseOf(name)}.dart',
      ),
    );

const _destination = Destination(
  label: LocalizedText('label', en: 'Home'),
  icon: Fragment(
    'Icons.home',
    imports: [ImportRef('package:flutter/material.dart')],
  ),
);

/// The routes of a feature without guards and without conditions: its
/// start route, a destination of the main navigation.
final RoutesData _homeRoutes = RoutesData([
  Route(
    '/',
    name: 'root',
    screen: _screen('HomeScreen', 'home'),
    destination: _destination,
    startCandidate: true,
  ),
]);

/// The routes of a feature that asks for conditions and has no guard: a
/// route that every user sees; a route for members with a route below it,
/// which asks for the same by being there; and a route that asks for two
/// conditions.
final RoutesData _roomsRoutes = RoutesData([
  Route('/', name: 'lobby', screen: _screen('LobbyScreen', 'rooms')),
  Route(
    '/members',
    name: 'members',
    screen: _screen('MembersScreen', 'rooms'),
    conditions: const [_member],
    children: [
      Route('card', name: 'card', screen: _screen('CardScreen', 'rooms')),
    ],
  ),
  Route(
    '/lounge',
    name: 'lounge',
    screen: _screen('LoungeScreen', 'rooms'),
    conditions: const [_member, _paid],
  ),
]);

/// The file of the functions of the guards of the feature `account`.
const _accountFile = ImportRef.app('features/account/account_session.dart');

/// The file of the function of the guard of the feature `shop`.
const _shopFile = ImportRef.app('features/shop/shop_plan.dart');

/// The file of the function of the guard of the feature `intro`.
const _introFile = ImportRef.app('features/intro/intro_status.dart');

/// The guard of the feature `account` that stands for the members, which
/// shows the target of the gate of the feature.
const _memberGuard = RouteGuard(
  name: 'member',
  allows: FunctionRef('isMember', import: _accountFile),
  redirectTo: 'login',
  stage: GuardStage.identity,
  condition: _member,
);

/// A second guard for the same condition, of another name and stage.
const _memberGuardToo = RouteGuard(
  name: 'memberToo',
  allows: FunctionRef('isMember', import: _accountFile),
  redirectTo: 'login',
  stage: GuardStage.welcome,
  condition: _member,
);

/// The routes of a feature with a gate and a guard of a condition that
/// show one target, so that both have one flow: its login screen with a
/// screen below it. The gate does not bring the user back. The feature
/// declares the guard of the condition first.
final RoutesData _accountRoutes = RoutesData(
  [
    Route(
      '/login',
      name: 'login',
      screen: _screen('LoginScreen', 'account'),
      children: [
        Route(
          'reset',
          name: 'reset',
          screen: _screen('ResetScreen', 'account'),
        ),
      ],
    ),
  ],
  guards: const [
    _memberGuard,
    RouteGuard(
      name: 'signedIn',
      allows: FunctionRef('isSignedIn', import: _accountFile),
      redirectTo: 'login',
      stage: GuardStage.identity,
      resumes: false,
    ),
  ],
);

/// The routes of a feature with a guard of a condition and no gate, of the
/// first stage, which does not bring the user back.
final RoutesData _shopRoutes = RoutesData(
  [Route('/plans', name: 'plans', screen: _screen('PlansScreen', 'shop'))],
  guards: const [
    RouteGuard(
      name: 'paid',
      allows: FunctionRef('hasPaid', import: _shopFile),
      redirectTo: 'plans',
      stage: GuardStage.welcome,
      resumes: false,
      condition: _paid,
    ),
  ],
);

/// The routes of a feature with a gate of the first stage.
final RoutesData _introRoutes = RoutesData(
  [Route('/', name: 'intro', screen: _screen('IntroScreen', 'intro'))],
  guards: const [
    RouteGuard(
      name: 'firstRun',
      allows: FunctionRef('introSeen', import: _introFile),
      redirectTo: 'intro',
      stage: GuardStage.welcome,
    ),
  ],
);

/// The routes of an app with conditions. The modules are listed against
/// the order in which the app asks their guards: the guard of a condition
/// of `shop`, of the first stage, then `account`, which declares its guard
/// of a condition before its gate, and then `intro`, whose gate is of the
/// first stage.
final List<RoleData<Object>> _clubData = [
  dataOf(routerRole, _homeRoutes),
  dataOf(routerRole, _roomsRoutes, module: 'rooms'),
  dataOf(routerRole, _shopRoutes, module: 'shop'),
  dataOf(routerRole, _accountRoutes, module: 'account'),
  dataOf(routerRole, _introRoutes, module: 'intro'),
];

RouterFacade _facade(List<RoleData<Object>> data) =>
    routerRole.facadeOf(inputOf(routerRole, data: data));

/// The functions of the guards of the feature `account`, over notifiers
/// that a test sets.
const _vmAccount = '''
import 'package:flutter/foundation.dart';

final ValueNotifier<bool> signedInNow = ValueNotifier(true);

final ValueNotifier<bool> memberNow = ValueNotifier(false);

ValueListenable<bool> isSignedIn() => signedInNow;

ValueListenable<bool> isMember() => memberNow;
''';

/// The function of the guard of the feature `shop`.
const _vmShop = '''
import 'package:flutter/foundation.dart';

final ValueNotifier<bool> paidNow = ValueNotifier(true);

ValueListenable<bool> hasPaid() => paidNow;
''';

/// The function of the guard of the feature `intro`.
const _vmIntro = '''
import 'package:flutter/foundation.dart';

final ValueNotifier<bool> introSeenNow = ValueNotifier(true);

ValueListenable<bool> introSeen() => introSeenNow;
''';

/// What the script [main] prints in the app with conditions, or in the app
/// of [data]; see [printedByGuards].
Future<String> _printedBy(String main, {List<RoleData<Object>>? data}) =>
    printedByGuards(
      main,
      data: data ?? _clubData,
      files: {
        'lib/${_accountFile.uri}': _vmAccount,
        'lib/${_shopFile.uri}': _vmShop,
        'lib/${_introFile.uri}': _vmIntro,
      },
    );

/// Prints the guards of the app, and then what `redirectOf()` says of each
/// route, and of a screen that is no route (`none`), with the routes whose
/// flow `flowIsOver()` says is over, as the gate and the condition with one
/// flow, a second condition and a gate of an earlier stage change.
const _vmAskMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/account/account_session.dart';
import 'package:my_app/features/intro/intro_status.dart';
import 'package:my_app/features/shop/shop_plan.dart';

void main() {
  for (final guard in routeGuards) {
    print(
      '${guard.name} shows ${guard.redirectTo.path} in place of '
      '${guard.routes?.join(', ') ?? 'every route'}',
    );
  }
  const routes = [
    'home.root',
    'rooms.lobby',
    'rooms.members',
    'rooms.card',
    'rooms.lounge',
    'account.login',
    'account.reset',
    'shop.plans',
    'intro.intro',
    null,
  ];
  void ask(String when) {
    final shown = <String>[];
    final sent = <String, List<String>>{};
    for (final route in routes) {
      final name = route ?? 'none';
      switch (redirectOf(route)) {
        case null:
          shown.add(name);
        case final location:
          sent.putIfAbsent(location.path, () => []).add(name);
      }
    }
    print(when);
    if (shown.isNotEmpty) print('  shows ${shown.join(', ')}');
    for (final MapEntry(:key, :value) in sent.entries) {
      print('  $key: ${value.join(', ')}');
    }
    final over = [
      for (final route in routes)
        if (flowIsOver(route)) route ?? 'none',
    ];
    if (over.isNotEmpty) print('  over: ${over.join(', ')}');
  }

  signedInNow.value = false;
  ask('the gate does not allow, the condition does not hold');
  signedInNow.value = true;
  ask('the gate allows, the condition does not hold');
  memberNow.value = true;
  ask('the gate allows, the condition holds');
  signedInNow.value = false;
  ask('the gate does not allow, the condition holds');
  signedInNow.value = true;
  memberNow.value = false;
  paidNow.value = false;
  ask('two conditions do not hold');
  memberNow.value = true;
  ask('the second condition of a route does not hold');
  introSeenNow.value = false;
  ask('a gate of the first stage does not allow');
}
''';

/// Prints what `GuardedNavigation` of the app answers a router that knows
/// a location by its URI, as it is asked about locations on top of the
/// pages of a stack and told of those pages while the gates and the
/// conditions change. The pages are written as `pagesOf` of [vmAnswers]
/// reads them, the one on top first, and a line names those that a location
/// is asked for on top of by their routes.
const _vmFlowMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/account/account_session.dart';
import 'package:my_app/features/intro/intro_status.dart';
import 'package:my_app/features/shop/shop_plan.dart';

import 'answers.dart';

final guards = GuardedNavigation<String>(
  start: '/',
  locationOf: (location) => location.path,
);

void asked(String? route, String location, {List<String> on = const []}) {
  final routes = routesOf(on);
  final answer = guards.asked(route, location, onTopOf: routes);
  final pages = routes.isEmpty ? 'no page' : routes.join(' + ');
  print('  asked $location on $pages: ${whenAsked(answer)}');
}

void changed(String what, List<String> pages) {
  print('  $what: ${whenChanged(guards.changed(pagesOf(pages)))}');
}

const home = 'home.root /home';
const lobby = 'rooms.lobby /rooms';
const members = 'rooms.members /rooms/members';
const card = 'rooms.card /rooms/members/card';
const lounge = 'rooms.lounge /rooms/lounge';
const login = 'account.login /account/login';
const reset = 'account.reset /account/login/reset';
const plans = 'shop.plans /shop/plans';
const intro = 'intro.intro /intro';

/// [page] as one that the router can close on its own.
String over(String page) => '$page pushed';

void main() {
  print('a route that asks for a condition that does not hold');
  asked('home.root', '/home', on: [lobby]);
  asked('rooms.members', '/rooms/members?tab=a', on: [lobby]);
  asked('rooms.card', '/rooms/members/card', on: [over(lobby), home]);
  asked('rooms.lounge', '/rooms/lounge', on: [lobby]);
  asked('rooms.members', '/rooms/members');
  asked(null, '/no/such', on: [lobby]);
  changed('a notification', [over(login), lobby]);

  print('the flow of a guard with routes');
  asked('account.login', '/account/login', on: [lobby]);
  asked('account.reset', '/account/login/reset', on: [over(login), lobby]);
  asked('account.login', '/account/login');

  print('a request while the flow is open');
  asked('rooms.members', '/rooms/members', on: [over(login), lobby]);
  asked('rooms.card', '/rooms/members/card', on: [over(reset), over(login), lobby]);
  asked('rooms.members', '/rooms/members', on: [over(reset), lobby]);
  asked('rooms.members', '/rooms/members', on: [login]);
  asked('rooms.members', '/rooms/members', on: [over(lobby), over(login), home]);
  asked('rooms.members', '/rooms/members');

  print('the condition holds while its flow is open');
  memberNow.value = true;
  changed('the target over a page', [over(login), lobby]);
  asked('rooms.members', '/rooms/members?tab=a', on: [lobby]);
  changed('a notification', [over(members), lobby]);
  changed('two pages of the flow', [over(reset), over(login), lobby]);
  changed('a page of the flow in place of the target', [over(reset), lobby]);
  changed('a page outside the flow over the target', [over(lobby), over(login), home]);
  changed('the target alone', [login]);
  changed('the chain of a page of the flow', [reset, login]);
  changed('a page over the target, which has none below', [over(lobby), login]);
  changed('a page that the router can close, alone', [over(login)]);
  changed('a page that it cannot close over a page', [login, home]);
  changed('no page of the flow', [lobby]);
  asked('account.login', '/account/login', on: [lobby]);
  asked('account.reset', '/account/login/reset');

  print('a condition that stops holding');
  memberNow.value = false;
  changed('on a page that does not ask', [lobby]);
  changed('on a page that asks, over a page', [over(members), lobby]);
  changed('below a page that does not ask', [over(lobby), over(members), home]);
  changed('on a route below one that asks', [over(card), lobby]);
  changed('on a page that asks, alone', [members]);
  changed('on the chain of a page that asks', [card, members]);
  changed('below a page, with no page below it', [over(lobby), members]);

  print('a request that the router dropped');
  asked('rooms.members', '/rooms/members', on: [lobby]);
  asked('rooms.lobby', '/rooms', on: [over(login), lobby]);
  memberNow.value = true;
  changed('member holds', [lobby]);
  memberNow.value = false;
  changed('member stops', [lobby]);
  asked('rooms.members', '/rooms/members', on: [lobby]);
  asked('intro.intro', '/intro', on: [over(login), lobby]);
  memberNow.value = true;
  changed('member holds', [home]);

  print('a gate that brings the user back stops while the flow is open');
  memberNow.value = false;
  changed('member stops', [lobby]);
  asked('rooms.members', '/rooms/members', on: [lobby]);
  introSeenNow.value = false;
  changed('firstRun stops', [over(login), lobby]);
  introSeenNow.value = true;
  changed('firstRun allows', [intro]);
  memberNow.value = true;
  changed('member holds', [lobby]);

  print('a route that asks for two conditions');
  memberNow.value = false;
  paidNow.value = false;
  changed('both stop', [home]);
  asked('rooms.lounge', '/rooms/lounge', on: [home]);
  asked('rooms.lounge', '/rooms/lounge', on: [over(plans), home]);
  paidNow.value = true;
  changed('paid holds', [over(plans), home]);
  asked('rooms.lounge', '/rooms/lounge', on: [home]);
  memberNow.value = true;
  changed('member holds', [over(login), home]);
  asked('rooms.lounge', '/rooms/lounge', on: [home]);

  print('the page that a request was made on closes');
  memberNow.value = false;
  paidNow.value = false;
  changed('both stop', [home]);
  asked('rooms.lounge', '/rooms/lounge', on: [home]);
  asked('rooms.members', '/rooms/members', on: [over(plans), home]);
  paidNow.value = true;
  changed('paid holds below the flow of member', [over(login), over(plans), home]);
  memberNow.value = true;
  paidNow.value = false;
  changed('member holds, paid stops', [over(members), lobby]);
  asked('rooms.lounge', '/rooms/lounge', on: [over(members), lobby]);
  memberNow.value = false;
  changed('member stops below the flow of paid', [over(plans), over(members), lobby]);
  memberNow.value = true;
  changed('member holds', [lobby]);
  asked('rooms.lounge', '/rooms/lounge', on: [lobby]);
  memberNow.value = false;
  changed('member stops over the flow of paid', [over(card), over(plans), lobby]);
  memberNow.value = true;
  paidNow.value = true;
  changed('paid holds, with a page over its flow', [over(lobby), over(plans), lobby]);

  print('a gate and a condition with one flow, in one turn');
  signedInNow.value = false;
  memberNow.value = false;
  changed('both stop', [over(members), lobby]);
  changed('the second notification', [login]);
  asked('rooms.members', '/rooms/members', on: [login]);
  signedInNow.value = true;
  memberNow.value = true;
  changed('both allow', [login]);
  changed('the second notification', [members]);
  signedInNow.value = false;
  memberNow.value = false;
  changed('both stop', [members]);
  signedInNow.value = true;
  memberNow.value = true;
  changed('both allow, nothing asked for', [login]);

  print('a gate and a condition with one flow, the gate first');
  signedInNow.value = false;
  memberNow.value = false;
  changed('both stop', [lobby]);
  asked('rooms.lobby', '/rooms', on: [login]);
  asked('rooms.members', '/rooms/members', on: [login]);
  signedInNow.value = true;
  changed('the gate allows', [login]);
  asked('account.login', '/account/login', on: [home]);
  memberNow.value = true;
  changed('the condition holds', [home]);
  signedInNow.value = false;
  memberNow.value = false;
  changed('both stop', [home]);
  signedInNow.value = true;
  changed('the gate allows, nothing asked for', [login]);
  memberNow.value = true;
  changed('the condition holds', [login]);

  print('a gate and a condition with one flow, the condition first');
  signedInNow.value = false;
  memberNow.value = false;
  changed('both stop', [card, members]);
  asked('rooms.card', '/rooms/members/card', on: [login]);
  memberNow.value = true;
  changed('the condition holds', [login]);
  asked('rooms.lobby', '/rooms', on: [login]);
  signedInNow.value = true;
  changed('the gate allows', [login]);

  print('the gate of the flow stops while the flow is open');
  memberNow.value = false;
  changed('member stops', [lobby]);
  asked('rooms.members', '/rooms/members', on: [lobby]);
  signedInNow.value = false;
  changed('the gate stops', [over(login), lobby]);
  signedInNow.value = true;
  memberNow.value = true;
  changed('both allow', [login]);

  print('a link to a route that asks for a condition, behind a gate');
  introSeenNow.value = false;
  memberNow.value = false;
  changed('firstRun stops', [home]);
  asked('rooms.members', '/rooms/members', on: [intro]);
  introSeenNow.value = true;
  changed('firstRun allows', [intro]);
  changed('a notification', [home]);
  memberNow.value = true;
  changed('member holds', [home]);
  memberNow.value = false;
  changed('member stops', [home]);
  asked('rooms.members', '/rooms/members');
  memberNow.value = true;

  print('a location asked for once the gates allow, before the class is told');
  introSeenNow.value = false;
  changed('firstRun stops', [lobby]);
  introSeenNow.value = true;
  asked('home.root', '/home', on: [intro]);
  changed('firstRun allows', [home]);

  print('a guard with routes that does not bring the user back');
  introSeenNow.value = false;
  changed('firstRun stops', [lobby]);
  paidNow.value = false;
  changed('paid stops', [intro]);
  introSeenNow.value = true;
  changed('firstRun allows', [intro]);
  changed('a notification, on a page that asks', [over(lounge), home]);
  paidNow.value = true;
  changed('paid holds', [home]);
}
''';

/// The module `rooms` for the tests of the rules of its routes, which lists
/// the role of the conditions as [requires], [uses] or [provides] say.
ModuleDescriptor _rooms({
  Set<Role> requires = const {},
  Set<Role> uses = const {},
  bool provides = false,
}) =>
    ModuleDescriptor(
      id: const ModuleId('rooms'),
      description: 'Rooms',
      kind: ModuleKinds.feature,
      requires: requires,
      uses: uses,
      providers: [if (provides) const RoleProvider.plain(_clubRole)],
    );

/// The problems that the module rule [rule] of the router role finds in
/// [data], the routes and the guards of [module].
List<String> _problems(
  String rule,
  RoutesData data, {
  required ModuleDescriptor module,
}) {
  // The input can only be built by a role; a test role captures it.
  late ModuleRuleInput<RoutesData> input;
  final role = TestRole<RoutesData>(
    'capture',
    moduleRules: [
      ModuleRule(
        id: 'capture',
        description: 'Captures the input.',
        check: (captured) {
          input = captured;
          return const [];
        },
      ),
    ],
  );
  final contribution = role.data(data);
  role.checkModule(
    ModuleRuleRequest(
      hook: RoleHookRequest(
        data: [contribution.withOrigin(ModuleOrigin(module.id))],
        presentRoles: {role},
        context: testContext,
      ),
      module: module,
      contributions: [contribution],
    ),
  );
  final issues =
      routerRole.moduleRules.singleWhere((found) => found.id == rule).check(
            input,
          );
  for (final issue in issues) {
    expect(issue.origin, ModuleOrigin(module.id));
    expect(issue.isError, isTrue);
  }
  return [for (final issue in issues) issue.message];
}

void main() {
  group('a condition of the routes', () {
    test('is the one of its role with its name', () {
      expect(_member, const RouteCondition(_clubRole, 'member'));
      expect(
        _member.hashCode,
        const RouteCondition(_clubRole, 'member').hashCode,
      );
      // A condition of the same name of another role is another one, and
      // roles compare by identity.
      expect(_member, isNot(_paid));
      expect(_member, isNot(const RouteCondition(routerRole, 'member')));
      expect(_member, isNot(RouteCondition(TestRole<NoDsl>('club'), 'member')));
      expect(
        {_member, _paid, _clubPaid()},
        {_member, _paid},
      );
      // Messages name it by the id of its role.
      expect('$_member', 'club.member');
      expect(_member.role, same(_clubRole));
      expect(_member.name, 'member');
    });

    test(
        'is asked for by no route and stood for by no guard unless they say '
        'so', () {
      expect(_homeRoutes.routes.single.conditions, isEmpty);
      expect(_introRoutes.guards.single.condition, isNull);
      expect(_roomsRoutes.routes[1].conditions, [_member]);
      expect(_memberGuard.condition, _member);
    });
  });

  group('the conditions of RouterFacade', () {
    test(
        'a route asks for its conditions and for those of the routes above '
        'it, each once', () {
      final facade = _facade(_clubData);
      Set<RouteCondition> of(String path) => facade.routeAt(path)!.conditions;

      expect(of('/rooms'), isEmpty);
      expect(of('/rooms/members'), {_member});
      expect(of('/rooms/members/card'), {_member});
      expect(of('/rooms/lounge').toList(), [_member, _paid]);
      expect(of('/account/login'), isEmpty);

      // A child that lists the condition of its parent again, and one of
      // its own: those of the parent come first.
      final nested = _facade([
        dataOf(
          routerRole,
          RoutesData([
            Route(
              '/members',
              name: 'members',
              screen: _screen('MembersScreen', 'rooms'),
              conditions: const [_member],
              children: [
                Route(
                  'card',
                  name: 'card',
                  screen: _screen('CardScreen', 'rooms'),
                  conditions: const [_paid, _member],
                ),
              ],
            ),
          ]),
          module: 'rooms',
        ),
      ]);
      expect(
        nested.routeAt('/rooms/members/card')!.conditions.toList(),
        [_member, _paid],
      );
    });

    test(
        'the routes that ask for a condition are those of every module, in '
        'the order of the routes', () {
      final facade = _facade([
        ..._clubData,
        dataOf(
          routerRole,
          RoutesData([
            Route(
              '/',
              name: 'desk',
              screen: _screen('DeskScreen', 'desk'),
              conditions: const [_member],
            ),
          ]),
          module: 'desk',
        ),
      ]);

      expect(
        [for (final route in facade.routesAsking(_member)) route.fullName],
        ['rooms.members', 'rooms.card', 'rooms.lounge', 'desk.desk'],
      );
      expect(
        [for (final route in facade.routesAsking(_paid)) route.fullName],
        ['rooms.lounge'],
      );
      expect(facade.routesAsking(_invited), isEmpty);
    });

    test(
        'the gates come before the guards of conditions, those of each kind '
        'by stage, then in the order of the modules, and then as their '
        'module declares them', () {
      final facade = _facade(_clubData);

      // The gate of `intro`, of the first stage, though its module is
      // last; the gate of `account`, which the module declares after its
      // guard of a condition; and only then the guards of conditions, that
      // of the first stage first.
      expect(
        [for (final guard in facade.guards) guard.fullName],
        ['intro.firstRun', 'account.signedIn', 'shop.paid', 'account.member'],
      );
      expect(
        [for (final guard in facade.guards) guard.isGate],
        [true, true, false, false],
      );
      // The guards of a module stay as it declares them.
      expect(
        [
          for (final feature in facade.features)
            for (final guard in feature.guards) guard.fullName,
        ],
        ['shop.paid', 'account.member', 'account.signedIn', 'intro.firstRun'],
      );

      // A gate and a guard of a condition, each of either stage, with
      // their modules in both orders: the gate is always first.
      for (final ofGate in GuardStage.values) {
        for (final ofCondition in GuardStage.values) {
          for (final gateFirst in [true, false]) {
            final gate = dataOf(
              routerRole,
              RoutesData(
                _introRoutes.routes,
                guards: [
                  RouteGuard(
                    name: 'firstRun',
                    allows: const FunctionRef('introSeen', import: _introFile),
                    redirectTo: 'intro',
                    stage: ofGate,
                  ),
                ],
              ),
              module: 'intro',
            );
            final condition = dataOf(
              routerRole,
              RoutesData(
                _shopRoutes.routes,
                guards: [
                  RouteGuard(
                    name: 'paid',
                    allows: const FunctionRef('hasPaid', import: _shopFile),
                    redirectTo: 'plans',
                    stage: ofCondition,
                    condition: _paid,
                  ),
                ],
              ),
              module: 'shop',
            );
            expect(
              [
                for (final guard in _facade([
                  if (gateFirst) gate,
                  condition,
                  if (!gateFirst) gate,
                ]).guards)
                  guard.fullName,
              ],
              ['intro.firstRun', 'shop.paid'],
              reason: 'gate: ${ofGate.name}, condition: ${ofCondition.name}, '
                  'gate first: $gateFirst',
            );
          }
        }
      }
    });

    test(
        'the guard for a condition is the one of the app that stands for it, '
        'and none for a condition that no module has a guard for', () {
      final facade = _facade(_clubData);

      expect(facade.guardFor(_member)!.fullName, 'account.member');
      expect(facade.guardFor(_member)!.guard, same(_memberGuard));
      expect(facade.guardFor(_paid)!.fullName, 'shop.paid');
      expect(facade.guardFor(_invited), isNull);
      // An app without the module of the guard: the routes that ask for
      // the condition are still there, and nothing stands for it.
      final open = _facade([
        dataOf(routerRole, _homeRoutes),
        dataOf(routerRole, _roomsRoutes, module: 'rooms'),
      ]);
      expect(open.routesAsking(_member), hasLength(3));
      expect(open.guardFor(_member), isNull);
      expect(open.guards, isEmpty);
    });
  });

  group('the router template, in an app with conditions', () {
    /// The guards of `routeGuards` in the file that the template renders
    /// from [data], each as its code.
    Future<List<String>> guardsOf(List<RoleData<Object>> data) async {
      final rendered = await renderTemplate(routerRole, data: data);
      final router = rendered.files[RouterRole.appRouterFile]!;
      expectParses(router);
      final guards = parseString(content: router)
          .unit
          .declarations
          .whereType<TopLevelVariableDeclaration>()
          .map((declaration) => declaration.variables.variables.single)
          .singleWhere(
            (variable) => variable.name.lexeme == RouterRole.routeGuards,
          );
      return [
        for (final element in (guards.initializer! as ListLiteral).elements)
          element.toSource(),
      ];
    }

    test(
        'generates the gates first, and gives a guard of a condition the '
        'routes of every module that ask for it, which a gate has none of',
        () async {
      String guard(
        String name,
        String allows,
        String target,
        String flow, [
        String rest = '',
      ]) =>
          "RouteGuard('$name', allows: $allows(), redirectTo: const "
          '${target}Location(), flow: const {$flow}$rest)';
      const login = "'account.login', 'account.reset'";

      expect(await guardsOf(_clubData), [
        guard(
          'intro.firstRun',
          'guard0.introSeen',
          'IntroIntro',
          "'intro.intro'",
        ),
        guard(
          'account.signedIn',
          'guard1.isSignedIn',
          'AccountLogin',
          login,
          ', resumes: false',
        ),
        guard(
          'shop.paid',
          'guard2.hasPaid',
          'ShopPlans',
          "'shop.plans'",
          ", resumes: false, routes: const {'rooms.lounge'}",
        ),
        // The route below a route that asks for the condition is one of
        // its routes too, and the gate of the module has the same flow.
        guard(
          'account.member',
          'guard1.isMember',
          'AccountLogin',
          login,
          ", routes: const {'rooms.members', 'rooms.card', 'rooms.lounge'}",
        ),
      ]);
    });

    test(
        'gives a guard of a condition that no route of the app asks for no '
        'routes, which keeps it from being a gate', () async {
      // The app without the feature whose routes ask for the conditions.
      final guards = await guardsOf([
        dataOf(routerRole, _homeRoutes),
        dataOf(routerRole, _shopRoutes, module: 'shop'),
      ]);

      expect(guards.single, endsWith(', resumes: false, routes: const {})'));
      expect(
        await _printedBy(
          r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/shop/shop_plan.dart';

void main() {
  paidNow.value = false;
  final guard = routeGuards.single;
  print('${guard.routes}, ${guard.routes.runtimeType}');
  for (final route in ['home.root', 'shop.plans', null]) {
    print('$route: ${redirectOf(route)?.path}, over: ${flowIsOver(route)}');
  }
  paidNow.value = true;
  print('shop.plans: over: ${flowIsOver('shop.plans')}');
}
''',
          data: [
            dataOf(routerRole, _homeRoutes),
            dataOf(routerRole, _shopRoutes, module: 'shop'),
          ],
        ),
        '''
{}, _ConstSet<String>
home.root: null, over: false
shop.plans: null, over: false
null: null, over: false
shop.plans: over: true
''',
      );
    });

    test(
        'the class of a guard of the app has the routes that the guard keeps '
        'the user from, and none unless the guard says so', () async {
      final rendered = await renderTemplate(routerRole, data: _clubData);
      final guardClass = parseString(
        content: rendered.files[RouterRole.appRouterFile]!,
      ).unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (declared) => declared.namePart.typeName.lexeme == 'RouteGuard',
          );

      expect(
        guardClass.toSource(),
        allOf(
          contains('this.routes})'),
          contains('final Set<String>? routes;'),
        ),
      );
    });

    test(
        'a guard of a condition that does not hold sends the routes that ask '
        'for it to its target and no other route, after the gates; and its '
        'flow, the one of a gate too, is over only once both allow', () async {
      // The gates decide first, for every route outside their flows, of
      // whichever stage a guard of a condition is. With gates that allow,
      // the first guard whose condition a route asks for and that does not
      // allow decides, for that route alone: the lounge asks for two, and
      // the guard of `shop` comes first. The flow of the login is that of
      // a gate and of a guard of a condition: it is over once both allow,
      // and while the condition does not hold its routes show like any
      // other.
      expect(await _printedBy(_vmAskMain), '''
intro.firstRun shows /intro in place of every route
account.signedIn shows /account/login in place of every route
shop.paid shows /shop/plans in place of rooms.lounge
account.member shows /account/login in place of rooms.members, rooms.card, rooms.lounge
the gate does not allow, the condition does not hold
  shows account.login, account.reset
  /account/login: home.root, rooms.lobby, rooms.members, rooms.card, rooms.lounge, shop.plans, intro.intro, none
  over: shop.plans, intro.intro
the gate allows, the condition does not hold
  shows home.root, rooms.lobby, account.login, account.reset, shop.plans, intro.intro, none
  /account/login: rooms.members, rooms.card, rooms.lounge
  over: shop.plans, intro.intro
the gate allows, the condition holds
  shows home.root, rooms.lobby, rooms.members, rooms.card, rooms.lounge, account.login, account.reset, shop.plans, intro.intro, none
  over: account.login, account.reset, shop.plans, intro.intro
the gate does not allow, the condition holds
  shows account.login, account.reset
  /account/login: home.root, rooms.lobby, rooms.members, rooms.card, rooms.lounge, shop.plans, intro.intro, none
  over: shop.plans, intro.intro
two conditions do not hold
  shows home.root, rooms.lobby, account.login, account.reset, shop.plans, intro.intro, none
  /account/login: rooms.members, rooms.card
  /shop/plans: rooms.lounge
  over: intro.intro
the second condition of a route does not hold
  shows home.root, rooms.lobby, rooms.members, rooms.card, account.login, account.reset, shop.plans, intro.intro, none
  /shop/plans: rooms.lounge
  over: account.login, account.reset, intro.intro
a gate of the first stage does not allow
  shows intro.intro
  /intro: home.root, rooms.lobby, rooms.members, rooms.card, rooms.lounge, account.login, account.reset, shop.plans, none
  over: account.login, account.reset
''');
    });

    /// What [_vmFlowMain] prints, which the first test that reads it runs:
    /// the tests of the generated class each read some sections.
    late final flow = _printedBy(_vmFlowMain);

    /// What the generated class answers for a route that asks for the
    /// condition of the members while it does not hold and its flow is not
    /// open: the target of the guard over the page on top, with the routes
    /// of the flow that the request waits for.
    const opensLogin =
        '/account/login over the page, while account.login, account.reset';

    test(
        'the generated class opens the target of a guard with routes over '
        'the page on top for a route that asks for its condition, whichever '
        'pages the router has and with none; every other route shows, the '
        'flow of the guard too', () async {
      final printed = await flow;

      // A route below one that asks for the condition asks too. The lounge
      // asks for two conditions, of which the first holds. The answer is
      // the same from the platform or with no page yet, when the router
      // tells of no pages. A location that is no route asks for nothing.
      // And a notification that changes nothing leaves the flow open.
      expect(
        sectionOf(
          printed,
          'a route that asks for a condition that does not hold',
        ),
        '''
  asked /home on rooms.lobby: shows it
  asked /rooms/members?tab=a on rooms.lobby: $opensLogin
  asked /rooms/members/card on rooms.lobby + home.root: $opensLogin
  asked /rooms/lounge on rooms.lobby: $opensLogin
  asked /rooms/members on no page: $opensLogin
  asked /no/such on rooms.lobby: shows it
  a notification: stays
''',
      );
      // The flow is not over while the condition does not hold, though
      // every gate allows: its routes show like any other, over a page and
      // in place of the stack.
      expect(sectionOf(printed, 'the flow of a guard with routes'), '''
  asked /account/login on rooms.lobby: shows it
  asked /account/login/reset on account.login + rooms.lobby: shows it
  asked /account/login on no page: shows it
''');
    });

    test(
        'the generated class answers that the router shows nothing for a '
        'route that asks for a condition while a page of the flow of its '
        'guard is among the pages, on top or below another page', () async {
      // The target on top, a page of the flow over it or in its place, the
      // target alone, and a page outside the flow over the target: the
      // flow is open below that page, and it does not open a second time.
      // From the platform the router tells of no pages, since the location
      // takes the place of the stack, so the flow opens.
      expect(sectionOf(await flow, 'a request while the flow is open'), '''
  asked /rooms/members on account.login + rooms.lobby: nothing
  asked /rooms/members/card on account.reset + account.login + rooms.lobby: nothing
  asked /rooms/members on account.reset + rooms.lobby: nothing
  asked /rooms/members on account.login: nothing
  asked /rooms/members on rooms.lobby + account.login + home.root: nothing
  asked /rooms/members on no page: $opensLogin
''');
    });

    test(
        'once the condition holds, the generated class closes the pages of '
        'the flow and the pages over them, also a page of the flow below a '
        'page outside it; it answers the start of the app when the router '
        'cannot close them or no page stays below', () async {
      // The lowest page of the flow decides how many pages close: the
      // target, a page of the flow in its place, and with them a page over
      // them, of the flow or not. The request that the router kept is
      // asked about again and shows. A flow that took the place of the
      // stack, as after `go()` to its target or from the platform, has no
      // page below it, and a page that the router cannot close on its own
      // does not leave alone: the start of the app takes the place of the
      // stack. With no page of the flow, nothing happens: the class
      // remembers nothing for a guard with routes. A location of the flow
      // that is asked for now shows the start of the app.
      expect(
        sectionOf(await flow, 'the condition holds while its flow is open'),
        '''
  the target over a page: closes 1
  asked /rooms/members?tab=a on rooms.lobby: shows it
  a notification: stays
  two pages of the flow: closes 2
  a page of the flow in place of the target: closes 1
  a page outside the flow over the target: closes 2
  the target alone: /
  the chain of a page of the flow: /
  a page over the target, which has none below: /
  a page that the router can close, alone: /
  a page that it cannot close over a page: /
  no page of the flow: stays
  asked /account/login on rooms.lobby: /
  asked /account/login/reset on no page: /
''',
      );
    });

    test(
        'once a condition stops holding, the generated class closes the '
        'pages that ask for it and the pages over them, and answers the '
        'start of the app when no page stays below', () async {
      // A page that does not ask stays. A page that asks leaves, with the
      // page that was pushed over it, so the user is on the page that it
      // was opened from. A page that asks at the bottom of the stack
      // leaves for the start of the app, with what is over it.
      expect(sectionOf(await flow, 'a condition that stops holding'), '''
  on a page that does not ask: stays
  on a page that asks, over a page: closes 1
  below a page that does not ask: closes 2
  on a route below one that asks: closes 1
  on a page that asks, alone: /
  on the chain of a page that asks: /
  below a page, with no page below it: /
''');
    });

    test(
        'the generated class remembers no location for a guard with routes: '
        'the request waits with the router, and nothing happens once the '
        'condition holds when the router dropped it', () async {
      final printed = await flow;

      // The user leaves the flow for a page that does not ask, or for the
      // start of the app in place of a flow that is over: the condition
      // comes to hold, and the location that was asked for does not show.
      expect(sectionOf(printed, 'a request that the router dropped'), '''
  asked /rooms/members on rooms.lobby: $opensLogin
  asked /rooms on account.login + rooms.lobby: shows it
  member holds: stays
  member stops: stays
  asked /rooms/members on rooms.lobby: $opensLogin
  asked /intro on account.login + rooms.lobby: /
  member holds: stays
''');
      // So a gate that stops while the flow is open brings the user back
      // to the page that the flow was opened over, not to the location that
      // the flow was opened for.
      expect(
        sectionOf(
          printed,
          'a gate that brings the user back stops while the flow is open',
        ),
        '''
  member stops: stays
  asked /rooms/members on rooms.lobby: $opensLogin
  firstRun stops: /intro
  firstRun allows: /rooms
  member holds: stays
''',
      );
    });

    test(
        'for a route that asks for two conditions, the first guard that '
        'does not allow answers; once it allows, the router closes its flow, '
        'and the request, asked about again, opens the flow of the next',
        () async {
      // The guard of `shop` comes first. While its flow is open, a further
      // request for the lounge shows nothing. Once `shop` allows, the pages
      // of its flow close. The lounge is asked about again and opens the
      // target of the other guard, and shows once that allows.
      expect(sectionOf(await flow, 'a route that asks for two conditions'), '''
  both stop: stays
  asked /rooms/lounge on home.root: /shop/plans over the page, while shop.plans
  asked /rooms/lounge on shop.plans + home.root: nothing
  paid holds: closes 1
  asked /rooms/lounge on home.root: $opensLogin
  member holds: closes 1
  asked /rooms/lounge on home.root: shows it
''');
    });

    test(
        'when the pages that close reach below the flow that was opened '
        'last, the request that waits for it is dropped: the page that it '
        'was made on closes', () async {
      // A request for a route of the members, made on the target of
      // `shop`, opens the flow of the other guard over that target: a flow
      // is open for the guards that have it. Once `shop` allows, its flow
      // closes with what is over it, and the request was made on a page
      // that closes. The same goes for a request that was made on a page
      // that asks for a condition, once that condition stops holding below
      // the flow of the other one. A page over the flow that closes drops
      // nothing, and neither does the flow itself when it closes with a
      // page over it: the page that the request was made on stays.
      expect(
        sectionOf(await flow, 'the page that a request was made on closes'),
        '''
  both stop: stays
  asked /rooms/lounge on home.root: /shop/plans over the page, while shop.plans
  asked /rooms/members on shop.plans + home.root: $opensLogin
  paid holds below the flow of member: closes 2, and drops the request
  member holds, paid stops: stays
  asked /rooms/lounge on rooms.members + rooms.lobby: /shop/plans over the page, while shop.plans
  member stops below the flow of paid: closes 2, and drops the request
  member holds: stays
  asked /rooms/lounge on rooms.lobby: /shop/plans over the page, while shop.plans
  member stops over the flow of paid: closes 1
  paid holds, with a page over its flow: closes 2
''',
      );
    });

    test(
        'with a gate and a guard with routes that have one flow and change '
        'in one turn, as two guards over one notifier do, the gate decides '
        'while it does not allow, and the router leaves the flow for the '
        'location that was asked for behind the gate', () async {
      // Both stop on a page that asks for the condition: the target of the
      // gate takes the place of the stack, and the second notification
      // finds nothing to do. A location that is asked for behind the gate
      // is remembered, and shows once both allow: the first notification
      // answers it, and the second nothing. With nothing asked for, the
      // gate does not bring the user back, so the flow, which is over,
      // leaves for the start of the app.
      expect(
        sectionOf(
          await flow,
          'a gate and a condition with one flow, in one turn',
        ),
        '''
  both stop: /account/login
  the second notification: stays
  asked /rooms/members on account.login: /account/login
  both allow: /rooms/members
  the second notification: stays
  both stop: /account/login
  both allow, nothing asked for: /
''',
      );
    });

    test(
        'with a gate and a guard with routes that have one flow and change '
        'apart, the order decides: when the gate allows first, a location '
        'that asks for the condition is forgotten for the start of the app; '
        'when the condition holds first, the location shows once the gate '
        'allows', () async {
      final printed = await flow;

      // The gate allows first. The condition still keeps the user from the
      // location that was asked for behind the gate, and the class cannot
      // keep a request waiting: the user comes to the start of the app, and
      // nothing happens once the condition holds. With nothing asked for,
      // the flow stays, since it is not over, until the condition holds.
      // So two guards with one flow read one notifier.
      expect(
        sectionOf(
          printed,
          'a gate and a condition with one flow, the gate first',
        ),
        '''
  both stop: /account/login
  asked /rooms on account.login: /account/login
  asked /rooms/members on account.login: /account/login
  the gate allows: /
  asked /account/login on home.root: shows it
  the condition holds: stays
  both stop: /account/login
  the gate allows, nothing asked for: stays
  the condition holds: /
''',
      );
      // The condition holds first: the gate still keeps the user from
      // every location outside the flow, and the latest one that was asked
      // for shows once it allows.
      expect(
        sectionOf(
          printed,
          'a gate and a condition with one flow, the condition first',
        ),
        '''
  both stop: /account/login
  asked /rooms/members/card on account.login: /account/login
  the condition holds: stays
  asked /rooms on account.login: /account/login
  the gate allows: /rooms
''',
      );
      // The gate stops while the flow is open over a page: its target
      // takes the place of the stack, the request with it, and the gate
      // does not bring the user back.
      expect(
        sectionOf(printed, 'the gate of the flow stops while the flow is open'),
        '''
  member stops: stays
  asked /rooms/members on rooms.lobby: $opensLogin
  the gate stops: /account/login
  both allow: /
''',
      );
    });

    test(
        'KNOWN LIMIT: a location that asks for a condition and is asked for '
        'behind a gate is lost once the gate allows while the condition '
        'does not hold: the generated class answers the start of the app, '
        'though it opens the flow for the same location with no gate in its '
        'way', () async {
      // A link to a route of the members opens the app behind a gate, as
      // on a first launch. The class remembers it for the gate. Once the
      // gate allows, the user is no member, and the class, which opens a
      // flow only when it is asked and keeps no request waiting, answers
      // the start of the app and forgets the link: nothing happens once the
      // condition holds. The same link in an app whose gates allow opens
      // the target of the guard over the start of the app, and its request
      // waits with the router. To close the gap, `changed` would answer
      // with the flow to open and the request to keep.
      expect(
        sectionOf(
          await flow,
          'a link to a route that asks for a condition, behind a gate',
        ),
        '''
  firstRun stops: /intro
  asked /rooms/members on intro.intro: /intro
  firstRun allows: /
  a notification: stays
  member holds: stays
  member stops: stays
  asked /rooms/members on no page: $opensLogin
''',
      );
    });

    test(
        'the generated class forgets the location that a gate made it '
        'remember once the user asks for another one that no gate keeps '
        'them from', () async {
      // The gate allows, and the code of the app navigates before the
      // class is told, as a listener of the guard that comes before the
      // router does: the user has moved on, and the location that the gate
      // took them from does not take the place of that page.
      expect(
        sectionOf(
          await flow,
          'a location asked for once the gates allow, before the class is told',
        ),
        '''
  firstRun stops: /intro
  asked /home on intro.intro: shows it
  firstRun allows: stays
''',
      );
    });

    test(
        'a guard with routes that does not bring the user back makes the '
        'generated class forget what a gate made it remember when it stops '
        'allowing, and closes its pages like any other', () async {
      // It stops while the flow of a gate is shown, which the gate took the
      // user to from a location: the location is forgotten, and the user
      // comes to the start of the app once the gate allows.
      expect(
        sectionOf(
          await flow,
          'a guard with routes that does not bring the user back',
        ),
        '''
  firstRun stops: /intro
  paid stops: stays
  firstRun allows: /
  a notification, on a page that asks: closes 1
  paid holds: stays
''',
      );
    });

    test(
        'tells coding agents what tells a gate from a guard that keeps the '
        'user from some routes, with the name that the class of the app has '
        'for them', () async {
      final rendered = await renderTemplate(routerRole, data: _clubData);

      final note = rendered.notes.last.entryValue! as AgentNote;
      expectNamesOfCode(
        note,
        {
          RouterRole.appRouterFile: ['RouteGuard.routes', 'RouteGuard.flow'],
        },
        files: rendered.files,
      );
      // The same note as in an app whose guards are all gates: it tells of
      // the guards as such.
      final gates = await renderTemplate(
        routerRole,
        data: [
          dataOf(routerRole, _homeRoutes),
          dataOf(routerRole, _introRoutes, module: 'intro'),
        ],
      );
      expect(gates.notes.last.entryValue, note);
    });
  });

  group('the module rule router.routes, for a route with conditions', () {
    Route members({
      List<RouteCondition> conditions = const [_member],
      List<Route> children = const [],
      Destination? destination,
      bool startCandidate = false,
    }) =>
        Route(
          '/members',
          name: 'members',
          screen: _screen('MembersScreen', 'rooms'),
          conditions: conditions,
          children: children,
          destination: destination,
          startCandidate: startCandidate,
        );
    Route card({
      List<RouteCondition> conditions = const [],
      bool startCandidate = false,
    }) =>
        Route(
          'card',
          name: 'card',
          screen: _screen('CardScreen', 'rooms'),
          conditions: conditions,
          startCandidate: startCandidate,
        );
    List<String> problems(
      List<Route> routes, {
      ModuleDescriptor? module,
      List<RouteGuard> guards = const [],
    }) =>
        _problems(
          'router.routes',
          RoutesData(routes, guards: guards),
          module: module ?? _rooms(requires: {_clubRole}),
        );

    test(
        'accepts a condition of a role that the module requires, uses or '
        'provides, on a route outside the main navigation and the flows, '
        'with routes below it', () {
      for (final module in [
        _rooms(requires: {_clubRole}),
        _rooms(uses: {_clubRole}),
        _rooms(provides: true),
      ]) {
        expect(
          problems(_roomsRoutes.routes, module: module),
          isEmpty,
          reason: '${module.roles}',
        );
      }
      // A route may list a condition twice, and one of a route above it.
      expect(
        problems([
          members(
            conditions: const [_member, _member],
            children: [
              card(conditions: const [_member]),
            ],
          ),
        ]),
        isEmpty,
      );
    });

    test(
        'rejects a condition of a role that the module does not list, once '
        'for the route that lists it', () {
      expect(
        problems(
          [
            members(
              conditions: const [_member, _member, _paid],
              children: [card()],
            ),
          ],
          module: _rooms(uses: {layoutRole}),
        ),
        ['club.member', 'club.paid'].map(
          (condition) =>
              'The route "members" (/members) asks for the condition '
              '$condition, but the module neither requires, uses nor '
              'provides the club role, whose condition it is.',
        ),
      );
    });

    test('rejects a condition on a route of the main navigation', () {
      const tab = 'it is a destination of the main navigation';
      const below = 'it is below the destination "members" of the main '
          'navigation';
      String problem(
        String route,
        String where, [
        String asks = 'club.member',
      ]) =>
          'The route $route asks for the condition $asks, but $where; every '
          'user gets to the main navigation, so no route in it asks for a '
          'condition.';

      expect(
        problems([members(destination: _destination)]),
        [problem('"members" (/members)', tab)],
      );
      // A route below a destination is in its branch.
      expect(
        problems([
          members(
            conditions: const [],
            destination: _destination,
            children: [
              card(conditions: const [_paid]),
            ],
          ),
        ]),
        [problem('"card" (card)', below, 'club.paid')],
      );
      // The route that lists the condition gets the problem, not the
      // routes below it, which ask for it by being there.
      expect(
        problems([
          members(destination: _destination, children: [card()]),
        ]),
        [problem('"members" (/members)', tab)],
      );
    });

    test(
        'rejects a start candidate that asks for a condition, its own or one '
        'of a route above it', () {
      String problem(String route, String conditions) =>
          'The route $route is a start candidate but asks for $conditions; '
          'every user sees the screen that the app starts on, so a start '
          'candidate asks for no condition, and neither does a route above '
          'it.';

      expect(
        problems([members(startCandidate: true)]),
        [problem('"members" (/members)', 'the condition club.member')],
      );
      expect(
        problems([
          members(children: [card(startCandidate: true)]),
        ]),
        [problem('"card" (card)', 'the condition club.member')],
      );
      expect(
        problems([
          members(
            children: [
              card(conditions: const [_paid], startCandidate: true),
            ],
          ),
        ]),
        [problem('"card" (card)', 'the conditions club.member, club.paid')],
      );
      // A start candidate above a route that asks for one is none.
      expect(
        problems([
          members(
            conditions: const [],
            startCandidate: true,
            children: [
              card(conditions: const [_member]),
            ],
          ),
        ]),
        isEmpty,
      );
    });

    test('rejects a condition on a route in the flow of a guard', () {
      RouteGuard guard(String name) => RouteGuard(
            name: name,
            allows: const FunctionRef('isMember', import: _accountFile),
            redirectTo: 'members',
            stage: GuardStage.identity,
          );
      String problem(String route, String asks) =>
          'The route $route asks for $asks, but it is in the flow of the '
          'guard "first"; the router shows the routes of a flow to a user '
          'that the guard does not allow, so none of them asks for a '
          'condition.';

      // The target of a guard, the first of two that show it.
      expect(
        problems(
          [
            members(conditions: const [_member, _paid]),
          ],
          guards: [guard('first'), guard('second')],
        ),
        [
          problem(
            '"members" (/members)',
            'the conditions club.member, club.paid',
          ),
        ],
      );
      // A route below the target.
      expect(
        problems(
          [
            members(
              conditions: const [],
              children: [
                card(conditions: const [_member]),
              ],
            ),
          ],
          guards: [guard('first')],
        ),
        [problem('"card" (card)', 'the condition club.member')],
      );
      // A route outside the flow, next to the target.
      expect(
        problems(
          [
            members(conditions: const []),
            Route(
              '/lounge',
              name: 'lounge',
              screen: _screen('LoungeScreen', 'rooms'),
              conditions: const [_member],
            ),
          ],
          guards: [guard('first')],
        ),
        isEmpty,
      );
    });
  });

  group('the module rule router.guards, for a guard of a condition', () {
    ModuleDescriptor account({
      Set<Role> requires = const {},
      Set<Role> uses = const {},
      bool provides = false,
    }) =>
        ModuleDescriptor(
          id: const ModuleId('account'),
          description: 'Account',
          kind: ModuleKinds.feature,
          requires: requires,
          uses: uses,
          providers: [if (provides) const RoleProvider.plain(_clubRole)],
        );
    List<String> problems(
      List<RouteGuard> guards, {
      required ModuleDescriptor module,
    }) =>
        _problems(
          'router.guards',
          RoutesData(_accountRoutes.routes, guards: guards),
          module: module,
        );

    test(
        'accepts a guard of a condition of a role that the module requires '
        'or provides, next to a gate with the same target', () {
      for (final module in [
        account(requires: {_clubRole}),
        account(provides: true),
      ]) {
        expect(
          problems(_accountRoutes.guards, module: module),
          isEmpty,
          reason: '${module.roles}',
        );
      }
      // A guard for each of two conditions.
      expect(
        problems(
          const [
            _memberGuard,
            RouteGuard(
              name: 'paid',
              allows: FunctionRef('hasPaid', import: _accountFile),
              redirectTo: 'login',
              stage: GuardStage.identity,
              condition: _paid,
            ),
          ],
          module: account(requires: {_clubRole}),
        ),
        isEmpty,
      );
    });

    test(
        'rejects a guard of a condition of a role that the module only uses '
        'or does not list', () {
      const problem = 'The guard "member" stands for the condition '
          'club.member, but the module neither requires nor provides the '
          'club role, whose condition it is.';

      expect(
        problems(const [_memberGuard], module: account(uses: {_clubRole})),
        [problem],
      );
      expect(problems(const [_memberGuard], module: account()), [problem]);
    });

    test('rejects two guards of a module for one condition', () {
      expect(
        problems(
          const [_memberGuard, _memberGuardToo],
          module: account(requires: {_clubRole}),
        ).single,
        'Two guards of the module stand for the condition club.member; an '
        'app has one guard for a condition.',
      );
    });
  });

  group('the router template, for the guards of conditions of an app', () {
    test('accepts one guard for each condition', () {
      expect(
        routerRole.template.validate(inputOf(routerRole, data: _clubData)),
        isEmpty,
      );
    });

    test('rejects the guards of two modules that stand for one condition', () {
      final issues = routerRole.template.validate(
        inputOf(
          routerRole,
          data: [
            ..._clubData,
            dataOf(
              routerRole,
              RoutesData(
                [
                  Route(
                    '/',
                    name: 'desk',
                    screen: _screen('DeskScreen', 'desk'),
                  ),
                ],
                guards: const [
                  RouteGuard(
                    name: 'member',
                    allows: FunctionRef('isMember', import: _accountFile),
                    redirectTo: 'desk',
                    stage: GuardStage.welcome,
                    condition: _member,
                  ),
                ],
              ),
              module: 'desk',
            ),
          ],
        ),
      );

      // The app asks the guard of `desk` first, by its stage, so the guard
      // of `account` is the second one.
      expect(issues, hasLength(1));
      expect(
        issues.single.message,
        'The guard account.member and the guard desk.member both stand for '
        'the condition club.member; an app has one guard for a condition.',
      );
      expect(
        issues.single.hint,
        'Leave one of the modules desk and account out of the app.',
      );
      expect(issues.single.origin, const ModuleOrigin(ModuleId('account')));
      expect(issues.single.isError, isTrue);
    });
  });

  group('the start route of an app with conditions', () {
    Future<Object?> choose(
      String? start, {
      List<RoleData<Object>>? data,
    }) =>
        routerRole.template.choose(
          routerRole.choiceContext(
            RoleChoiceRequest(
              data: data ?? _clubData,
              presentRoles: {routerRole},
              optionValues: {'start': start},
              environment: FakeEnvironment(),
              context: testContext,
            ),
          ),
        );

    test(
        'is no route that asks for a condition, its own or that of a route '
        'above it, also in an app without a guard for the condition', () {
      // The app without the modules of the guards: the routes that ask for
      // the conditions show like any other there, and none starts the app
      // all the same.
      final open = [
        dataOf(routerRole, _homeRoutes),
        dataOf(routerRole, _roomsRoutes, module: 'rooms'),
      ];
      expect(_facade(open).guards, isEmpty);
      for (final (start, conditions) in [
        ('/rooms/members', 'the condition club.member'),
        ('/rooms/members/card', 'the condition club.member'),
        ('/rooms/lounge', 'the conditions club.member, club.paid'),
      ]) {
        expect(
          () => choose(start, data: open),
          throwsA(isA<SmfUsageException>()),
          reason: start,
        );
        expect(
          () => choose(start),
          throwsA(
            isA<SmfUsageException>().having(
              (e) => e.message,
              'message',
              'The app cannot start on $start, because the route asks for '
                  '$conditions: every user sees the screen that the app '
                  'starts on. That holds in an app without a guard for the '
                  'condition too, where the route shows like any other.',
            ),
          ),
          reason: start,
        );
      }
    });

    test('is a route that asks for none', () async {
      expect(await choose('/rooms'), const RouterChoice(startPath: '/rooms'));
      expect(await choose(null), const RouterChoice(startPath: '/home'));
    });
  });
}
