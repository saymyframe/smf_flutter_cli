@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
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
    ),
    RouteGuard(
      name: 'premium',
      allows: FunctionRef('isPremium', import: _introFile),
      redirectTo: 'paywall',
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
        ),
        RouteGuard(
          name: 'premium',
          allows: FunctionRef('isPremium', import: _introFile),
          redirectTo: 'intro',
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
    RouteGuard(name: name, allows: allows, redirectTo: redirectTo);

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

/// A stand-in for the part of Flutter's foundation library that the code
/// of the guards uses, with the signatures of Flutter 3.44.
const _vmFoundation = '''
typedef VoidCallback = void Function();

abstract class Listenable {
  const Listenable();

  factory Listenable.merge(Iterable<Listenable?> listenables) = _Merged;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

abstract class ValueListenable<T> extends Listenable {
  const ValueListenable();

  T get value;
}

class ValueNotifier<T> implements ValueListenable<T> {
  ValueNotifier(this._value);

  final List<VoidCallback> _listeners = [];

  T _value;

  @override
  T get value => _value;

  set value(T value) {
    if (value == _value) return;
    _value = value;
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

class _Merged extends Listenable {
  _Merged(this._listenables);

  final Iterable<Listenable?> _listenables;

  @override
  void addListener(VoidCallback listener) {
    for (final listenable in _listenables) {
      listenable?.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final listenable in _listenables) {
      listenable?.removeListener(listener);
    }
  }
}
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the router role use: what it exports of the foundation library, without
/// `ValueListenable`, as Flutter 3.44 does.
const _vmWidgets = '''
export 'foundation.dart' show Listenable, ValueNotifier, VoidCallback;

abstract class BuildContext {}

class RouterConfig<T> {}
''';

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
/// and close, and how often `guardChanges` notified and the functions were
/// called.
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
/// pages of a stack while the guards open and close. A page is written as
/// its route, or `-` for none, its location, and `pushed` if a push showed
/// it; the page on top comes first.
const _vmMemoryMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/account/account_composition.dart';
import 'package:my_app/features/intro/intro_status.dart';

final guards = GuardedNavigation<String>(
  start: '/',
  locationOf: (location) => location.path,
);

void asked(String? route, String location) {
  final answer = guards.asked(route, location);
  print('  asked $location: ${answer?.location ?? 'shows it'}');
}

void changed(String what, List<String> pages) {
  final answer = guards.changed([
    for (final page in pages.map((page) => page.split(' ')))
      (
        route: page[0] == '-' ? null : page[0],
        location: page[1],
        pushed: page.length > 2,
      ),
  ]);
  print('  $what: ${answer?.location ?? 'stays'}');
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

  print('a flow with nothing remembered');
  const flow = ['intro.terms /intro/terms', 'intro.intro /intro'];
  asked('intro.terms', '/intro/terms');
  introSeenNow.value = false;
  changed('firstRun stops', flow);
  changed('a notification', flow);
  premiumNow.value = false;
  changed('premium stops', flow);
  premiumNow.value = true;
  changed('premium allows', flow);
  introSeenNow.value = true;
  changed('firstRun allows', flow);
  changed('a notification', flow);
  introSeenNow.value = false;
  changed('firstRun stops', ['account.login /account/login']);
  introSeenNow.value = true;
  changed('firstRun allows, outside its flow', ['home.root /home']);

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

/// Prints what `GuardedNavigation` answers in an app whose two guards show
/// one target: when it is told of no pages, as by a router that has none
/// yet, and when the guards of the one flow start allowing one after the
/// other while a page of the flow is on top.
const _vmSharedTargetMain = r'''
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/intro/intro_status.dart';

void main() {
  // The router is created while no guard allows, and has no page yet.
  final guards = GuardedNavigation<String>(
    start: '/',
    locationOf: (location) => location.path,
  );
  String told(List<(String, String)> pages) =>
      guards.changed([
        for (final (route, location) in pages)
          (route: route, location: location, pushed: false),
      ])?.location ??
      'stays';
  const flow = [('intro.terms', '/intro/terms'), ('intro.intro', '/intro')];

  print('a change before the router has a page');
  introSeenNow.value = true;
  premiumNow.value = true;
  print('  both allow, no pages: ${told(const [])}');
  final shown = guards.asked('intro.terms', '/intro/terms');
  print('  asked /intro/terms: ${shown?.location ?? 'shows it'}');
  print('  a notification in the flow: ${told(flow)}');

  print('two guards with one target');
  introSeenNow.value = false;
  print('  firstRun stops: ${told(flow)}');
  premiumNow.value = false;
  print('  premium stops: ${told(flow)}');
  introSeenNow.value = true;
  print('  firstRun allows: ${told(flow)}');
  premiumNow.value = true;
  print('  premium allows: ${told(flow)}');
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
        'merge the guards of the data of a module, and leave out a guard '
        'whose target is no top-level route of its module', () {
      const guard = RouteGuard(
        name: 'premium',
        allows: FunctionRef('isPremium', import: _introFile),
        redirectTo: 'paywall',
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
              RouterRole.routeGuards,
            ],
            // What the code of the app calls to go to the target of a guard.
            RouterRole.navigationFile: ['NavLink.go'],
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

    /// What the script [main] prints in the app with guards, with the
    /// files of the router's template and stand-ins for Flutter and for the
    /// files of the functions of the guards. print ends a line with \r\n
    /// on Windows.
    Future<String> printedBy(
      String main, {
      List<RoleData<Object>>? data,
    }) async {
      final directory = await Directory.systemTemp.createTemp('smf_guards');
      addTearDown(() => directory.delete(recursive: true));
      final rendered = await renderTemplate(
        routerRole,
        data: data ?? _guardedData,
      );
      final files = {
        'flutter/lib/foundation.dart': _vmFoundation,
        'flutter/lib/widgets.dart': _vmWidgets,
        for (final MapEntry(key: path, value: text) in rendered.files.entries)
          'app/$path': text,
        // The file of the provider of the role, which no test here calls.
        'app/${RouterRole.appRouterFactoryFile}': '''
import 'app_router.dart';

AppRouter createAppRouter() => throw UnimplementedError();
''',
        'app/lib/${_introFile.uri}': _vmIntroStatus,
        'app/lib/${_accountFile.uri}': _vmAccount,
        'app/bin/main.dart': main,
        'app/.dart_tool/package_config.json': jsonEncode({
          'configVersion': 2,
          'packages': [
            for (final (name, root) in [
              ('my_app', '../'),
              ('flutter', '../../flutter/'),
            ])
              {
                'name': name,
                'rootUri': root,
                'packageUri': 'lib/',
                'languageVersion': '3.6',
              },
          ],
        }),
      };
      for (final MapEntry(key: path, value: text) in files.entries) {
        File('${directory.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(text);
      }
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', '${directory.path}/app/bin/main.dart'],
      );

      expect(result.stderr, isEmpty);
      return (result.stdout as String).replaceAll('\r\n', '\n');
    }

    test(
        'the generated guards send every route outside the flow of the first '
        'one that does not allow to its target, and tell when one changes',
        () async {
      // The functions of the guards are called on the first use of the
      // guards, each once, whatever the guards are asked. The first guard
      // that does not allow decides: the routes of its flow show, and the
      // targets of the guards after it are routes like any other. Each
      // change of a guard is one notification.
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
firstRun and premium allow
  shows account.login
  /account/login: home.root, intro.intro, intro.terms, intro.paywall, none
all allow
  shows home.root, intro.intro, intro.terms, intro.paywall, account.login, none
premium stopped
  shows intro.paywall
  /intro/paywall: home.root, intro.intro, intro.terms, account.login, none
firstRun stopped too
  shows intro.intro, intro.terms
  /intro: home.root, intro.paywall, account.login, none
changes: 5
calls: 1, 1
''');
    });

    test(
        'the generated class keeps what a router remembers: the latest '
        'location that was asked for, or the location below the pushed pages '
        'that a change took out of the stack, never one in a flow; it answers '
        'that location once the guards allow it and forgets it, and the '
        'start of the app when a flow is over with nothing remembered',
        () async {
      expect(await printedBy(_vmMemoryMain), '''
asked while no guard allows
  asked /home: /intro
  asked /intro/terms: shows it
  asked /account/login: /intro
  asked /no/such?x=1: /intro
  asked /home/details/5?tab=a: /intro
  firstRun allows: /intro/paywall
  premium allows: /account/login
  signedIn allows: /home/details/5?tab=a
  a notification: stays
pages that a change takes out of the stack
  signedIn stops: /account/login
  premium stops: /intro/paywall
  a page outside the flows: /intro/paywall
  premium allows: /account/login
  signedIn allows: /home/details/5?tab=a
  signedIn stops: /account/login
  signedIn allows: /
a flow with nothing remembered
  asked /intro/terms: shows it
  firstRun stops: stays
  a notification: stays
  premium stops: stays
  premium allows: stays
  firstRun allows: /
  a notification: stays
  firstRun stops: /intro
  firstRun allows, outside its flow: stays
a location of a flow asked last
  firstRun stops: /intro
  asked /account/login: /intro
  firstRun allows: /home
the location / asked last
  signedIn stops: /account/login
  asked /: /account/login
  signedIn allows: /
''');
    });

    test(
        'the generated class takes note of what the guards allow when it is '
        'told of no pages, so that a notification without a change ends no '
        'flow later; and of two guards with one target, the flow is over '
        'only once both allow', () async {
      expect(
        await printedBy(_vmSharedTargetMain, data: _sharedTargetData),
        '''
a change before the router has a page
  both allow, no pages: stays
  asked /intro/terms: shows it
  a notification in the flow: stays
two guards with one target
  firstRun stops: stays
  premium stops: stays
  firstRun allows: stays
  premium allows: /
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
        'a GuardedNavigation and read guardChanges.',
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
          'The provider of the router role does not ask the guards',
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: data ?? _guardedData,
              presentRoles: {routerRole},
              context: testContext,
            ),
            files: {
              for (final file in files) file.path: file,
              // A file of a feature that uses both, which asks nothing for
              // the router.
              screenPath: const DartFileIndex(
                path: screenPath,
                imports: [
                  IndexedImport('package:my_app/core/router/app_router.dart'),
                ],
                invocations: [IndexedInvocation('GuardedNavigation')],
                references: [IndexedReference('guardChanges')],
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
    /// file of the role by a relative path, and calls [calls] and reads
    /// [reads].
    DartFileIndex factory({
      List<String> calls = const [],
      List<String> reads = const [],
    }) =>
        DartFileIndex(
          path: factoryPath,
          imports: const [IndexedImport('app_router.dart')],
          invocations: [for (final name in calls) IndexedInvocation(name)],
          references: [for (final name in reads) IndexedReference(name)],
        );

    String problem(String what) =>
        'The provider of the router role does not ask the guards of the '
        'app: none of its files $what of ${RouterRole.appRouterFile}.';

    test(
        'accepts a provider whose files create a GuardedNavigation and read '
        'guardChanges', () {
      expect(
        check([
          factory(calls: ['GuardedNavigation'], reads: ['guardChanges']),
        ]),
        isEmpty,
      );
      // In two of its files, one of which imports the file of the role
      // with a prefix.
      expect(
        check([
          factory(calls: ['GuardedNavigation']),
          const DartFileIndex(
            path: delegatePath,
            imports: [
              IndexedImport(
                'package:my_app/core/router/app_router.dart',
                prefix: 'router',
              ),
            ],
            memberAccesses: [IndexedMemberAccess('router', 'guardChanges')],
          ),
        ]),
        isEmpty,
      );
    });

    test('reports a provider that does not ask the guards', () {
      final issues = check([factory()]);

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
            factory(calls: ['GuardedNavigation']),
          ]))
            issue.message,
        ],
        [problem('reads guardChanges')],
      );
      expect(
        [
          for (final issue in check([
            factory(reads: ['guardChanges']),
          ]))
            issue.message,
        ],
        [problem('creates a GuardedNavigation')],
      );
      // A provider that only calls redirectOf() keeps nothing of what the
      // guards make a router remember.
      expect(
        check([
          factory(calls: ['redirectOf'], reads: ['guardChanges']),
        ]),
        hasLength(1),
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
          ),
        ]),
        hasLength(2),
      );
    });

    test(
        'checks an app with guards and the files of a provider among its '
        'modules, and nothing otherwise', () {
      expect(check(const []), hasLength(2));
      expect(check(const [], withProvider: false), isEmpty);
      expect(check([factory()], data: _data), isEmpty);
    });
  });
}
