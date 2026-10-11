@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'router_vm.dart';
import 'support.dart';

ScreenRef _screen(String name, String feature) => ScreenRef(
      name,
      import: ImportRef.app(
        'features/$feature/${SmfNames.snakeCaseOf(name)}.dart',
      ),
    );

const _homeDestination = Destination(
  label: LocalizedText('label', en: 'Home'),
  icon: Fragment(
    'Icons.home',
    imports: [ImportRef('package:flutter/material.dart')],
  ),
);

/// The routes of a feature without guards: its start route, a destination
/// of the main navigation, with a child.
final List<Route> _homeRoutes = [
  Route(
    '/',
    name: 'root',
    screen: _screen('HomeScreen', 'home'),
    destination: _homeDestination,
    startCandidate: true,
    children: [
      Route(
        'details/:id',
        name: 'details',
        screen: _screen('DetailsScreen', 'home'),
        params: const [RouteParam.path('id', type: int)],
      ),
    ],
  ),
];

/// The file of the functions of the guards of the feature `intro`.
const _introFile = ImportRef.app('features/intro/intro_status.dart');

/// The file of the function of the guard of the feature `account`.
const _accountFile = ImportRef.app('features/account/account_composition.dart');

/// The routes of a feature with two guards: one shows its first route,
/// which has a child, and the other its second top-level route.
final RoutesData _introRoutes = RoutesData(
  [
    Route(
      '/',
      name: 'intro',
      screen: _screen('IntroScreen', 'intro'),
      children: [
        Route('terms', name: 'terms', screen: _screen('TermsScreen', 'intro')),
      ],
    ),
    Route(
      '/paywall',
      name: 'paywall',
      screen: _screen('PaywallScreen', 'intro'),
      params: const [RouteParam.query('plan', type: String, optional: true)],
    ),
  ],
  guards: const [
    RouteGuard(
      name: 'firstRun',
      allows: FunctionRef('introSeen', import: _introFile),
      redirectTo: 'intro',
      stage: GuardStage.welcome,
    ),
    RouteGuard(
      name: 'premium',
      allows: FunctionRef('isPremium', import: _introFile),
      redirectTo: 'paywall',
      stage: GuardStage.identity,
    ),
  ],
);

/// The routes of a feature with one guard, which shows its only route.
final RoutesData _accountRoutes = RoutesData(
  [Route('/login', name: 'login', screen: _screen('LoginScreen', 'account'))],
  guards: const [
    RouteGuard(
      name: 'signedIn',
      allows: FunctionRef('isSignedIn', import: _accountFile),
      redirectTo: 'login',
      stage: GuardStage.identity,
    ),
  ],
);

/// The guard of the feature `account` as one that does not bring the user
/// back, with the routes of the feature.
final RoutesData _sessionRoutes = RoutesData(
  _accountRoutes.routes,
  guards: const [
    RouteGuard(
      name: 'signedIn',
      allows: FunctionRef('isSignedIn', import: _accountFile),
      redirectTo: 'login',
      stage: GuardStage.identity,
      resumes: false,
    ),
  ],
);

/// The routes of an app without guards.
final List<RoleData<Object>> _data = [
  dataOf(routerRole, RoutesData(_homeRoutes)),
];

/// The routes of an app with guards: a feature without one, which can
/// start the app, and then the features with guards, in the order the app
/// asks them.
final List<RoleData<Object>> _guardedData = [
  ..._data,
  dataOf(routerRole, _introRoutes, module: 'intro'),
  dataOf(routerRole, _accountRoutes, module: 'account'),
];

/// The routes of an app with one guard: a feature without one, which can
/// start the app, and a feature with a guard.
final List<RoleData<Object>> _oneGuardData = [
  ..._data,
  dataOf(routerRole, _accountRoutes, module: 'account'),
];

/// The routes of an app whose modules are listed against the stages of
/// their guards: `account`, whose guard is of the stage `identity` and does
/// not bring the user back, comes before `intro`, whose first guard is of
/// the stage `welcome`. The app asks the first guard of `intro`, then the
/// guard of `account`, and then the second guard of `intro`, which is of
/// the stage `identity` too.
final List<RoleData<Object>> _accountFirstData = [
  ..._data,
  dataOf(routerRole, _sessionRoutes, module: 'account'),
  dataOf(routerRole, _introRoutes, module: 'intro'),
];

/// The routes of an app whose two guards show one target, so that both
/// have one flow: the first route of `intro` with its child.
final List<RoleData<Object>> _sharedTargetData = [
  ..._data,
  dataOf(
    routerRole,
    RoutesData(
      _introRoutes.routes,
      guards: const [
        RouteGuard(
          name: 'firstRun',
          allows: FunctionRef('introSeen', import: _introFile),
          redirectTo: 'intro',
          stage: GuardStage.welcome,
        ),
        RouteGuard(
          name: 'premium',
          allows: FunctionRef('isPremium', import: _introFile),
          redirectTo: 'intro',
          stage: GuardStage.identity,
        ),
      ],
    ),
    module: 'intro',
  ),
];

RouterFacade _facade(List<RoleData<Object>> data) =>
    routerRole.facadeOf(inputOf(routerRole, data: data));

/// The routes of the feature `home` for the tests of the rules of its
/// guards: its start route with its child; a route outside the main
/// navigation with a child, which a guard can show; and a route that needs
/// a value.
final List<Route> _gatedRoutes = [
  ..._homeRoutes,
  Route(
    '/gate',
    name: 'gate',
    screen: _screen('GateScreen', 'home'),
    children: [
      Route('step', name: 'step', screen: _screen('StepScreen', 'home')),
    ],
  ),
  Route(
    '/items/:id',
    name: 'item',
    screen: _screen('ItemScreen', 'home'),
    params: const [RouteParam.path('id', type: int)],
  ),
];

/// The file of the functions of the guards of the feature `home`.
const _gateFile = ImportRef.app('features/home/home_gate.dart');

/// A guard of the feature `home` named [name] that shows [redirectTo], with
/// the function [allows].
RouteGuard _guard({
  String name = 'open',
  String redirectTo = 'gate',
  FunctionRef allows = const FunctionRef('isOpen', import: _gateFile),
}) =>
    RouteGuard(
      name: name,
      allows: allows,
      redirectTo: redirectTo,
      stage: GuardStage.welcome,
    );

/// The issues of the module rule `router.guards`, if the role has it, for
/// [guards] of the feature `home`, whose routes are [routes].
List<SmfIssue> _guardIssues(List<RouteGuard> guards, {List<Route>? routes}) {
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
  final data = role.data(RoutesData(routes ?? _gatedRoutes, guards: guards));
  role.checkModule(
    ModuleRuleRequest(
      hook: RoleHookRequest(
        data: [data.withOrigin(const ModuleOrigin(ModuleId('home')))],
        presentRoles: {role},
        context: testContext,
      ),
      module: const ModuleDescriptor(
        id: ModuleId('home'),
        description: 'Home',
        kind: ModuleKinds.feature,
      ),
      contributions: [data],
    ),
  );
  return [
    for (final rule in routerRole.moduleRules)
      if (rule.id == 'router.guards') ...rule.check(input),
  ];
}

/// The problems that the module rule `router.guards` finds in [guards] of
/// the feature `home`, whose routes are [routes].
List<String> _guardProblems(List<RouteGuard> guards, {List<Route>? routes}) =>
    [for (final issue in _guardIssues(guards, routes: routes)) issue.message];

/// The issues of the structural rules of the router in the app of [request]
/// whose messages start with [start].
List<SmfIssue> _structuralIssues(String start, StructuralRuleRequest request) =>
    [
      for (final issue in routerRole.checkStructure(request))
        if (issue.message.startsWith(start)) issue,
    ];

/// The functions of the guards of the feature `intro`, which count their
/// calls, over notifiers that a test sets.
const _vmIntroStatus = '''
import 'package:flutter/foundation.dart';

final ValueNotifier<bool> introSeenNow = ValueNotifier(false);

final ValueNotifier<bool> premiumNow = ValueNotifier(false);

int introSeenCalls = 0;

int isPremiumCalls = 0;

ValueListenable<bool> introSeen() {
  introSeenCalls++;
  return introSeenNow;
}

ValueListenable<bool> isPremium() {
  isPremiumCalls++;
  return premiumNow;
}
''';

/// The function of the guard of the feature `account`.
const _vmAccount = '''
import 'package:flutter/foundation.dart';

final ValueNotifier<bool> signedInNow = ValueNotifier(false);

ValueListenable<bool> isSignedIn() => signedInNow;
''';

/// Prints the guards of the app, and then what `redirectOf()` says of some
/// routes, and of a screen that is no route (`none`), as the guards open
/// and close, with the routes whose flow `flowIsOver()` says is over, and
/// how often `guardChanges` notified and the functions were called.
const _vmGuardsMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/account/account_composition.dart';
import 'package:my_app/features/intro/intro_status.dart';

void main() {
  print('functions called before the first use: $introSeenCalls');
  var changes = 0;
  guardChanges.addListener(() => changes++);
  for (final guard in routeGuards) {
    print(
      '${guard.name} shows ${guard.redirectTo.path} and allows '
      '${guard.flow.join(', ')}',
    );
  }
  const routes = [
    'home.root',
    'intro.intro',
    'intro.terms',
    'intro.paywall',
    'account.login',
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

  ask('none allows');
  introSeenNow.value = true;
  ask('firstRun allows');
  premiumNow.value = true;
  ask('firstRun and premium allow');
  signedInNow.value = true;
  ask('all allow');
  premiumNow.value = false;
  ask('premium stopped');
  introSeenNow.value = false;
  ask('firstRun stopped too');
  // A value that stays is no change.
  introSeenNow.value = false;
  print('changes: $changes');
  print('calls: $introSeenCalls, $isPremiumCalls');
}
''';

/// Prints what `GuardedNavigation` of the app answers a router that knows
/// a location by its URI, as it is asked about locations and told of the
/// pages of a stack while the guards open and close. The pages are written
/// as `pagesOf` of [vmAnswers] reads them. The app has no guard with routes,
/// so no answer depends on the pages that a location is asked for on top
/// of, and the script gives none.
const _vmMemoryMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/account/account_composition.dart';
import 'package:my_app/features/intro/intro_status.dart';

import 'answers.dart';

final guards = GuardedNavigation<String>(
  start: '/',
  locationOf: (location) => location.path,
);

void asked(String? route, String location) {
  final answer = guards.asked(route, location, onTopOf: const []);
  print('  asked $location: ${whenAsked(answer)}');
}

void changed(String what, List<String> pages) {
  print('  $what: ${whenChanged(guards.changed(pagesOf(pages)))}');
}

void main() {
  print('asked while no guard allows');
  asked('home.root', '/home');
  asked('intro.terms', '/intro/terms');
  asked('account.login', '/account/login');
  asked(null, '/no/such?x=1');
  asked('home.details', '/home/details/5?tab=a');
  introSeenNow.value = true;
  changed('firstRun allows', ['intro.intro /intro']);
  premiumNow.value = true;
  changed('premium allows', ['intro.paywall /intro/paywall']);
  signedInNow.value = true;
  const details = ['home.details /home/details/5?tab=a', 'home.root /home'];
  changed('signedIn allows', ['account.login /account/login']);
  changed('a notification', details);

  print('pages that a change takes out of the stack');
  signedInNow.value = false;
  changed('signedIn stops', ['home.details /home/details/9 pushed', ...details]);
  premiumNow.value = false;
  changed('premium stops', ['account.login /account/login']);
  changed('a page outside the flows', ['home.root /home']);
  premiumNow.value = true;
  changed('premium allows', ['intro.paywall /intro/paywall']);
  signedInNow.value = true;
  changed('signedIn allows', ['account.login /account/login']);
  signedInNow.value = false;
  changed('signedIn stops', ['home.details /home/details/9 pushed']);
  signedInNow.value = true;
  changed('signedIn allows', ['account.login /account/login']);

  print('a flow that is over');
  asked('intro.terms', '/intro/terms');
  asked('intro.paywall', '/intro/paywall?plan=a');
  asked('account.login', '/account/login');
  asked('home.root', '/home');
  asked(null, '/no/such');
  changed('a notification', ['home.root /home']);
  const flow = ['intro.terms /intro/terms', 'intro.intro /intro'];
  changed('a notification, a page of the flow on top', flow);

  print('a flow shown with nothing remembered');
  introSeenNow.value = false;
  changed('firstRun stops', flow);
  asked('intro.terms', '/intro/terms');
  changed('a notification', flow);
  premiumNow.value = false;
  changed('premium stops', flow);
  premiumNow.value = true;
  changed('premium allows', flow);
  introSeenNow.value = true;
  changed('firstRun allows', flow);
  asked('intro.terms', '/intro/terms');

  print('a flow of a guard that allows, behind a guard that does not');
  premiumNow.value = false;
  const paywall = ['intro.paywall /intro/paywall'];
  changed('premium stops', paywall);
  asked('intro.terms', '/intro/terms');
  asked('intro.paywall', '/intro/paywall');
  introSeenNow.value = false;
  changed('firstRun stops', paywall);
  introSeenNow.value = true;
  changed('firstRun allows', ['intro.intro /intro']);
  premiumNow.value = true;
  changed('premium allows', paywall);

  print('a location of a flow asked last');
  introSeenNow.value = false;
  changed('firstRun stops', ['home.root /home']);
  asked('account.login', '/account/login');
  introSeenNow.value = true;
  changed('firstRun allows', ['intro.intro /intro']);

  print('the location / asked last');
  signedInNow.value = false;
  changed('signedIn stops', ['home.root /home']);
  asked(null, '/');
  signedInNow.value = true;
  changed('signedIn allows', ['account.login /account/login']);
}
''';

/// Prints the guards of the app in the order of `routeGuards`, and the
/// target that `redirectOf()` answers for a route outside every flow as the
/// guards start allowing one after another, in the order of the modules.
const _vmOrderMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/account/account_composition.dart';
import 'package:my_app/features/intro/intro_status.dart';

void main() {
  print([for (final guard in routeGuards) guard.name].join(', '));
  String shown() => redirectOf('home.root')?.path ?? 'shows it';
  print('none allows: ${shown()}');
  signedInNow.value = true;
  print('signedIn allows: ${shown()}');
  introSeenNow.value = true;
  print('firstRun allows too: ${shown()}');
  signedInNow.value = false;
  print('signedIn stopped: ${shown()}');
  signedInNow.value = true;
  premiumNow.value = true;
  print('all allow: ${shown()}');
}
''';

/// Prints what `GuardedNavigation` answers in an app whose guard
/// `account.signedIn` does not bring the user back, while the guards before
/// and after it do, as that guard and the others stop and start allowing:
/// alone, behind a guard that does not allow, before one, and with the
/// class told of each change or asked only later. The pages are written as
/// in [_vmMemoryMain].
const _vmResumesMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/account/account_composition.dart';
import 'package:my_app/features/intro/intro_status.dart';

import 'answers.dart';

final guards = GuardedNavigation<String>(
  start: '/',
  locationOf: (location) => location.path,
);

void asked(String? route, String location) {
  final answer = guards.asked(route, location, onTopOf: const []);
  print('  asked $location: ${whenAsked(answer)}');
}

void changed(String what, List<String> pages) {
  print('  $what: ${whenChanged(guards.changed(pagesOf(pages)))}');
}

void main() {
  const intro = ['intro.intro /intro'];
  const login = ['account.login /account/login'];
  const paywall = ['intro.paywall /intro/paywall'];
  const details = ['home.details /home/details/5?tab=a', 'home.root /home'];

  print('a first launch');
  asked('home.details', '/home/details/3');
  introSeenNow.value = true;
  changed('firstRun allows', intro);
  signedInNow.value = true;
  changed('signedIn allows', login);
  premiumNow.value = true;
  changed('premium allows', paywall);

  print('the guard stops allowing');
  signedInNow.value = false;
  changed('signedIn stops', ['home.details /home/details/9 pushed', ...details]);
  changed('a notification', login);
  signedInNow.value = true;
  changed('signedIn allows', login);
  changed('a notification', ['home.root /home']);

  print('a location asked for while it does not allow');
  signedInNow.value = false;
  changed('signedIn stops', details);
  asked('home.details', '/home/details/7');
  asked('account.login', '/account/login');
  signedInNow.value = true;
  changed('signedIn allows', login);
  changed('a notification', ['home.details /home/details/7', 'home.root /home']);

  print('it stops behind a guard that brings the user back');
  introSeenNow.value = false;
  changed('firstRun stops', details);
  signedInNow.value = false;
  changed('signedIn stops', intro);
  introSeenNow.value = true;
  changed('firstRun allows', intro);
  signedInNow.value = true;
  changed('signedIn allows', login);

  print('it stops before a guard that brings the user back');
  signedInNow.value = false;
  changed('signedIn stops', details);
  introSeenNow.value = false;
  changed('firstRun stops', login);
  introSeenNow.value = true;
  changed('firstRun allows', intro);
  signedInNow.value = true;
  changed('signedIn allows', login);

  print('it stops and allows again behind a guard that does not allow');
  introSeenNow.value = false;
  changed('firstRun stops', details);
  signedInNow.value = false;
  changed('signedIn stops', intro);
  signedInNow.value = true;
  changed('signedIn allows', intro);
  introSeenNow.value = true;
  changed('firstRun allows', intro);

  print('a location that was asked for before it stops');
  introSeenNow.value = false;
  changed('firstRun stops', details);
  asked('home.details', '/home/details/8');
  signedInNow.value = false;
  changed('signedIn stops', intro);
  introSeenNow.value = true;
  changed('firstRun allows', intro);
  signedInNow.value = true;
  changed('signedIn allows', login);

  print('it stops without the class being told, which is asked next');
  introSeenNow.value = false;
  changed('firstRun stops', details);
  signedInNow.value = false;
  asked('intro.terms', '/intro/terms');
  signedInNow.value = true;
  introSeenNow.value = true;
  changed('firstRun allows', intro);

  print('it stops while a guard after it does not allow');
  premiumNow.value = false;
  changed('premium stops', details);
  signedInNow.value = false;
  changed('signedIn stops', paywall);
  signedInNow.value = true;
  changed('signedIn allows', login);
  premiumNow.value = true;
  changed('premium allows', paywall);

  print('a guard that brings the user back');
  introSeenNow.value = false;
  changed('firstRun stops', ['home.details /home/details/9 pushed', ...details]);
  introSeenNow.value = true;
  changed('firstRun allows', intro);
  premiumNow.value = false;
  changed('premium stops', ['home.root /home']);
  premiumNow.value = true;
  changed('premium allows', paywall);
}
''';

/// Prints what `flowIsOver()` and `GuardedNavigation` answer in an app whose
/// two guards show one target, so that both have one flow: when the class
/// is told of no pages, as by a router that has none yet, and as the two
/// guards start and stop allowing while a page of the flow is on top.
const _vmSharedTargetMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/intro/intro_status.dart';

import 'answers.dart';

void main() {
  // The router is created while no guard allows, and has no page yet.
  final guards = GuardedNavigation<String>(
    start: '/',
    locationOf: (location) => location.path,
  );
  String told(List<(String, String)> pages) => whenChanged(
        guards.changed([
          for (final (route, location) in pages)
            (route: route, location: location, pushed: false),
        ]),
      );
  String asked(String route, String location) =>
      whenAsked(guards.asked(route, location, onTopOf: const []));
  String over() => flowIsOver('intro.terms') ? 'over' : 'not over';
  const flow = [('intro.terms', '/intro/terms'), ('intro.intro', '/intro')];

  print('a router without a page');
  print('  no guard allows, no pages: ${told(const [])}');

  print('two guards with one target, with nothing remembered');
  print('  no guard allows: ${over()}');
  print('  asked /intro/terms: ${asked('intro.terms', '/intro/terms')}');
  introSeenNow.value = true;
  print('  firstRun allows: ${told(flow)}, ${over()}');
  print('  asked /intro/terms: ${asked('intro.terms', '/intro/terms')}');
  premiumNow.value = true;
  print('  premium allows: ${told(flow)}, ${over()}');
  print('  asked /intro/terms: ${asked('intro.terms', '/intro/terms')}');
  print('  both allow, no pages: ${told(const [])}');

  print('two guards with one target, in the other order');
  introSeenNow.value = false;
  print('  firstRun stops: ${told(const [('home.root', '/home')])}, ${over()}');
  premiumNow.value = false;
  print('  premium stops: ${told(flow)}, ${over()}');
  premiumNow.value = true;
  print('  premium allows: ${told(flow)}, ${over()}');
  print('  asked /intro/terms: ${asked('intro.terms', '/intro/terms')}');
  introSeenNow.value = true;
  print('  firstRun allows: ${told(flow)}, ${over()}');
}
''';

void main() {
  group('the guards of a module', () {
    test('a module has no guards unless it declares some', () {
      expect(RoutesData(_homeRoutes).guards, isEmpty);
      expect(
        [for (final guard in _introRoutes.guards) '$guard'],
        ['guard firstRun', 'guard premium'],
      );
    });
  });

  group('the guards of RouterFacade', () {
    test(
        'come in the order of the features and of their guards, each with '
        'its full name, its target and its flow', () {
      final facade = _facade(_guardedData);

      expect(
        [for (final guard in facade.guards) guard.fullName],
        ['intro.firstRun', 'intro.premium', 'account.signedIn'],
      );
      expect(
        [for (final guard in facade.guards) guard.target.fullPath],
        ['/intro', '/intro/paywall', '/account/login'],
      );
      // The target and the routes below it, parents first.
      expect(
        [
          for (final guard in facade.guards)
            [for (final route in guard.flow) route.fullName],
        ],
        [
          ['intro.intro', 'intro.terms'],
          ['intro.paywall'],
          ['account.login'],
        ],
      );
      final firstRun = facade.guards.first;
      expect(firstRun.guard, same(_introRoutes.guards.first));
      expect('${firstRun.feature.module}', 'intro');
      expect(firstRun.feature.guards, facade.guards.take(2));
      expect(firstRun.flow.first, same(facade.routeAt('/intro')));
      expect('$firstRun', 'guard intro.firstRun');
      expect(_facade(_data).guards, isEmpty);
    });

    test(
        'come by stage, whatever the order of the modules, then in the order '
        'of the modules, and then as their module declares them', () {
      // An onboarding comes before a sign-in though its module is listed
      // after: `account` before `intro`, whose first guard is of the stage
      // before. The second guard of `intro` is of the stage of the guard
      // of `account`, so it comes after it, in the order of the modules.
      final facade = _facade(_accountFirstData);
      expect(
        [for (final guard in facade.guards) guard.fullName],
        ['intro.firstRun', 'account.signedIn', 'intro.premium'],
      );
      // The guards of a module stay as it declares them.
      expect(
        [
          for (final feature in facade.features)
            for (final guard in feature.guards) guard.fullName,
        ],
        ['account.signedIn', 'intro.firstRun', 'intro.premium'],
      );

      // Every arrangement of the stages of three guards, two of them of one
      // module, with the modules in both orders.
      const stages = GuardStage.values;
      expect(stages, [GuardStage.welcome, GuardStage.identity]);
      RouteGuard staged(RouteGuard guard, GuardStage stage) => RouteGuard(
            name: guard.name,
            allows: guard.allows,
            redirectTo: guard.redirectTo,
            stage: stage,
          );
      var arrangements = 0;
      for (final firstRun in stages) {
        for (final premium in stages) {
          for (final signedIn in stages) {
            for (final accountFirst in [false, true]) {
              final intro = dataOf(
                routerRole,
                RoutesData(
                  _introRoutes.routes,
                  guards: [
                    staged(_introRoutes.guards.first, firstRun),
                    staged(_introRoutes.guards.last, premium),
                  ],
                ),
                module: 'intro',
              );
              final account = dataOf(
                routerRole,
                RoutesData(
                  _accountRoutes.routes,
                  guards: [staged(_accountRoutes.guards.single, signedIn)],
                ),
                module: 'account',
              );
              // The guards in the order of the modules and of their
              // declarations, each with its stage.
              final declared = [
                if (accountFirst) ('account.signedIn', signedIn),
                ('intro.firstRun', firstRun),
                ('intro.premium', premium),
                if (!accountFirst) ('account.signedIn', signedIn),
              ];
              expect(
                [
                  for (final guard in _facade([
                    ..._data,
                    if (accountFirst) account,
                    intro,
                    if (!accountFirst) account,
                  ]).guards)
                    guard.fullName,
                ],
                [
                  for (final (name, stage) in declared)
                    if (stage == GuardStage.welcome) name,
                  for (final (name, stage) in declared)
                    if (stage == GuardStage.identity) name,
                ],
                reason: 'firstRun: ${firstRun.name}, premium: ${premium.name}, '
                    'signedIn: ${signedIn.name}, account first: $accountFirst',
              );
              arrangements++;
            }
          }
        }
      }
      expect(arrangements, 16);
    });

    test(
        'a guard brings the user back unless it says otherwise, and has the '
        'stage that its module gives it', () {
      const guard = RouteGuard(
        name: 'firstRun',
        allows: FunctionRef('introSeen', import: _introFile),
        redirectTo: 'intro',
        stage: GuardStage.welcome,
      );
      expect(guard.resumes, isTrue);
      expect(guard.stage, GuardStage.welcome);
      final signedIn = _sessionRoutes.guards.single;
      expect(signedIn.resumes, isFalse);
      expect(signedIn.stage, GuardStage.identity);
    });

    test(
        'merge the guards of the data of a module, and leave out a guard '
        'whose target is no top-level route of its module', () {
      const guard = RouteGuard(
        name: 'premium',
        allows: FunctionRef('isPremium', import: _introFile),
        redirectTo: 'paywall',
        stage: GuardStage.identity,
      );
      final facade = _facade([
        dataOf(
          routerRole,
          RoutesData(_introRoutes.routes, guards: [_introRoutes.guards.first]),
          module: 'intro',
        ),
        // A route of another module, a child and a route that is not there.
        dataOf(
          routerRole,
          RoutesData(
            _homeRoutes,
            guards: [
              for (final route in ['intro', 'details', 'nowhere'])
                _guard(name: route, redirectTo: route),
            ],
          ),
        ),
        dataOf(
          routerRole,
          const RoutesData([], guards: [guard]),
          module: 'intro',
        ),
        // A module without routes has no feature for its guards.
        dataOf(
          routerRole,
          const RoutesData([], guards: [guard]),
          module: 'empty',
        ),
        // Data that does not come from a module.
        routerRole
            .data(_accountRoutes)
            .withOrigin(const RoleTemplateOrigin(layoutRole)),
      ]);

      expect(
        [for (final guard in facade.guards) guard.fullName],
        ['intro.firstRun', 'intro.premium'],
      );
      expect(facade.features.last.guards, isEmpty);
    });
  });

  group('the router template', () {
    test('generates nothing of the guards in an app without guards', () async {
      final rendered = await renderTemplate(routerRole, data: _data);

      final router = rendered.files[RouterRole.appRouterFile]!;
      for (final name in [
        'RouteGuard',
        RouterRole.routeGuards,
        RouterRole.redirectOf,
        RouterRole.flowIsOver,
        RouterRole.guardChanges,
        RouterRole.guardedNavigation,
        'foundation.dart',
      ]) {
        expect(router, isNot(contains(name)), reason: name);
      }
      // Nor does the guide for coding agents tell of what the app lacks:
      // it has the note of the role alone.
      expect(rendered.notes.single.entryValue, agentNoteOf(routerRole));
    });

    test(
        'tells coding agents about the guards in an app with guards, be it '
        'one guard or several, after the note of the role, with the names '
        'that its files declare there', () async {
      const socket = AppEntryRole.agentSections;
      final notes = <AgentNote>[];
      for (final (guards, data) in [(1, _oneGuardData), (3, _guardedData)]) {
        final reason = 'The number of the guards of the app: $guards';
        expect(
          routerRole.facadeOf(inputOf(routerRole, data: data)).guards,
          hasLength(guards),
        );
        final rendered = await renderTemplate(routerRole, data: data);

        expect(rendered.notes, hasLength(2), reason: reason);
        expect(rendered.notes.first.entryValue, agentNoteOf(routerRole));
        final entry = rendered.notes.last;
        expect(entry.socket, socket);
        expect(entry.entryKey, routerRole.description);
        expect(socket.problemsWith(entry), isEmpty);
        final note = entry.entryValue! as AgentNote;
        notes.add(note);
        // What the role guarantees, whichever module provides it.
        expect(note.isOfRole, isTrue);
        expect(note.text, contains('`${RouterRole.appRouterFile}`'));
        expectNamesOfCode(
          note,
          {
            RouterRole.appRouterFile: [
              'RouteGuard',
              'RouteGuard.allows',
              'RouteGuard.redirectTo',
              // The routes that no code of the app navigates to.
              'RouteGuard.flow',
              // Whether the user comes back to where they were.
              'RouteGuard.resumes',
              // The routes that a guard keeps the user from, if not all.
              'RouteGuard.routes',
              RouterRole.routeGuards,
              // What a request for such a route does once its guard allows.
              'AppNavigator.go',
              'AppNavigator.push',
              'AppNavigator.replace',
            ],
          },
          files: rendered.files,
        );

        // The section has the two notes of the role, in this order, and
        // names only files that the app entry and the role guarantee.
        final section = socket.render(rendered.notes)[socket.tag]!;
        expect(
          section,
          contains('${agentNoteOf(routerRole).text}\n\n${note.text}'),
        );
        final issues = appEntryRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            files: const {},
            texts: {AppEntryRole.agentsFile: '# AGENTS.md\n$section\n'},
            owners: {
              for (final role in <Role>[appEntryRole, routerRole]) ...{
                for (final path in role.interface.files)
                  path: RoleTemplateOrigin(role),
                for (final symbol in role.interface.symbols)
                  symbol.path: RoleTemplateOrigin(role),
              },
            },
          ),
        );
        expect(
          [for (final issue in issues) issue.message],
          isEmpty,
          reason: reason,
        );
      }
      // The note tells of the guards as such, not of those of one app.
      expect(notes.toSet(), hasLength(1));
    });

    test(
        'generates the guards of the app next to its router, in the order '
        'the app asks them, with the files of their functions under '
        'prefixes of its own', () async {
      final rendered = await renderTemplate(routerRole, data: _guardedData);

      final router = rendered.files[RouterRole.appRouterFile]!;
      expectParses(router);
      final unit = parseString(content: router).unit;
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            if (directive.prefix case final prefix?)
              '${directive.uri.stringValue} as ${prefix.name}'
            else
              directive.uri.stringValue,
        ],
        containsAll([
          'package:flutter/foundation.dart',
          // The two guards of intro are in one file.
          'package:my_app/features/intro/intro_status.dart as guard0',
          'package:my_app/features/account/account_composition.dart as guard1',
        ]),
      );
      final declared = [
        for (final declaration in unit.declarations)
          switch (declaration) {
            ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
            FunctionDeclaration(:final name) => name.lexeme,
            TopLevelVariableDeclaration(:final variables) =>
              variables.variables.single.name.lexeme,
            _ => null,
          },
      ];
      expect(
        declared,
        containsAllInOrder([
          'RouteGuard',
          RouterRole.routeGuards,
          RouterRole.redirectOf,
          RouterRole.flowIsOver,
          RouterRole.guardChanges,
          RouterRole.guardedNavigation,
        ]),
      );
      final guards = unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .map((declaration) => declaration.variables.variables.single)
          .singleWhere(
            (variable) => variable.name.lexeme == RouterRole.routeGuards,
          );
      String guard(String name, String allows, String target, String flow) =>
          "RouteGuard('$name', allows: $allows(), redirectTo: const "
          '${target}Location(), flow: const {$flow})';
      expect(
        [
          for (final element in (guards.initializer! as ListLiteral).elements)
            element.toSource(),
        ],
        [
          guard(
            'intro.firstRun',
            'guard0.introSeen',
            'IntroIntro',
            "'intro.intro', 'intro.terms'",
          ),
          // The target takes an optional value, which the guard leaves out.
          guard(
            'intro.premium',
            'guard0.isPremium',
            'IntroPaywall',
            "'intro.paywall'",
          ),
          guard(
            'account.signedIn',
            'guard1.isSignedIn',
            'AccountLogin',
            "'account.login'",
          ),
        ],
      );
      // The location classes of the targets are those of the facade.
      final navigation = rendered.files[RouterRole.navigationFile]!;
      for (final target in ['IntroIntro', 'IntroPaywall', 'AccountLogin']) {
        expect(navigation, contains('final class ${target}Location extends'));
      }
    });

    test(
        'generates the guards by stage, against the order of the modules, '
        'and says of a guard that does not bring the user back that it does '
        'not', () async {
      final rendered = await renderTemplate(
        routerRole,
        data: _accountFirstData,
      );

      final router = rendered.files[RouterRole.appRouterFile]!;
      expectParses(router);
      final unit = parseString(content: router).unit;
      final guards = unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .map((declaration) => declaration.variables.variables.single)
          .singleWhere(
            (variable) => variable.name.lexeme == RouterRole.routeGuards,
          );
      String guard(
        String name,
        String allows,
        String target,
        String flow, {
        String resumes = '',
      }) =>
          "RouteGuard('$name', allows: $allows(), redirectTo: const "
          '${target}Location(), flow: const {$flow}$resumes)';
      expect(
        [
          for (final element in (guards.initializer! as ListLiteral).elements)
            element.toSource(),
        ],
        [
          // The files of the functions get their prefixes in the order of
          // the guards too.
          guard(
            'intro.firstRun',
            'guard0.introSeen',
            'IntroIntro',
            "'intro.intro', 'intro.terms'",
          ),
          guard(
            'account.signedIn',
            'guard1.isSignedIn',
            'AccountLogin',
            "'account.login'",
            resumes: ', resumes: false',
          ),
          guard(
            'intro.premium',
            'guard0.isPremium',
            'IntroPaywall',
            "'intro.paywall'",
          ),
        ],
      );
      // A guard of the app brings the user back unless it says otherwise.
      final guardClass =
          unit.declarations.whereType<ClassDeclaration>().singleWhere(
                (declared) => declared.namePart.typeName.lexeme == 'RouteGuard',
              );
      expect(
        guardClass.toSource(),
        allOf(contains('this.resumes = true'), contains('final bool resumes;')),
      );
    });

    /// What the script [main] prints in the app with guards, or in the app
    /// of [data], with the files of the functions of the guards of the
    /// features `intro` and `account`; see [printedByGuards].
    Future<String> printedBy(String main, {List<RoleData<Object>>? data}) =>
        printedByGuards(
          main,
          data: data ?? _guardedData,
          files: const {
            'lib/features/intro/intro_status.dart': _vmIntroStatus,
            'lib/features/account/account_composition.dart': _vmAccount,
          },
        );

    /// What [_vmMemoryMain] prints, which the first test that reads it
    /// runs: the tests of the generated class each read some sections.
    late final memory = printedBy(_vmMemoryMain);

    test(
        'the generated guards send every route outside the flow of the first '
        'one that does not allow to its target, tell when one changes, and '
        'say that a flow is over once its guard allows', () async {
      // The functions of the guards are called on the first use of the
      // guards, each once, whatever the guards are asked. The first guard
      // that does not allow decides: the routes of its flow show, and the
      // targets of the guards after it are routes like any other to it.
      // Each change of a guard is one notification. The flow of a guard is
      // over while the guard allows, whatever the other guards do, and a
      // route outside every flow, or no route, is in none.
      expect(await printedBy(_vmGuardsMain), '''
functions called before the first use: 0
intro.firstRun shows /intro and allows intro.intro, intro.terms
intro.premium shows /intro/paywall and allows intro.paywall
account.signedIn shows /account/login and allows account.login
none allows
  shows intro.intro, intro.terms
  /intro: home.root, intro.paywall, account.login, none
firstRun allows
  shows intro.paywall
  /intro/paywall: home.root, intro.intro, intro.terms, account.login, none
  over: intro.intro, intro.terms
firstRun and premium allow
  shows account.login
  /account/login: home.root, intro.intro, intro.terms, intro.paywall, none
  over: intro.intro, intro.terms, intro.paywall
all allow
  shows home.root, intro.intro, intro.terms, intro.paywall, account.login, none
  over: intro.intro, intro.terms, intro.paywall, account.login
premium stopped
  shows intro.paywall
  /intro/paywall: home.root, intro.intro, intro.terms, account.login, none
  over: intro.intro, intro.terms, account.login
firstRun stopped too
  shows intro.intro, intro.terms
  /intro: home.root, intro.paywall, account.login, none
  over: account.login
changes: 5
calls: 1, 1
''');
    });

    test(
        'the generated class keeps what a router remembers: the latest '
        'location that was asked for, or the location below the pushed pages '
        'that a change took out of the stack, never one in a flow; it answers '
        'that location once the guards allow it and forgets it', () async {
      final printed = await memory;

      expect(sectionOf(printed, 'asked while no guard allows'), '''
  asked /home: /intro
  asked /intro/terms: shows it
  asked /account/login: /intro
  asked /no/such?x=1: /intro
  asked /home/details/5?tab=a: /intro
  firstRun allows: /intro/paywall
  premium allows: /account/login
  signedIn allows: /home/details/5?tab=a
  a notification: stays
''');
      expect(
        sectionOf(printed, 'pages that a change takes out of the stack'),
        '''
  signedIn stops: /account/login
  premium stops: /intro/paywall
  a page outside the flows: /intro/paywall
  premium allows: /account/login
  signedIn allows: /home/details/5?tab=a
  signedIn stops: /account/login
  signedIn allows: /
''',
      );
      expect(sectionOf(printed, 'a location of a flow asked last'), '''
  firstRun stops: /intro
  asked /account/login: /intro
  firstRun allows: /home
''');
      expect(sectionOf(printed, 'the location / asked last'), '''
  signedIn stops: /account/login
  asked /: /account/login
  signedIn allows: /
''');
    });

    test(
        'the generated class answers the start of the app for a location in '
        'a flow that is over, whose guard allows, and for a page of such a '
        'flow on top of the stack when nothing is remembered', () async {
      final printed = await memory;

      // Every guard allows: a route of a flow shows the start of the app,
      // whichever guard has the flow, and nothing is remembered for it. A
      // page of such a flow that a router still has on top leaves at the
      // next notification of a guard.
      expect(sectionOf(printed, 'a flow that is over'), '''
  asked /intro/terms: /
  asked /intro/paywall?plan=a: /
  asked /account/login: /
  asked /home: shows it
  asked /no/such: shows it
  a notification: stays
  a notification, a page of the flow on top: /
''');
      // The pages of the flow of a guard that does not allow stay, also
      // when a guard after it changes. Once the guard allows, with nothing
      // remembered, as in an app that a link opened in the flow, the router
      // leaves the flow for the start of the app.
      expect(sectionOf(printed, 'a flow shown with nothing remembered'), '''
  firstRun stops: stays
  asked /intro/terms: shows it
  a notification: stays
  premium stops: stays
  premium allows: stays
  firstRun allows: /
  asked /intro/terms: /
''');
      // A guard that does not allow decides before a flow that is over: a
      // route of the flow of a guard that allows shows the target of that
      // guard. And a location in a flow is not remembered when another
      // guard takes it out of the stack.
      expect(
        sectionOf(
          printed,
          'a flow of a guard that allows, behind a guard that does not',
        ),
        '''
  premium stops: stays
  asked /intro/terms: /intro/paywall
  asked /intro/paywall: shows it
  firstRun stops: /intro
  firstRun allows: /intro/paywall
  premium allows: /
''',
      );
    });

    test(
        'the generated guards are asked by stage: the first one that does '
        'not allow decides, whatever the order of the modules', () async {
      // `account` is listed before `intro`, whose first guard is of the
      // stage before that of the guard of `account`: it decides first, then
      // the guard of `account`, and then the second guard of `intro`, of
      // the same stage as that of `account`.
      expect(await printedBy(_vmOrderMain, data: _accountFirstData), '''
intro.firstRun, account.signedIn, intro.premium
none allows: /intro
signedIn allows: /intro
firstRun allows too: /intro/paywall
signedIn stopped: /account/login
all allow: shows it
''');
    });

    test(
        'the generated class forgets what it remembers when a guard that '
        'does not bring the user back stops allowing, whichever guard made '
        'it remember, so the user comes to the start of the app; it still '
        'shows a location that is asked for after the guard stopped, and one '
        'that the app is opened with while the guard never allowed', () async {
      final printed = await printedBy(_vmResumesMain, data: _accountFirstData);

      // The location that the app is opened with is asked for while no
      // guard allows. The guard that does not bring the user back never
      // allowed, so it did not stop: the user comes to that location once
      // the last guard allows.
      expect(sectionOf(printed, 'a first launch'), '''
  asked /home/details/3: /intro
  firstRun allows: /account/login
  signedIn allows: /intro/paywall
  premium allows: /home/details/3
''');
      // Neither the pushed page nor the location below it comes back: the
      // flow of the guard is over and nothing is remembered.
      expect(sectionOf(printed, 'the guard stops allowing'), '''
  signedIn stops: /account/login
  a notification: stays
  signedIn allows: /
  a notification: stays
''');
      expect(
        sectionOf(printed, 'a location asked for while it does not allow'),
        '''
  signedIn stops: /account/login
  asked /home/details/7: /account/login
  asked /account/login: shows it
  signedIn allows: /home/details/7
  a notification: stays
''',
      );
      // A guard before it took the user from a location, and it stops
      // while the flow of that guard is shown: the location is forgotten,
      // though the guard before it still decides and the stack stays.
      expect(
        sectionOf(printed, 'it stops behind a guard that brings the user back'),
        '''
  firstRun stops: /intro
  signedIn stops: stays
  firstRun allows: /account/login
  signedIn allows: /
''',
      );
      // The other order of the two, as in one handler: it stops first, and
      // the guard before it then takes the user from its target, a location
      // in a flow, which is never remembered.
      expect(
        sectionOf(printed, 'it stops before a guard that brings the user back'),
        '''
  signedIn stops: /account/login
  firstRun stops: /intro
  firstRun allows: /account/login
  signedIn allows: /
''',
      );
      // It allows again before the guard before it does: the router showed
      // nothing of it, and the location is forgotten all the same.
      expect(
        sectionOf(
          printed,
          'it stops and allows again behind a guard that does not allow',
        ),
        '''
  firstRun stops: /intro
  signedIn stops: stays
  signedIn allows: stays
  firstRun allows: /
''',
      );
      // A location that was asked for before it stopped is forgotten too.
      expect(
        sectionOf(printed, 'a location that was asked for before it stops'),
        '''
  firstRun stops: /intro
  asked /home/details/8: /intro
  signedIn stops: stays
  firstRun allows: /account/login
  signedIn allows: /
''',
      );
      // A change that the class is not told of counts the next time it is
      // asked: it finds that the guard does not allow, which allowed when
      // it last looked.
      expect(
        sectionOf(
          printed,
          'it stops without the class being told, which is asked next',
        ),
        '''
  firstRun stops: /intro
  asked /intro/terms: shows it
  firstRun allows: /
''',
      );
      // And so is the location that a guard after it took the user from.
      expect(
        sectionOf(printed, 'it stops while a guard after it does not allow'),
        '''
  premium stops: /intro/paywall
  signedIn stops: /account/login
  signedIn allows: /intro/paywall
  premium allows: /
''',
      );
      // The guards before and after it bring the user back as before: to
      // the location below the pushed pages.
      expect(sectionOf(printed, 'a guard that brings the user back'), '''
  firstRun stops: /intro
  firstRun allows: /home/details/5?tab=a
  premium stops: /intro/paywall
  premium allows: /home
''');
    });

    test(
        'of two guards with one target, the flow is over only once both '
        'allow, in whichever order; and the generated class answers nothing '
        'when it is told of no pages', () async {
      expect(
        await printedBy(_vmSharedTargetMain, data: _sharedTargetData),
        '''
a router without a page
  no guard allows, no pages: stays
two guards with one target, with nothing remembered
  no guard allows: not over
  asked /intro/terms: shows it
  firstRun allows: stays, not over
  asked /intro/terms: shows it
  premium allows: /, over
  asked /intro/terms: /
  both allow, no pages: stays
two guards with one target, in the other order
  firstRun stops: /intro, not over
  premium stops: stays, not over
  premium allows: stays, not over
  asked /intro/terms: shows it
  firstRun allows: /home, over
''',
      );
    });
  });

  group('the start route of an app with guards', () {
    Future<Object?> choose(String? start) => routerRole.template.choose(
          routerRole.choiceContext(
            RoleChoiceRequest(
              data: _guardedData,
              presentRoles: {routerRole},
              optionValues: {'start': start},
              environment: FakeEnvironment(),
              context: testContext,
            ),
          ),
        );

    test('is no route of the flow of a guard', () {
      for (final (start, guard) in [
        ('/intro', 'intro.firstRun'),
        ('/intro/terms', 'intro.firstRun'),
        ('/intro/paywall', 'intro.premium'),
        ('/account/login', 'account.signedIn'),
      ]) {
        expect(
          () => choose(start),
          throwsA(
            isA<SmfUsageException>().having(
              (e) => e.message,
              'message',
              'The app cannot start on $start, because the route is in the '
                  'flow of the guard $guard: the app shows it until the guard '
                  'allows, and then the screen that it starts on.',
            ),
          ),
          reason: start,
        );
      }
    });

    test('is a route of a feature outside the flows of the guards', () async {
      expect(await choose('/home'), const RouterChoice(startPath: '/home'));
      expect(await choose(null), const RouterChoice(startPath: '/home'));
    });
  });

  group('the module rule router.guards', () {
    test('is a module rule of the role', () {
      expect(
        routerRole.moduleRules.map((rule) => rule.id),
        ['router.routes', 'router.guards', 'router.screen_sockets'],
      );
    });

    test(
        'accepts guards that show top-level routes outside the main '
        'navigation', () {
      expect(
        _guardProblems([
          _guard(),
          // Two guards may show the same route.
          _guard(name: 'paid'),
        ]),
        isEmpty,
      );
      expect(_guardProblems(const []), isEmpty);
    });

    test('names the module in every issue', () {
      final issues = _guardIssues([_guard(redirectTo: 'nowhere')]);

      expect(issues, hasLength(1));
      expect(issues.single.origin, const ModuleOrigin(ModuleId('home')));
    });

    test('rejects invalid and repeated names', () {
      String invalid(String name) =>
          'The guard "$name" needs a name that is a lowerCamelCase Dart '
          'identifier, such as firstRun.';

      expect(
        _guardProblems([
          _guard(name: 'FirstRun'),
          _guard(name: 'first_run'),
          _guard(name: 'class'),
          _guard(name: ''),
          _guard(name: 'same'),
          _guard(name: 'same'),
        ]),
        [
          for (final name in ['FirstRun', 'first_run', 'class', ''])
            invalid(name),
          'Two guards of the module are named "same".',
        ],
      );
    });

    test('rejects a function that is not a public function of the app', () {
      const file = 'features/home/home_gate.dart';
      final problems = _guardProblems([
        _guard(allows: const FunctionRef('_isOpen', import: _gateFile)),
        _guard(
          name: 'packaged',
          allows: const FunctionRef(
            'isOpen',
            import: ImportRef('package:gate/gate.dart'),
          ),
        ),
        _guard(
          name: 'prefixed',
          allows: const FunctionRef(
            'isOpen',
            import: ImportRef.app(file, prefix: 'g'),
          ),
        ),
        _guard(
          name: 'shown',
          allows: const FunctionRef(
            'isOpen',
            import: ImportRef.app(file, show: ['isOpen']),
          ),
        ),
        _guard(
          name: 'misplaced',
          allows: const FunctionRef(
            'isOpen',
            import: ImportRef.app('lib/$file'),
          ),
        ),
      ]);

      expect(problems, hasLength(5));
      expect(
        problems[0],
        'The guard "open": The function "_isOpen" is not a public Dart '
        'function name.',
      );
      expect(
        problems[1],
        'The guard "packaged" asks a function of "package:gate/gate.dart"; '
        'its function is in a file of the app, imported with ImportRef.app.',
      );
      for (final (index, name) in [(2, 'prefixed'), (3, 'shown')]) {
        expect(
          problems[index],
          'The guard "$name" imports its function with a prefix or show; the '
          'router role imports the file with a prefix of its own.',
        );
      }
      expect(
        problems[4],
        'The guard "misplaced": The app import "lib/$file" must be a .dart '
        'path below lib/, without the lib/ prefix, such as core/app/app.dart.',
      );
    });

    test('rejects a target that is no top-level route of the module', () {
      final problems = _guardProblems([
        _guard(redirectTo: 'nowhere'),
        _guard(name: 'below', redirectTo: 'step'),
      ]);

      expect(problems, hasLength(2));
      expect(
        problems.first,
        'The guard "open" shows the route "nowhere", but the module has no '
        'route of that name.',
      );
      expect(
        problems.last,
        'The guard "below" shows the route "step" (step), which is a child; '
        'the target of a guard is a top-level route, since a child shows on '
        'top of its parents.',
      );
    });

    test('rejects a target that needs values', () {
      expect(
        _guardProblems([_guard(redirectTo: 'item')]).single,
        'The guard "open" shows the route "item" (/items/:id), which needs '
        ':id; the router shows the target of a guard without values.',
      );
      // A value that the location may leave out is none that it needs.
      expect(
        _guardProblems(
          [_guard(redirectTo: 'search')],
          routes: [
            Route(
              '/search',
              name: 'search',
              screen: _screen('SearchScreen', 'home'),
              params: const [
                RouteParam.query('q', type: String, optional: true),
              ],
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('rejects a target in the main navigation', () {
      expect(
        _guardProblems(
          [_guard(redirectTo: 'tab')],
          routes: [
            Route(
              '/tab',
              name: 'tab',
              screen: _screen('TabScreen', 'home'),
              destination: _homeDestination,
            ),
          ],
        ).single,
        'The guard "open" shows the route "tab" (/tab), which is a '
        'destination of the main navigation; a guard keeps the user out of '
        'the main navigation, so its target is outside it.',
      );
    });

    test('rejects a start candidate in the flow of a guard', () {
      Route gate({bool starts = false, bool stepStarts = false}) => Route(
            '/gate',
            name: 'gate',
            screen: _screen('GateScreen', 'home'),
            startCandidate: starts,
            children: [
              Route(
                'step',
                name: 'step',
                screen: _screen('StepScreen', 'home'),
                startCandidate: stepStarts,
              ),
            ],
          );
      String problem(String route) =>
          'The guard "open" shows the route "gate" (/gate), but the route '
          '$route of its flow is a start candidate; the app shows the flow '
          'of a guard until the guard allows, and then the screen that it '
          'starts on.';

      expect(
        _guardProblems([_guard()], routes: [gate(starts: true)]),
        [problem('"gate" (/gate)')],
      );
      expect(
        _guardProblems([_guard()], routes: [gate(stepStarts: true)]),
        [problem('"step" (step)')],
      );
      expect(_guardProblems([_guard()], routes: [gate()]), isEmpty);
    });
  });

  group('the structural rule router.guard_functions', () {
    const introPath = 'lib/features/intro/intro_status.dart';
    const accountPath = 'lib/features/account/account_composition.dart';
    const listenable = 'ValueListenable<bool>';

    /// A top-level function, as the harness indexes it.
    IndexedDeclaration function(
      String name, {
      String? type = listenable,
      List<IndexedParameter> parameters = const [],
    }) =>
        IndexedDeclaration(
          name: name,
          kind: DeclarationKind.function,
          type: type,
          parameters: parameters,
        );

    /// The issues of the rule in the app of the features with guards, or of
    /// [data], whose files of functions declare [intro] and [account]; a
    /// file without declarations is not in the app.
    List<SmfIssue> check({
      List<IndexedDeclaration> intro = const [],
      List<IndexedDeclaration> account = const [],
      List<RoleData<Object>>? data,
    }) =>
        _structuralIssues(
          'The function of the guard ',
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: data ?? _guardedData,
              presentRoles: {routerRole},
              context: testContext,
            ),
            files: {
              if (intro.isNotEmpty)
                introPath: DartFileIndex(path: introPath, declarations: intro),
              if (account.isNotEmpty)
                accountPath:
                    DartFileIndex(path: accountPath, declarations: account),
            },
          ),
        );

    test('is a structural rule of the role, with the one that follows it', () {
      expect(
        routerRole.structuralRules.map((rule) => rule.id),
        [
          'router.nav_access',
          'router.screen_constructors',
          'router.guard_functions',
          'router.guards_asked',
          'router.destinations_shown',
        ],
      );
      // The last one of the guards says what a provider uses of the role.
      expect(
        routerRole.structuralRules[3].description,
        'In an app with guards, the files of the provider of the role create '
        'a GuardedNavigation, read guardChanges, and name its answers '
        'ShowOver and ClosePages.',
      );
    });

    test(
        'accepts top-level functions without parameters that return a '
        'ValueListenable<bool>', () {
      expect(
        check(
          intro: [
            function('introSeen'),
            // As written, whatever its white space, and with parameters
            // that a call may leave out.
            function(
              'isPremium',
              type: 'ValueListenable< bool >',
              parameters: const [
                IndexedParameter('now', kind: ParameterKind.optionalNamed),
              ],
            ),
          ],
          account: [function('isSignedIn')],
        ),
        isEmpty,
      );
    });

    test('rejects a function that its file does not declare as one', () {
      final issues = check(
        intro: [
          const IndexedDeclaration(
            name: 'introSeen',
            kind: DeclarationKind.variable,
            type: listenable,
          ),
        ],
      );

      expect(issues, hasLength(3));
      expect(
        issues[0].message,
        'The function of the guard intro.firstRun: function introSeen() in '
        '$introPath must be a function, not a variable.',
      );
      expect(
        issues[1].message,
        'The function of the guard intro.premium: $introPath does not '
        'declare function isPremium().',
      );
      expect(
        issues[2].message,
        'The function of the guard account.signedIn: $accountPath is '
        'missing, so it cannot declare function isSignedIn().',
      );
      expect(
        [for (final issue in issues) '${issue.origin}'],
        ['intro', 'intro', 'account'],
      );
      expect(
        [for (final issue in issues) issue.path],
        [introPath, introPath, accountPath],
      );
      expect(
        issues.first.hint,
        'The router role calls it without arguments, and listens to the '
        'ValueListenable<bool> that it returns.',
      );
    });

    test('rejects a function of another type, or one that needs arguments', () {
      final problems = [
        for (final issue in check(
          intro: [
            function('introSeen', type: 'bool'),
            function('isPremium', type: null),
          ],
          account: [
            function(
              'isSignedIn',
              parameters: const [
                IndexedParameter(
                  'session',
                  kind: ParameterKind.requiredPositional,
                ),
                IndexedParameter('user', kind: ParameterKind.requiredNamed),
              ],
            ),
          ],
        ))
          issue.message,
      ];

      expect(problems, hasLength(4));
      expect(
        problems[0],
        'The function of the guard intro.firstRun: function introSeen() in '
        '$introPath must return $listenable, not bool.',
      );
      expect(
        problems[1],
        'The function of the guard intro.premium: function isPremium() in '
        '$introPath must return $listenable, not an undeclared type.',
      );
      expect(
        problems[2],
        'The function of the guard account.signedIn: function isSignedIn() '
        'in $accountPath must not require more than 0 positional arguments.',
      );
      expect(
        problems[3],
        'The function of the guard account.signedIn: function isSignedIn() '
        'in $accountPath must not require the parameter user.',
      );
    });

    test(
        'leaves a function outside the app to the module rule, and an app '
        'without guards alone', () {
      expect(
        check(
          data: [
            dataOf(
              routerRole,
              RoutesData(
                _gatedRoutes,
                guards: [
                  _guard(
                    allows: const FunctionRef(
                      'isOpen',
                      import: ImportRef('package:gate/gate.dart'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        isEmpty,
      );
      expect(check(data: _data), isEmpty);
    });
  });

  group('the structural rule router.guards_asked', () {
    const factoryPath = RouterRole.appRouterFactoryFile;
    const delegatePath = 'lib/core/router/delegate.dart';
    const screenPath = 'lib/features/intro/intro_screen.dart';
    const provider = ModuleOrigin(ModuleId('navigator'));

    /// The issues of the rule in the app of the features with guards, or
    /// of [data], where the module `navigator`, the provider of the role
    /// unless [withProvider] is `false`, generates [files].
    List<SmfIssue> check(
      List<DartFileIndex> files, {
      List<RoleData<Object>>? data,
      bool withProvider = true,
    }) =>
        _structuralIssues(
          'The provider of the router role does not',
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: data ?? _guardedData,
              presentRoles: {routerRole},
              context: testContext,
            ),
            files: {
              for (final file in files) file.path: file,
              // A file of a feature that uses them all, which asks nothing
              // for the router.
              screenPath: const DartFileIndex(
                path: screenPath,
                imports: [
                  IndexedImport('package:my_app/core/router/app_router.dart'),
                ],
                invocations: [IndexedInvocation('GuardedNavigation')],
                references: [IndexedReference('guardChanges')],
                typeNames: [
                  IndexedTypeName('ShowOver'),
                  IndexedTypeName('ClosePages'),
                ],
              ),
            },
            owners: {
              for (final file in files) file.path: provider,
              screenPath: const ModuleOrigin(ModuleId('intro')),
            },
            modules: [
              if (withProvider)
                ModuleDescriptor(
                  id: provider.module,
                  description: 'Navigator',
                  kind: ModuleKinds.infrastructure,
                  providers: const [RoleProvider.plain(routerRole)],
                ),
              const ModuleDescriptor(
                id: ModuleId('intro'),
                description: 'Intro',
                kind: ModuleKinds.feature,
              ),
            ],
          ),
        );

    /// The file of the provider with `createAppRouter()`, which imports the
    /// file of the role by a relative path, calls [calls], reads [reads]
    /// and names the types [types].
    DartFileIndex factory({
      List<String> calls = const [],
      List<String> reads = const [],
      List<String> types = const [],
    }) =>
        DartFileIndex(
          path: factoryPath,
          imports: const [IndexedImport('app_router.dart')],
          invocations: [for (final name in calls) IndexedInvocation(name)],
          references: [for (final name in reads) IndexedReference(name)],
          typeNames: [for (final name in types) IndexedTypeName(name)],
        );

    /// A file of the provider that asks the guards and does what they
    /// answer.
    DartFileIndex asking() => factory(
          calls: ['GuardedNavigation'],
          reads: ['guardChanges'],
          types: ['ShowOver', 'ClosePages'],
        );

    String problem(String what) =>
        'The provider of the router role does not ask the guards of the '
        'app: none of its files $what of ${RouterRole.appRouterFile}.';

    String unanswered(String answer) =>
        'The provider of the router role does not do what the guards of '
        'the app answer: none of its files names the answer $answer of '
        '${RouterRole.appRouterFile}.';

    test(
        'accepts a provider whose files create a GuardedNavigation, read '
        'guardChanges, and name the answers ShowOver and ClosePages', () {
      expect(check([asking()]), isEmpty);
      // In two of its files, one of which imports the file of the role
      // with a prefix.
      expect(
        check([
          factory(calls: ['GuardedNavigation'], types: ['ClosePages']),
          const DartFileIndex(
            path: delegatePath,
            imports: [
              IndexedImport(
                'package:my_app/core/router/app_router.dart',
                prefix: 'router',
              ),
            ],
            memberAccesses: [IndexedMemberAccess('router', 'guardChanges')],
            typeNames: [IndexedTypeName('ShowOver', prefix: 'router')],
          ),
        ]),
        isEmpty,
      );
      // An app whose guards are all gates gets no other answer than a
      // location, and the rule holds there all the same: a guard with
      // routes that is added to the app by hand needs no other router.
      expect(
        _facade(_guardedData).guards.every((guard) => guard.isGate),
        isTrue,
      );
    });

    test('reports a provider that does not ask the guards', () {
      final issues = check([
        factory(types: ['ShowOver', 'ClosePages']),
      ]);

      expect(
        [for (final issue in issues) issue.message],
        [
          problem('creates a GuardedNavigation'),
          problem('reads guardChanges'),
        ],
      );
      for (final issue in issues) {
        expect(issue.origin, provider);
        expect(issue.path, factoryPath);
        expect(issue.isError, isTrue);
        expect(
          issue.hint,
          'A router asks its GuardedNavigation about every location before '
          'it shows it, and tells it of its pages when guardChanges '
          'notifies; see RouterRole.guardedNavigation.',
        );
      }
      expect(
        [
          for (final issue in check([
            factory(
              calls: ['GuardedNavigation'],
              types: ['ShowOver', 'ClosePages'],
            ),
          ]))
            issue.message,
        ],
        [problem('reads guardChanges')],
      );
      expect(
        [
          for (final issue in check([
            factory(reads: ['guardChanges'], types: ['ShowOver', 'ClosePages']),
          ]))
            issue.message,
        ],
        [problem('creates a GuardedNavigation')],
      );
      // A provider that only calls redirectOf() keeps nothing of what the
      // guards make a router remember.
      expect(
        check([
          factory(
            calls: ['redirectOf'],
            reads: ['guardChanges'],
            types: ['ShowOver', 'ClosePages'],
          ),
        ]),
        hasLength(1),
      );
    });

    test(
        'reports a provider that asks the guards and names neither the '
        'answer that opens a flow over the page on top nor the one that '
        'closes pages, as one that shows every answer in place of its stack',
        () {
      final issues = check([
        factory(
          calls: ['GuardedNavigation'],
          reads: ['guardChanges'],
          // The other answers, and a type that it only declares a field
          // with.
          types: ['ShowInstead', 'ShowNothing', 'GuardedNavigation'],
        ),
      ]);

      expect(
        [for (final issue in issues) issue.message],
        [unanswered('ShowOver'), unanswered('ClosePages')],
      );
      for (final issue in issues) {
        expect(issue.origin, provider);
        expect(issue.path, factoryPath);
        expect(issue.isError, isTrue);
        expect(
          issue.hint,
          'A router opens the target of a guard with routes over the page '
          'on top for the answer ShowOver, and closes the pages on top for '
          'the answer ClosePages; see RouterRole.guardedNavigation.',
        );
      }
      expect(
        [
          for (final issue in check([
            factory(
              calls: ['GuardedNavigation'],
              reads: ['guardChanges'],
              types: ['ShowOver'],
            ),
          ]))
            issue.message,
        ],
        [unanswered('ClosePages')],
      );
      // A call of a function of that name is no answer of the guards that
      // the provider tells apart.
      expect(
        [
          for (final issue in check([
            factory(
              calls: ['GuardedNavigation', 'ShowOver', 'ClosePages'],
              reads: ['guardChanges', 'ShowOver', 'ClosePages'],
              types: ['ClosePages'],
            ),
          ]))
            issue.message,
        ],
        [unanswered('ShowOver')],
      );
    });

    test(
        'counts only what the files of the provider use of the file of the '
        'role', () {
      expect(
        check([
          const DartFileIndex(
            path: factoryPath,
            imports: [
              IndexedImport('package:my_app/core/other.dart'),
              IndexedImport('app_router.dart', prefix: 'router'),
            ],
            invocations: [
              // Of other.dart, which the file imports without a prefix.
              IndexedInvocation('GuardedNavigation'),
            ],
            // Of an object, not of the import.
            memberAccesses: [IndexedMemberAccess('guards', 'guardChanges')],
            typeNames: [
              // Of other.dart too, and after a prefix that no import has.
              IndexedTypeName('ShowOver'),
              IndexedTypeName('ClosePages', prefix: 'other'),
            ],
          ),
        ]),
        hasLength(4),
      );
      // A file that does not import the file of the role names none of its
      // types.
      expect(
        check([
          asking(),
          const DartFileIndex(
            path: delegatePath,
            typeNames: [
              IndexedTypeName('ShowOver'),
              IndexedTypeName('ClosePages'),
            ],
          ),
        ]),
        isEmpty,
      );
      expect(
        check([
          factory(calls: ['GuardedNavigation'], reads: ['guardChanges']),
          const DartFileIndex(
            path: delegatePath,
            imports: [IndexedImport('package:my_app/core/other.dart')],
            typeNames: [
              IndexedTypeName('ShowOver'),
              IndexedTypeName('ClosePages'),
            ],
          ),
        ]),
        hasLength(2),
      );
    });

    test(
        'checks an app with guards and the files of a provider among its '
        'modules, and nothing otherwise', () {
      expect(check(const []), hasLength(4));
      expect(check(const [], withProvider: false), isEmpty);
      expect(check([factory()], data: _data), isEmpty);
    });
  });
}
