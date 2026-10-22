@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/bundles/purchases_role_bundle.dart';
import 'package:smf_contracts/bundles/purchases_role_setting_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake provider of purchases in the test app.
const _fakeFile = ImportRef.app('fakes/fake_purchases.dart');

/// The file of the fake provider of sign-in in the test app.
const _fakeAuthFile = ImportRef.app('fakes/fake_auth.dart');

/// The file of `appPurchases`, as code imports it.
const _controllerImport = ImportRef.app('core/purchases/app_purchases.dart');

/// The template of the role, as the origin of what it contributes.
const _template = RoleTemplateOrigin(purchasesRole);

/// The implementation of the service of the test app: one that is created
/// asynchronously, or one created with the app.
RoleImplementation _implementation({required bool async}) => async
    ? const RoleImplementation.async(
        type: TypeRef('FakePurchases', import: _fakeFile),
        init: FactoryRef('openFakePurchases', import: _fakeFile),
      )
    : const RoleImplementation(
        type: TypeRef('FakePurchases', import: _fakeFile),
        create: FactoryRef('createFakePurchases', import: _fakeFile),
      );

/// What the template of the role contributes.
List<Contribution> _contributions() =>
    purchasesRole.template.contribute(testContext);

/// The data that the template of the role gives [role].
List<RoleData<Object>> _dataFor(Role role) => [
      for (final contribution in _contributions())
        if (contribution case final RoleData<Object> data
            when data.role == role)
          data.withOrigin(_template),
    ];

/// The files of the role in an app with the roles in [present], rendered
/// with an implementation that is created asynchronously, or with the app,
/// and with [data] of other roles, and what the template puts into other
/// sockets.
Future<RenderedTemplate> _rendered({
  Set<Role> present = const {},
  bool async = false,
  List<RoleData<Object>> data = const [],
}) =>
    renderTemplate(
      purchasesRole,
      data: [
        dataOf(
          purchasesRole,
          _implementation(async: async),
          module: 'fake_purchases',
        ),
        ...data,
      ],
      present: present,
    );

/// A stand-in for the part of Flutter's foundation library that the files
/// of the role and of the auth role use, with the signatures of Flutter
/// 3.44: the app runs in debug mode, and what it prints goes to
/// `debugPrinted`. A notifier that was disposed of throws when it is used.
const _foundation = r'''
const bool kDebugMode = true;

/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('$message');

class Immutable {
  const Immutable();
}

const Immutable immutable = Immutable();

typedef VoidCallback = void Function();

abstract class Listenable {
  const Listenable();

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

abstract class ValueListenable<T> extends Listenable {
  const ValueListenable();

  T get value;
}

mixin class ChangeNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;

  void _notDisposed() {
    if (_disposed) throw StateError('A $runtimeType was used after dispose.');
  }

  @override
  void addListener(VoidCallback listener) {
    _notDisposed();
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notifyListeners() {
    _notDisposed();
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  void dispose() {
    _notDisposed();
    _disposed = true;
    _listeners.clear();
  }
}

class ValueNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  ValueNotifier(this._value);

  T _value;

  @override
  T get value => _value;

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }
}

class ErrorDescription {
  ErrorDescription(this.message);

  final String message;
}

class FlutterErrorDetails {
  const FlutterErrorDetails({
    required this.exception,
    this.stack,
    this.library = 'Flutter framework',
    this.context,
  });

  final Object exception;
  final StackTrace? stack;
  final String? library;
  final ErrorDescription? context;
}

class FlutterError {
  static void reportError(FlutterErrorDetails details) {}
}

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

TargetPlatform get defaultTargetPlatform => TargetPlatform.android;
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the role and of the auth role use: what that library exports of the
/// foundation library, and the binding with the observers of the lifecycle
/// of the app. `lifecycle()` puts the app into a state, and `resumeApp()`
/// stands for the user who comes back to the app.
const _widgets = '''
export 'foundation.dart'
    show
        ChangeNotifier,
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        Listenable,
        ValueNotifier,
        VoidCallback,
        debugPrint,
        immutable;

enum AppLifecycleState { detached, resumed, inactive, hidden, paused }

abstract class Widget {
  const Widget();
}

final class BuildContext {
  const BuildContext();
}

abstract mixin class WidgetsBindingObserver {
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

class WidgetsBinding {
  static final WidgetsBinding instance = WidgetsBinding();

  /// The observers that were added and not removed.
  final List<WidgetsBindingObserver> observers = [];

  void addObserver(WidgetsBindingObserver observer) => observers.add(observer);

  bool removeObserver(WidgetsBindingObserver observer) =>
      observers.remove(observer);
}

/// The app comes into [state], which every observer is told of.
void lifecycle(AppLifecycleState state) {
  for (final observer in [...WidgetsBinding.instance.observers]) {
    observer.didChangeAppLifecycleState(state);
  }
}

/// The user comes back to the app, which was shown but not in use.
void resumeApp() {
  lifecycle(AppLifecycleState.inactive);
  lifecycle(AppLifecycleState.resumed);
}
''';

/// A provider of purchases for the test app, which keeps to the contract
/// of `PurchasesService` unless a test says otherwise.
///
/// The access of each user is on a map that stands for the server of the
/// provider, which each new service reads, as a service does at the next
/// launch of an app. An answer has the access that the user had when it was
/// asked for. The services note their calls, and a test holds a call until
/// it lets it go, or makes it fail.
const _fakePurchases = r'''
import 'dart:async';

import '../core/purchases/purchases_service.dart';

/// The access of each user on the server, by the id of the user, `null`
/// for the user of the device.
final Map<String?, AppAccess> accessOf = {};

/// The calls that reached the services, in order, each with its argument.
final List<String> calls = [];

/// The [calls] since it last asked.
List<String> takeCalls() {
  final taken = [...calls];
  calls.clear();
  return taken;
}

/// The calls that wait until their completer completes, by their names.
final Map<String, Completer<void>> holds = {};

/// What the calls throw, by their names.
final Map<String, Object> failures = {};

/// Whether the user cancels the sheet of the store.
bool cancels = false;

/// What a restore finds for the user.
AppAccess restorable = const NoAccess();

/// How many services were created.
int created = 0;

/// A plan that renews each month, with a free week first.
const monthly = Plan(
  id: 'monthly',
  title: 'Monthly',
  price: r'$4.99',
  amount: 4.99,
  currencyCode: 'USD',
  period: BillingPeriod(1, BillingUnit.month),
  introOffer: IntroOffer(
    price: r'$0.00',
    amount: 0,
    period: BillingPeriod(1, BillingUnit.week),
  ),
);

/// A plan paid once.
const lifetime = Plan(
  id: 'lifetime',
  title: 'Lifetime',
  price: r'$49.99',
  amount: 49.99,
  currencyCode: 'USD',
);

/// The access that a purchase of each plan gives.
final Map<String, AppAccess> premiumOf = {
  'monthly': PremiumAccess(
    expiresAt: DateTime.utc(2030),
    renews: true,
    inTrial: true,
    period: const BillingPeriod(1, BillingUnit.month),
    manageUrl: Uri.parse('https://store.example.com/manage'),
  ),
  'lifetime': const PremiumAccess(),
};

PurchasesService createFakePurchases() => FakePurchases();

Future<PurchasesService> openFakePurchases() async {
  await Future<void>.delayed(Duration.zero);
  return FakePurchases();
}

final class FakePurchases implements PurchasesService {
  FakePurchases() {
    created++;
  }

  final StreamController<AppAccess> _changes = StreamController.broadcast();

  String? _user;

  /// Whether something follows the changes of the access.
  bool get hasListener => _changes.hasListener;

  /// The provider tells of [access], as after a renewal or a grant made
  /// elsewhere.
  void tell(AppAccess access) => _changes.add(access);

  /// Sends [error] to those who follow the changes of the access.
  void fail(Object error) => _changes.addError(error);

  Future<void> _enter(String call) async {
    calls.add(call);
    await holds[call]?.future;
    if (failures[call] case final failure?) throw failure;
  }

  @override
  Future<void> identify(String? userId) async {
    await _enter('identify $userId');
    _user = userId;
  }

  @override
  Future<AppAccess> access() async {
    final user = _user;
    await _enter('access');
    return accessOf[user] ?? const NoAccess();
  }

  @override
  Stream<AppAccess> get accessChanges => _changes.stream;

  @override
  Future<List<Plan>> plans() async {
    await _enter('plans');
    return const [monthly, lifetime];
  }

  @override
  Future<AppAccess?> purchase(Plan plan) async {
    final user = _user;
    await _enter('purchase ${plan.id}');
    if (cancels) return null;
    return accessOf[user] = premiumOf[plan.id]!;
  }

  @override
  Future<AppAccess> restore() async {
    final user = _user;
    await _enter('restore');
    return accessOf[user] = restorable;
  }
}
''';

/// A provider of sign-in for the test app with the calls that the session
/// of an app in the mode `required` makes for a sign-up and a sign-out.
const _fakeAuth = '''
import 'dart:async';

import '../core/auth/auth_service.dart';

AuthService createFakeAuth() => FakeAuth();

final class FakeAuth implements AuthService {
  final StreamController<AuthUser?> _changes = StreamController.broadcast();

  @override
  AuthUser? currentUser;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> signUp({required String email, required String password}) async {
    currentUser = AuthUser(uid: 'user-1', isAnonymous: false, email: email);
    _changes.add(currentUser);
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    _changes.add(null);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
''';

/// What the scripts for the test app share. `pump` lets what is on its way
/// happen, `show` tells an access, and `failureOf` the failure of a call.
const _notes = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app/core/purchases/app_purchases.dart';
import 'package:my_app/fakes/fake_purchases.dart';

final result = <String, Object?>{};

Future<void> pump() => Future<void>.delayed(Duration.zero);

String show(AppAccess access) => switch (access) {
      NoAccess() => 'none',
      PremiumAccess(:final expiresAt, :final renews, :final inTrial) => [
          'premium',
          if (expiresAt != null) 'until ${expiresAt.year}',
          if (renews) 'renews',
          if (inTrial) 'in trial',
        ].join(' '),
    };

/// The failure of [call], as its reason and its hint.
Future<String> failureOf(Future<Object?> Function() call) async {
  try {
    await call();
    return 'no failure';
  } on PurchasesFailure catch (failure, stackTrace) {
    final where = '$stackTrace'.contains('fake_purchases.dart')
        ? ', thrown in fake_purchases.dart'
        : '';
    return '${failure.reason.name} (${failure.developerHint})$where';
  }
}

/// The purchases service of the app, as a fake.
FakePurchases get service => createPurchasesService() as FakePurchases;
''';

/// Goes through the life of the purchases of an app without sign-in: the
/// first launch, the plans, a purchase that the user cancels, a purchase,
/// the changes that the provider tells of, a return to the app after the
/// access ended, a restore, and the next launch. After each step it notes
/// the access, whether the user has premium access, the calls that reached
/// the provider and what the listeners heard.
const _life = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final heard = <String>[];
  final premium = <bool>[];
  appPurchases.addListener(() => heard.add(show(appPurchases.value)));
  appPurchases.hasPremium.addListener(
    () => premium.add(appPurchases.hasPremium.value),
  );
  void note(String step) {
    result[step] = {
      'access': show(appPurchases.value),
      'premium': appPurchases.hasPremium.value,
      'calls': takeCalls(),
      'heard': [...heard],
    };
    heard.clear();
  }

  note('before the start');
  await initPurchases();
  note('a first launch');
  final plans = await appPurchases.plans();
  result['the plans'] = [for (final plan in plans) plan.id];
  note('after the plans');
  cancels = true;
  result['a purchase that the user cancels'] =
      await appPurchases.purchase(monthly);
  cancels = false;
  note('after a purchase that the user cancels');
  result['a purchase'] = await appPurchases.purchase(monthly);
  note('after a purchase');
  service.tell(premiumOf['monthly']!);
  await pump();
  note('the same access, which the provider tells of');
  service.tell(PremiumAccess(expiresAt: DateTime.utc(2030)));
  await pump();
  note('a renewal that the user cancelled elsewhere');
  accessOf[null] = const NoAccess();
  resumeApp();
  await pump();
  note('a return to the app after the access ended');
  restorable = const PremiumAccess();
  result['a restore'] = show(await appPurchases.restore());
  note('after a restore');

  final first = service;
  await initPurchases();
  note('the next launch');
  result['the services'] = {
    'created': created,
    'the first one is followed': first.hasListener,
    'observers of the lifecycle': WidgetsBinding.instance.observers.length,
  };
  result['what the listeners of hasPremium heard'] = premium;
  port.send(result);
}
''';

/// What [_life] sends back.
const Map<String, Object?> _lifeResult = {
  'before the start': {
    'access': 'none',
    'premium': false,
    'calls': <Object?>[],
    'heard': <Object?>[],
  },
  // The start identifies the user of the device first, then asks for the
  // access, and tells nobody of an access that has not changed.
  'a first launch': {
    'access': 'none',
    'premium': false,
    'calls': ['identify null', 'access'],
    'heard': <Object?>[],
  },
  'the plans': ['monthly', 'lifetime'],
  'after the plans': {
    'access': 'none',
    'premium': false,
    'calls': ['plans'],
    'heard': <Object?>[],
  },
  'a purchase that the user cancels': false,
  'after a purchase that the user cancels': {
    'access': 'none',
    'premium': false,
    'calls': ['purchase monthly'],
    'heard': <Object?>[],
  },
  'a purchase': true,
  'after a purchase': {
    'access': 'premium until 2030 renews in trial',
    'premium': true,
    'calls': ['purchase monthly'],
    'heard': ['premium until 2030 renews in trial'],
  },
  // An equal access tells nobody.
  'the same access, which the provider tells of': {
    'access': 'premium until 2030 renews in trial',
    'premium': true,
    'calls': <Object?>[],
    'heard': <Object?>[],
  },
  'a renewal that the user cancelled elsewhere': {
    'access': 'premium until 2030',
    'premium': true,
    'calls': <Object?>[],
    'heard': ['premium until 2030'],
  },
  // A return asks for the access again, and the service has the user.
  'a return to the app after the access ended': {
    'access': 'none',
    'premium': false,
    'calls': ['access'],
    'heard': ['none'],
  },
  'a restore': 'premium',
  'after a restore': {
    'access': 'premium',
    'premium': true,
    'calls': ['restore'],
    'heard': ['premium'],
  },
  // The value is that of the new service, which the server gives the
  // access that the restore gave.
  'the next launch': {
    'access': 'premium',
    'premium': true,
    'calls': ['identify null', 'access'],
    'heard': ['none', 'premium'],
  },
  'the services': {
    'created': 2,
    'the first one is followed': false,
    'observers of the lifecycle': 1,
  },
  // Each change of the access tells them, also one that leaves the flag
  // as it was.
  'what the listeners of hasPremium heard': [
    true,
    true,
    false,
    true,
    false,
    true,
  ],
};

/// Makes calls before the first start: the plans, a purchase of a plan
/// that they gave, made once they came, and a restore; and a start whose
/// access takes longer than the wait of the start, with a call made after
/// it.
const _earlyCalls = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final done = <String>[];
  unawaited(
    appPurchases.plans().then((plans) {
      done.add('plans: ${plans.length}');
      return appPurchases.purchase(plans.last);
    }).then((bought) => done.add('purchase: $bought')),
  );
  unawaited(
    appPurchases.restore().then((access) => done.add('restore: ${show(access)}')),
  );
  await pump();
  result['before the start'] = {'calls': takeCalls(), 'done': [...done]};
  await initPurchases();
  result['when the start completes'] = {
    'calls': takeCalls(),
    'access': show(appPurchases.value),
  };
  await pump();
  result['the calls that are done'] = done;

  // A start whose access does not come in time completes after the wait,
  // and a call made then waits for the access.
  final controller =
      AppPurchasesController(startWait: const Duration(milliseconds: 20));
  final slow = FakePurchases();
  accessOf[null] = const PremiumAccess();
  final hold = holds['access'] = Completer<void>();
  var started = false;
  final start = controller.start(slow).then((_) => started = true);
  await pump();
  final whileWaiting = {
    'the start is done': started,
    'access': show(controller.value),
  };
  await start;
  final plans = controller.plans();
  await pump();
  result['a start whose access takes longer than its wait'] = {
    'while it waits': whileWaiting,
    'after the wait': {
      'access': show(controller.value),
      'calls': takeCalls(),
    },
  };
  holds.clear();
  hold.complete();
  await plans;
  result['once the access comes'] = {
    'access': show(controller.value),
    'calls': takeCalls(),
  };
  controller.dispose();
  port.send(result);
}
''';

/// Starts a controller whose user a test changes, as the session of an app
/// with sign-in tells: a change, the same user again, changes while a
/// purchase is on its way, an identification that fails, and a call after
/// it.
const _users = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final user = ValueNotifier<String?>('a');
  final controller = AppPurchasesController();
  final service = FakePurchases();
  accessOf['a'] = premiumOf['monthly']!;
  accessOf['c'] = const PremiumAccess();
  final heard = <String>[];
  controller.addListener(() => heard.add(show(controller.value)));
  void note(String step) {
    result[step] = {
      'access': show(controller.value),
      'calls': takeCalls(),
      'heard': [...heard],
    };
    heard.clear();
  }

  await controller.start(
    service,
    userId: () => user.value,
    userChanges: user,
  );
  note('the start');
  user.value = 'b';
  final atOnce = show(controller.value);
  await pump();
  note('a change of the user');
  result['the access right after the change'] = atOnce;
  user.notifyListeners();
  await pump();
  note('the same user again');

  // The user changes three times while a purchase of b is on its way.
  final hold = holds['purchase monthly'] = Completer<void>();
  final bought = controller.purchase(monthly);
  await pump();
  user
    ..value = 'c'
    ..value = 'a'
    ..value = 'c';
  await pump();
  note('changes while a purchase is on its way');
  holds.clear();
  hold.complete();
  result['the purchase'] = await bought;
  await pump();
  note('after the purchase');
  result['what b has'] = show(accessOf['b']!);

  // A change of the user back to the one that the service has, before the
  // look at the new one had its turn.
  final holdOfPlans = holds['plans'] = Completer<void>();
  final plans = controller.plans();
  await pump();
  user
    ..value = 'a'
    ..value = 'c';
  await pump();
  holds.clear();
  holdOfPlans.complete();
  await plans;
  await pump();
  note('a change back to the user of the service');

  // An identification that fails: the service tells of an access, which
  // counts for nothing, and the next call identifies the user again.
  failures['identify b'] =
      const PurchasesFailure(PurchasesFailureReason.network);
  user.value = 'b';
  await pump();
  note('a change whose identification fails');
  service.tell(const PremiumAccess());
  await pump();
  note('an access that the service tells of meanwhile');
  failures.clear();
  accessOf['b'] = const PremiumAccess();
  result['a call then'] = (await controller.plans()).length;
  await pump();
  note('after the call');
  controller.dispose();
  port.send(result);
}
''';

/// Makes the calls fail with each failure of the provider and with errors
/// of other kinds, and the start, the returns to the app and the changes
/// of the access with failures that no caller sees.
const _errors = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final uncaught = <String>[];
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      final controller = AppPurchasesController();
      final service = FakePurchases();
      const notSetUp = PurchasesFailure(
        PurchasesFailureReason.notConfigured,
        developerHint: 'Fill in the key.',
      );
      failures['identify null'] = notSetUp;
      await controller.start(service);
      resumeApp();
      await pump();
      result['a start that is not set up'] = {
        'access': show(controller.value),
        'calls': takeCalls(),
        'printed': [...debugPrinted],
      };
      result['a call that is not set up'] = await failureOf(controller.plans);
      failures.clear();
      takeCalls();

      result['a failure of the provider'] = {
        for (final reason in PurchasesFailureReason.values)
          reason.name: await failureOf(() {
            failures['plans'] = PurchasesFailure(reason);
            return controller.plans();
          }),
      };
      failures['plans'] = StateError('The plugin broke.');
      result['an error of another kind'] = await failureOf(controller.plans);
      failures['plans'] = 'A text that was thrown.';
      result['an object that is no error'] =
          await failureOf(controller.plans);
      failures.clear();
      result['a failure as text'] = [
        '${const PurchasesFailure(PurchasesFailureReason.network)}',
        '$notSetUp',
      ];

      debugPrinted.clear();
      for (final failure in <Object>[
        const PurchasesFailure(PurchasesFailureReason.network),
        const PurchasesFailure(PurchasesFailureReason.unavailable),
        const PurchasesFailure(
          PurchasesFailureReason.storeProblem,
          developerHint: 'The store broke.',
        ),
        StateError('The access broke.'),
        notSetUp,
        const PurchasesFailure(
          PurchasesFailureReason.notConfigured,
          developerHint: 'Fill in another key.',
        ),
      ]) {
        failures['access'] = failure;
        resumeApp();
        await pump();
      }
      failures.clear();
      service
        ..fail(StateError('The changes broke.'))
        ..fail(const PurchasesFailure(PurchasesFailureReason.network));
      await pump();
      result['printed'] = [...debugPrinted];
      controller.dispose();
      done.complete();
    },
    (error, stackTrace) => uncaught.add('$error'),
  );
  await done.future;
  result['uncaught'] = uncaught;
  port.send(result);
}
''';

/// A start that is not set up in a release build: the app prints nothing.
const _release = '''
Future<void> main(List<String> arguments, SendPort port) async {
  failures['identify null'] = const PurchasesFailure(
    PurchasesFailureReason.notConfigured,
    developerHint: 'Fill in the key.',
  );
  await initPurchases();
  result['access'] = show(appPurchases.value);
  result['printed'] = debugPrinted;
  port.send(result);
}
''';

/// Compares the answers of the service, and tells them as text.
const _types = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final at = DateTime.utc(2030);
  final page = Uri.parse('https://store.example.com/manage');
  const month = BillingPeriod(1, BillingUnit.month);
  PremiumAccess premium({
    DateTime? expiresAt,
    bool renews = true,
    bool inTrial = true,
    BillingPeriod? period = month,
    Uri? manageUrl,
  }) =>
      PremiumAccess(
        expiresAt: expiresAt ?? at,
        renews: renews,
        inTrial: inTrial,
        period: period,
        manageUrl: manageUrl ?? page,
      );
  result['equal'] = {
    'no access': const NoAccess() == const NoAccess(),
    'premium access': premium() == premium(),
    'another end': premium() == premium(expiresAt: DateTime.utc(2031)),
    'another renewal': premium() == premium(renews: false),
    'another trial': premium() == premium(inTrial: false),
    'another period': premium() == premium(period: null),
    'another page': premium() ==
        premium(manageUrl: Uri.parse('https://store.example.com/other')),
    'no access and premium access':
        const NoAccess() == const PremiumAccess(),
    'periods': const BillingPeriod(3, BillingUnit.month) ==
        const BillingPeriod(3, BillingUnit.month),
    'another unit': const BillingPeriod(3, BillingUnit.month) ==
        const BillingPeriod(3, BillingUnit.week),
    'another count': const BillingPeriod(3, BillingUnit.month) ==
        const BillingPeriod(1, BillingUnit.month),
    'as keys': {
      const NoAccess(),
      const NoAccess(),
      premium(),
      premium(),
      const BillingPeriod(1, BillingUnit.year),
      const BillingPeriod(1, BillingUnit.year),
    }.length,
  };
  result['as text'] = [
    '${const NoAccess()}',
    '${premium()}',
    '$month',
  ];
  result['free'] = [
    const IntroOffer(price: r'$0.00', amount: 0, period: month).isFree,
    const IntroOffer(price: r'$0.99', amount: 0.99, period: month).isFree,
    const IntroOffer(price: r'$0.00', amount: 0, period: month).cycles,
  ];
  port.send(result);
}
''';

/// Disposes of a controller with a purchase on its way, and changes the
/// user and the access after that.
const _dispose = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final user = ValueNotifier<String?>('a');
  final controller = AppPurchasesController();
  final service = FakePurchases();
  await controller.start(
    service,
    userId: () => user.value,
    userChanges: user,
  );
  final observers = WidgetsBinding.instance.observers.length;
  takeCalls();
  final hold = holds['purchase monthly'] = Completer<void>();
  final bought = controller.purchase(monthly);
  await pump();
  controller.dispose();
  holds.clear();
  hold.complete();
  result['the purchase on its way'] = await bought;
  user.value = 'b';
  service.tell(const PremiumAccess());
  resumeApp();
  await pump();
  result['after the dispose'] = {
    'access': show(controller.value),
    'calls': takeCalls(),
    'observers of the lifecycle': [
      observers,
      WidgetsBinding.instance.observers.length,
    ],
    'the service is followed': service.hasListener,
  };
  port.send(result);
}
''';

/// Starts an app with sign-in as `bootstrap()` does, and signs up and out.
const _withAuth = '''
import 'package:my_app/core/auth/app_session.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  await initAuth();
  await initPurchases();
  result['a first launch'] = takeCalls();
  await appSession.signUp(email: 'ada@example.com', password: 'secret');
  await pump();
  result['a sign-up'] = takeCalls();
  await appSession.signOut();
  await pump();
  result['a sign-out'] = takeCalls();
  port.send(result);
}
''';

/// The files of the test app: the files of the role, as its template
/// generates them in an app with sign-in, or without it, those of the
/// auth role in the first, and the fakes. The app runs in debug mode, or
/// in a release build without [debug].
Future<DartFiles> _app({
  bool async = false,
  bool auth = false,
  bool debug = true,
}) async {
  final purchases = await _rendered(
    async: async,
    present: {if (auth) authRole},
  );
  final session = auth
      ? await renderTemplate(
          authRole,
          data: [
            dataOf(
              authRole,
              const AuthImplementation(
                type: TypeRef('FakeAuth', import: _fakeAuthFile),
                create: FactoryRef('createFakeAuth', import: _fakeAuthFile),
              ),
              module: 'fake_auth',
            ),
          ],
          choice: AuthMode.required,
        )
      : null;
  return DartFiles.write(
    {
      ...purchases.files,
      ...?session?.files,
      'lib/fakes/fake_purchases.dart': _fakePurchases,
      if (auth) 'lib/fakes/fake_auth.dart': _fakeAuth,
    },
    flutter: {
      'foundation.dart': debug
          ? _foundation
          : _foundation.replaceFirst(
              'const bool kDebugMode = true;',
              'const bool kDebugMode = false;',
            ),
      'widgets.dart': _widgets,
    },
  );
}

/// [script], a script of [_notes] that has imports of its own, with them
/// among the imports of [_notes].
String _withImports(String script) {
  final imports = RegExp(r'^import .*;$', multiLine: true);
  final own = [for (final match in imports.allMatches(script)) match[0]!];
  final last = imports.allMatches(_notes).last;
  return [
    _notes.substring(0, last.end),
    ...own,
    _notes.substring(last.end),
    script.replaceAll(imports, ''),
  ].join('\n');
}

/// The top-level functions of [unit], by name.
Map<String, FunctionDeclaration> _functionsOf(CompilationUnit unit) => {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// The statements of the body of [function].
List<String> _statementsOf(FunctionDeclaration function) => [
      for (final statement
          in (function.functionExpression.body as BlockFunctionBody)
              .block
              .statements)
        '$statement',
    ];

/// The members of the class [name] of [unit] that are methods or getters,
/// each as its signature.
List<String> _methodsOf(CompilationUnit unit, String name) => [
      for (final member in unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((type) => type.namePart.typeName.lexeme == name)
          .body
          .members)
        if (member is MethodDeclaration)
          [
            '${member.returnType} ',
            if (member.isGetter) 'get ',
            member.name.lexeme,
            '${member.parameters ?? ''}',
          ].join(),
    ];

/// The values of the enum [name] of [unit].
List<String> _enumValuesOf(CompilationUnit unit, String name) => [
      for (final constant in unit.declarations
          .whereType<EnumDeclaration>()
          .singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          )
          .body
          .constants)
        constant.name.lexeme,
    ];

/// The named arguments of each creation of a class, by the name of the
/// class.
final class _NamedArgumentsOf extends RecursiveAstVisitor<void> {
  _NamedArgumentsOf(this.className);

  final String className;

  final found = <Map<String, String>>[];

  void _note(String name, ArgumentList arguments) {
    if (name != className) return;
    found.add({
      for (final argument in arguments.arguments.whereType<NamedArgument>())
        argument.name.lexeme: argument.argumentExpression.toSource(),
    });
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _note(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  // Unresolved code has the creation of a class without `new` or `const`
  // as the call of a method.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) _note(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }
}

/// The provider of the role and a feature that uses the role.
const _provider = ModuleDescriptor(
  id: ModuleId('fake_purchases'),
  description: 'Purchases',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(purchasesRole)],
);
const _feature = ModuleDescriptor(
  id: ModuleId('paywall'),
  description: 'Paywall',
  kind: ModuleKinds.feature,
  uses: {purchasesRole},
);

/// The template of another role whose code could reach the service.
final _otherRole = TestRole<NoDsl>('shop', requires: {purchasesRole});

/// The implementation of the provider of the apps of the rules: its class
/// in one file and its function in another.
const _providerImplementation = RoleImplementation(
  type: TypeRef(
    'StorePurchasesService',
    import: ImportRef.app('core/purchases/store_purchases_service.dart'),
  ),
  create: FactoryRef(
    'createStorePurchasesService',
    import: ImportRef.app('core/purchases/store_purchases.dart'),
  ),
);

/// The file of the function of [_providerImplementation], which imports
/// the file of `PurchasesService`, as the file of an implementation may.
const _factoryFile = DartFileIndex(
  path: 'lib/core/purchases/store_purchases.dart',
  imports: [IndexedImport('purchases_service.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createStorePurchasesService',
      kind: DeclarationKind.function,
    ),
  ],
);

/// The issues of the structural rules of the role in an app of the
/// provider with [_providerImplementation] and with [files], each with its
/// owner; a file without an owner has `null`.
List<SmfIssue> _structureIssues(
  Map<DartFileIndex, ContributionOrigin?> files,
) =>
    purchasesRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: [
            dataOf(
              purchasesRole,
              _providerImplementation,
              module: 'fake_purchases',
            ),
          ],
          presentRoles: {purchasesRole},
          context: testContext,
        ),
        files: {
          _factoryFile.path: _factoryFile,
          for (final file in files.keys) file.path: file,
        },
        owners: {
          _factoryFile.path: ModuleOrigin(_provider.id),
          for (final MapEntry(key: file, value: owner) in files.entries)
            if (owner != null) file.path: owner,
        },
        modules: const [_provider, _feature],
      ),
    );

/// The index of the file at [path] that imports the file of `appPurchases`
/// and calls [function] of it.
DartFileIndex _calling(String path, String function) => DartFileIndex(
      path: path,
      imports: const [
        IndexedImport('package:my_app/core/purchases/app_purchases.dart'),
      ],
      invocations: [IndexedInvocation(function)],
    );

void main() {
  group('the purchases role', () {
    test(
        'takes one provider, and works with sign-in, a settings screen and '
        'the languages of the app, and with no router', () {
      expect(purchasesRole.id, 'purchases');
      expect(purchasesRole.description, 'Purchases');
      expect(purchasesRole.presenceFlag, 'has_purchases');
      expect('$purchasesRole', 'purchases role');
      expect(purchasesRole.cardinality, RoleCardinality.atMostOne);
      expect(purchasesRole.requires, isEmpty);
      expect(
        purchasesRole.uses,
        {authRole, settingsScreenRole, localizationRole},
      );
      // Its provider uses what the role uses, so the contract harness
      // builds the apps of a provider with each of those roles and without.
      expect(
        _provider.effectiveUses,
        {authRole, settingsScreenRole, localizationRole},
      );
      expect(_provider.effectiveRequires, isEmpty);
      expect(purchasesRole.sockets, const [PurchasesRole.implementations]);
      expect(
        PurchasesRole.implementations.tag,
        'smf_purchases__implementations',
      );
      expect(purchasesRole.options, isEmpty);
      expect(
        [for (final rule in purchasesRole.moduleRules) rule.id],
        ['services.implementations'],
      );
      expect(
        [for (final rule in purchasesRole.structuralRules) rule.id],
        [
          'purchases.factory_calls',
          'purchases.start_calls',
          'purchases.implementation_factories',
        ],
      );
    });

    test(
        'guarantees the files of the service and of the controller, but not '
        'the file of the entry of the settings screen', () {
      expect(purchasesRole.interface.files, [
        'lib/core/purchases/purchases_service.dart',
        'lib/core/purchases/app_purchases.dart',
      ]);
      expect(purchasesRole.interface.files, [
        PurchasesRole.serviceFile,
        PurchasesRole.controllerFile,
      ]);
      expect(purchasesRole.interface.symbols, isEmpty);
      expect(
        PurchasesRole.settingFile,
        'lib/core/purchases/restore_purchases_setting.dart',
      );
      expect(PurchasesRole.readmeHeading, 'Purchases');
    });

    test(
        'publishes premium access as the condition of a route, whose name '
        'no code of an app has', () {
      expect(PurchasesRole.premium.role, same(purchasesRole));
      expect(PurchasesRole.premium.name, 'premium');
      expect('${PurchasesRole.premium}', 'purchases.premium');
      expect(PurchasesRole.premium, isNot(AuthRole.account));
    });

    test(
        'has the texts of the entry of the settings screen in English and in '
        'Ukrainian, with no problems', () {
      const texts = [
        PurchasesRole.restoreTitle,
        PurchasesRole.restoreActive,
        PurchasesRole.restoreNone,
        PurchasesRole.restoreFailed,
      ];
      for (final text in texts) {
        expect(text.problems(), isEmpty, reason: text.name);
        expect(text.languages, ['en', 'uk'], reason: text.name);
      }
      expect(PurchasesRole.restoreTitle.en, 'Restore purchases');
      expect(PurchasesRole.restoreTitle.textIn('uk'), 'Відновити покупки');
      expect({for (final text in texts) text.name}, hasLength(texts.length));
    });

    test(
        'publishes the steps by hand of the stores, which every provider '
        'that sells there needs, as steps of the role', () {
      const steps = [
        PurchasesRole.storeAgreementsStep,
        PurchasesRole.storeProductsStep,
      ];
      expect(
        [for (final step in steps) step.id.wire],
        ['purchases.store_agreements', 'purchases.store_products'],
      );
      for (final step in steps) {
        expect(step.id.role, same(purchasesRole));
        expect(step.id.module, isNull);
        expect(SmfNames.isSnakeCase(step.id.name), isTrue);
        expect(
          step.title.length,
          lessThanOrEqualTo(ManualStep.maxTitleLength),
        );
        expect(step.title, matches(RegExp(r'^[A-Z][^\n\\]*[^.\s]$')));
        expect(step.when, isEmpty);
      }
    });
  });

  group('the purchases template', () {
    test(
        'generates the files of the role in every app, and the entry only in '
        'an app with a settings screen', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [purchasesRoleBundle.name, purchasesRoleSettingBundle.name],
      );
      expect(
        [for (final brick in bricks) brick.when],
        [
          isEmpty,
          {settingsScreenRole},
        ],
      );
      expect(
        templatesOf(purchasesRoleSettingBundle).keys,
        [PurchasesRole.settingFile],
      );

      for (final settings in [false, true]) {
        final rendered = await _rendered(
          present: {if (settings) settingsScreenRole},
        );
        expect(
          rendered.files.keys.toSet(),
          {
            ...purchasesRole.interface.files,
            if (settings) PurchasesRole.settingFile,
          },
          reason: 'settings: $settings',
        );
        for (final MapEntry(key: path, value: text) in rendered.files.entries) {
          expectParses(text, reason: path);
        }
      }
    });

    test(
        'registers nothing in a DI container, gives the settings screen its '
        'entry, and lists the steps by hand of the stores', () {
      final contributions = _contributions();

      expect(_dataFor(diRole), isEmpty);
      final entry = _dataFor(settingsScreenRole).single;
      // The data needs no condition: it applies only with the role.
      expect(entry.when, isEmpty);
      expect(
        (entry.value as SettingsEntry).file,
        PurchasesRole.settingFile,
      );
      // In every app with the role, which a step of the role applies in.
      expect(
        [
          for (final step in contributions.whereType<ManualStep>())
            (step.id, step.title, step.when.isEmpty),
        ],
        [
          (
            PurchasesRole.storeAgreementsStep.id,
            'Set up payments in App Store Connect and Google Play Console',
            true,
          ),
          (
            PurchasesRole.storeProductsStep.id,
            'Create the products of your plans in App Store Connect and '
                'Google Play Console',
            true,
          ),
        ],
      );
    });

    test(
        'generates the interface that a provider implements, with the types '
        'of its answers and no import', () async {
      final rendered = await _rendered();
      final code = rendered.files[PurchasesRole.serviceFile]!;
      final unit = parseString(content: code).unit;

      expect(_methodsOf(unit, 'PurchasesService'), [
        'Future<void> identify(String? userId)',
        'Future<AppAccess> access()',
        'Stream<AppAccess> get accessChanges',
        'Future<List<Plan>> plans()',
        'Future<AppAccess?> purchase(Plan plan)',
        'Future<AppAccess> restore()',
      ]);
      expect(declaresSealedClass(code, 'AppAccess'), isTrue);
      expect(
        declarationsOf(code),
        containsAll([
          'NoAccess',
          'PremiumAccess.expiresAt',
          'PremiumAccess.renews',
          'PremiumAccess.inTrial',
          'PremiumAccess.period',
          'PremiumAccess.manageUrl',
          'BillingPeriod.count',
          'BillingPeriod.unit',
          'IntroOffer.price',
          'IntroOffer.amount',
          'IntroOffer.period',
          'IntroOffer.cycles',
          'IntroOffer.isFree',
          'Plan.id',
          'Plan.title',
          'Plan.price',
          'Plan.amount',
          'Plan.currencyCode',
          'Plan.period',
          'Plan.introOffer',
          'PurchasesFailure.reason',
          'PurchasesFailure.developerHint',
        ]),
      );
      expect(
        _enumValuesOf(unit, 'BillingUnit'),
        ['day', 'week', 'month', 'year'],
      );
      expect(_enumValuesOf(unit, 'PurchasesFailureReason'), [
        'network',
        'pending',
        'alreadyOwned',
        'notAllowed',
        'unavailable',
        'storeProblem',
        'notConfigured',
        'unknown',
      ]);
      // The file of the provider needs nothing of Flutter and no other
      // file of the app.
      expect(unit.directives, isEmpty);
    });

    test(
        'names in the generated files none of the names that the package '
        'of a known provider exports', () async {
      // The exports of purchases_flutter that the names of the role could
      // clash with in a file of a provider that imports both.
      const exported = {
        'BillingFeature',
        'BillingPlanType',
        'CustomerInfo',
        'EntitlementInfo',
        'IntroductoryPrice',
        'Offering',
        'Package',
        'Period',
        'PeriodUnit',
        'Price',
        'PurchaseResult',
        'Purchases',
        'PurchasesError',
        'PurchasesErrorCode',
        'Store',
        'StoreProduct',
      };
      final rendered = await _rendered(present: {settingsScreenRole});
      final declared = {
        for (final text in rendered.files.values)
          for (final name in declarationsOf(text))
            if (!name.contains('.')) name,
      };
      expect(declared.intersection(exported), isEmpty);
    });

    test(
        'exports the types of the answers of the service from the file of '
        'the controller, but the service', () async {
      final rendered = await _rendered();
      final unit = parseString(
        content: rendered.files[PurchasesRole.controllerFile]!,
      ).unit;
      final export = unit.directives.whereType<ExportDirective>().single;

      expect(export.uri.stringValue, 'purchases_service.dart');
      expect(
        [
          for (final combinator in export.combinators)
            '${combinator.keyword.lexeme} $combinator',
        ],
        ['hide hide PurchasesService'],
      );
    });

    for (final async in [true, false]) {
      final how = async ? 'created asynchronously' : 'created with the app';

      test(
          'creates an implementation $how in initPurchases(), starts '
          'appPurchases with it, and awaits that in the platform phase of '
          'bootstrap()', () async {
        final rendered = await _rendered(async: async);
        final code = rendered.files[PurchasesRole.controllerFile]!;
        final unit = parseString(content: code).unit;

        final init = _functionsOf(unit)['initPurchases']!;
        expect('${init.returnType}', 'Future<void>');
        expect(init.functionExpression.parameters!.parameters, isEmpty);
        expect(_statementsOf(init), [
          if (async)
            '_purchasesService = await impl0.openFakePurchases();'
          else
            '_purchasesService = impl0.createFakePurchases();',
          'await appPurchases.start(_purchasesService);',
        ]);
        expect(
          [
            for (final declaration
                in unit.declarations.whereType<TopLevelVariableDeclaration>())
              declaration.toSource(),
          ],
          contains('late PurchasesService _purchasesService;'),
        );
        // The controller imports no file of another role.
        expect(
          [
            for (final directive
                in unit.directives.whereType<ImportDirective>())
              directive.uri.stringValue,
          ],
          [
            'dart:async',
            'package:flutter/foundation.dart',
            'package:flutter/widgets.dart',
            'purchases_service.dart',
            'package:my_app/fakes/fake_purchases.dart',
          ],
        );
        expect(
          code,
          contains(
            "import 'package:my_app/fakes/fake_purchases.dart' as impl0;",
          ),
        );
        final start = rendered.elsewhere.singleWhere(
          (entry) => entry.socket == AppEntryRole.bootstrapPlatform,
        );
        expect(start.fragment!.code, 'await initPurchases();');
        expect(start.fragment!.imports, [_controllerImport]);
        expect(start.when, isEmpty);
      });
    }

    test(
        'starts appPurchases with the user of appSession in an app with '
        'sign-in, after the session, whatever the names of the modules',
        () async {
      final rendered = await _rendered(present: {authRole}, async: true);
      final code = rendered.files[PurchasesRole.controllerFile]!;
      final unit = parseString(content: code).unit;

      const startWithUser = 'await appPurchases.start(_purchasesService, '
          'userId: () => appSession.value.uid, userChanges: appSession);';
      expect(_statementsOf(_functionsOf(unit)['initPurchases']!), [
        '_purchasesService = await impl0.openFakePurchases();',
        startWithUser,
      ]);
      // The file of the session is the one that the auth role guarantees.
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ],
        contains('package:my_app/${AuthRole.sessionFile.substring(4)}'),
      );
      expect(authRole.interface.files, contains(AuthRole.sessionFile));
      // The order of the code of the platform phase follows the conditions
      // of that code, and the role only uses the auth role, which gives no
      // edge by itself.
      final start = rendered.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.bootstrapPlatform,
      );
      expect(start.fragment!.code, 'await initPurchases();');
      expect(start.when, {authRole});
    });

    test('reports the problems of the implementation', () {
      final issues = purchasesRole.template.validate(
        inputOf(
          purchasesRole,
          data: [
            dataOf(
              purchasesRole,
              const RoleImplementation(
                type: TypeRef('_Private'),
                create: FactoryRef('create', import: _fakeFile),
              ),
              module: 'fake_purchases',
            ),
          ],
        ),
      );
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('fake_purchases')),
      );
    });
  });

  group('the generated controller', () {
    for (final async in [false, true]) {
      group(
          'with an implementation '
          '${async ? 'created asynchronously' : 'created with the app'}', () {
        late DartFiles app;

        setUpAll(() async => app = await _app(async: async));

        tearDownAll(() => app.delete());

        test('is code that type-checks', () async {
          expect(await app.analysisProblems(), isEmpty);
        });

        test(
            'identifies the user first, knows the access when the start '
            'completes, buys, follows the changes that the provider tells '
            'of and asks again when the user comes back, restores, and has '
            'the access of the new service at the next launch', () async {
          expect(await app.run('$_notes$_life'), _lifeResult);
        });
      });
    }

    group('in one app', () {
      late DartFiles app;

      setUpAll(() async => app = await _app());

      tearDownAll(() => app.delete());

      test(
          'runs the calls made before the first start within it, after the '
          'start has the access, with those that their completions make, '
          'and completes a start whose access is late after its wait',
          () async {
        expect(await app.run('$_notes$_earlyCalls'), {
          'before the start': {'calls': <Object?>[], 'done': <Object?>[]},
          // The purchase, which the plans made once they came, runs within
          // the start too, after the restore that was made before it.
          'when the start completes': {
            'calls': [
              'identify null',
              'access',
              'plans',
              'restore',
              'purchase lifetime',
            ],
            'access': 'premium',
          },
          'the calls that are done': [
            'plans: 2',
            'restore: none',
            'purchase: true',
          ],
          'a start whose access takes longer than its wait': {
            'while it waits': {'the start is done': false, 'access': 'none'},
            // The call waits for the access of the start.
            'after the wait': {
              'access': 'none',
              'calls': ['identify null', 'access'],
            },
          },
          // The late access still counts.
          'once the access comes': {
            'access': 'premium',
            'calls': ['plans'],
          },
        });
      });

      test(
          'follows the user: has no access until the service has a new user, '
          'lets a purchase end before it, takes changes that wait in one '
          'turn, and takes no access of the service until an '
          'identification succeeds', () async {
        expect(await app.run('$_notes$_users'), {
          'the start': {
            'access': 'premium until 2030 renews in trial',
            'calls': ['identify a', 'access'],
            'heard': ['premium until 2030 renews in trial'],
          },
          'a change of the user': {
            'access': 'none',
            'calls': ['identify b', 'access'],
            'heard': ['none'],
          },
          'the access right after the change': 'none',
          'the same user again': {
            'access': 'none',
            'calls': <Object?>[],
            'heard': <Object?>[],
          },
          // The identification waits for the purchase.
          'changes while a purchase is on its way': {
            'access': 'none',
            'calls': ['purchase monthly'],
            'heard': <Object?>[],
          },
          'the purchase': true,
          // The purchase belongs to b, and the access is that of c, which
          // the three changes identify once.
          'after the purchase': {
            'access': 'premium',
            'calls': ['identify c', 'access'],
            'heard': ['premium'],
          },
          'what b has': 'premium until 2030 renews in trial',
          // A change to a and back to c, whom the service has, before the
          // look at a had its turn: the look finds c, whom it does not
          // identify again, and the access of c.
          'a change back to the user of the service': {
            'access': 'premium',
            'calls': ['plans', 'access'],
            'heard': ['none', 'premium'],
          },
          'a change whose identification fails': {
            'access': 'none',
            'calls': ['identify b'],
            'heard': ['none'],
          },
          'an access that the service tells of meanwhile': {
            'access': 'none',
            'calls': <Object?>[],
            'heard': <Object?>[],
          },
          'a call then': 2,
          // The call identifies b again, and the access of b follows.
          'after the call': {
            'access': 'premium',
            'calls': ['identify b', 'plans', 'access'],
            'heard': ['premium'],
          },
        });
      });

      test(
          'fails only with a PurchasesFailure, keeps the stack trace of the '
          'provider, starts and runs when the provider is not set up, prints '
          'each hint of that once, and leaves the other failures that no '
          'caller sees to the handler of the uncaught errors', () async {
        const thrown = ', thrown in fake_purchases.dart';
        const printed = 'Purchases are not set up, so the app runs without '
            'them:';
        expect(await app.run('$_notes$_errors'), {
          'a start that is not set up': {
            'access': 'none',
            // A return to the app tries again.
            'calls': ['identify null', 'identify null'],
            'printed': ['$printed Fill in the key.'],
          },
          'a call that is not set up': 'notConfigured (Fill in the key.)'
              '$thrown',
          'a failure of the provider': {
            for (final reason in [
              'network',
              'pending',
              'alreadyOwned',
              'notAllowed',
              'unavailable',
              'storeProblem',
              'notConfigured',
              'unknown',
            ])
              reason: '$reason (null)$thrown',
          },
          'an error of another kind':
              'unknown (Bad state: The plugin broke.)$thrown',
          'an object that is no error':
              'unknown (A text that was thrown.)$thrown',
          'a failure as text': [
            'PurchasesFailure: network',
            'PurchasesFailure: notConfigured (Fill in the key.)',
          ],
          // The hint that was printed before is not printed again.
          'printed': ['$printed Fill in another key.'],
          'uncaught': [
            'PurchasesFailure: storeProblem (The store broke.)',
            'Bad state: The access broke.',
            'Bad state: The changes broke.',
          ],
        });
      });

      test(
          'compares the answers of the service by their values, and tells '
          'them as text', () async {
        const premium = 'PremiumAccess(expiresAt: 2030-01-01 00:00:00.000Z, '
            'renews: true, inTrial: true, period: BillingPeriod(1 month), '
            'manageUrl: https://store.example.com/manage)';
        expect(await app.run('$_notes$_types'), {
          'equal': {
            'no access': true,
            'premium access': true,
            'another end': false,
            'another renewal': false,
            'another trial': false,
            'another period': false,
            'another page': false,
            'no access and premium access': false,
            'periods': true,
            'another unit': false,
            'another count': false,
            'as keys': 3,
          },
          'as text': [
            'NoAccess()',
            premium,
            'BillingPeriod(1 month)',
          ],
          'free': [true, false, 1],
        });
      });

      test(
          'stops following the service, the user and the lifecycle of the '
          'app once it is disposed of, and lets a call on its way end',
          () async {
        expect(await app.run('$_notes$_dispose'), {
          'the purchase on its way': true,
          'after the dispose': {
            'access': 'none',
            'calls': ['purchase monthly'],
            'observers of the lifecycle': [1, 0],
            'the service is followed': false,
          },
        });
      });
    });

    test('prints nothing in a release build', () async {
      final app = await _app(debug: false);
      addTearDown(app.delete);

      expect(await app.run('$_notes$_release'), {
        'access': 'none',
        'printed': <Object?>[],
      });
    });

    test(
        'type-checks in an app with sign-in, and identifies the user of the '
        'session when it starts, signs up and signs out', () async {
      final app = await _app(auth: true);
      addTearDown(app.delete);

      expect(await app.analysisProblems(), isEmpty);
      expect(await app.run(_withImports(_withAuth)), {
        'a first launch': ['identify null', 'access'],
        'a sign-up': ['identify user-1', 'access'],
        'a sign-out': ['identify null', 'access'],
      });
    });
  });
  group('the entry of the settings screen', () {
    late String code;
    late CompilationUnit unit;

    setUpAll(() async {
      final rendered = await _rendered(
        present: {settingsScreenRole, localizationRole},
        data: _dataFor(localizationRole),
      );
      code = rendered.files[PurchasesRole.settingFile]!;
      unit = parseString(content: code).unit;
    });

    /// The named arguments of each creation of [className] in the file.
    List<Map<String, String>> created(String className) {
      final found = _NamedArgumentsOf(className);
      unit.accept(found);
      return found.found;
    }

    test(
        'is given to the settings screen role, which shows it, and has a '
        'constant constructor that requires no arguments', () {
      final data = _dataFor(settingsScreenRole);
      final input = inputOf(
        settingsScreenRole,
        data: data,
        present: {routerRole},
      );

      expect(settingsScreenRole.template.validate(input), isEmpty);
      final entry = settingsScreenRole.entriesIn(input).single;
      expect(entry.widget.name, 'RestorePurchasesSetting');
      expect(entry.file, PurchasesRole.settingFile);
      final constructor = unit.declarations
          .whereType<ClassDeclaration>()
          .firstWhere(
            (type) => type.namePart.typeName.lexeme == entry.widget.name,
          )
          .body
          .members
          .whereType<ConstructorDeclaration>()
          .single;
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.name, isNull);
      expect('${constructor.parameters}', '({super.key})');
    });

    test(
        'gives the localization role its texts only in an app with a '
        'settings screen, and reads them from the texts of the app', () {
      final texts = _dataFor(localizationRole);
      expect(texts.single.when, {settingsScreenRole});
      final input = inputOf(
        localizationRole,
        data: texts,
        present: {settingsScreenRole},
      );
      expect(localizationRole.template.validate(input), isEmpty);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        [
          'purchasesRestoreTitle',
          'purchasesRestoreActive',
          'purchasesRestoreNone',
          'purchasesRestoreFailed',
        ],
      );
      for (final text in localizationRole.textsIn(input)) {
        expect(text.owner, _template);
      }

      expect(
        created('ListTile').single['title'],
        'Text(context.l10n.purchasesRestoreTitle)',
      );
      expect(
        code,
        allOf(
          contains('_Outcome.premium => context.l10n.purchasesRestoreActive,'),
          contains('_Outcome.nothing => context.l10n.purchasesRestoreNone,'),
          contains('context.l10n.purchasesRestoreFailed,'),
        ),
      );
    });

    test('writes its texts in English in an app without the localization role',
        () async {
      final rendered = await _rendered(present: {settingsScreenRole});
      final english = rendered.files[PurchasesRole.settingFile]!;

      expect(
        english,
        allOf(
          contains("title: Text('Restore purchases'),"),
          contains("_Outcome.premium => 'Your premium access is back.',"),
          contains("_Outcome.nothing => 'No purchases to restore.',"),
          contains(r"'Couldn\'t restore purchases. Try again.',"),
        ),
      );
      expectParses(english);
    });

    test(
        'restores on a tap, takes no other tap while a restore is on its way '
        'and shows a spinner then, and tells what it found as a live '
        'region, with the hint of a failure in debug mode only', () {
      final row = created('ListTile').single;
      expect(row['leading'], 'const Icon(Icons.restore)');
      expect(row['onTap'], '_restore');
      expect(
        row['trailing'],
        '_restoring ? const SizedBox.square(dimension: 20, child: '
        'CircularProgressIndicator(strokeWidth: 2)) : null',
      );
      expect(
        row['subtitle'],
        'message == null ? null : Semantics(liveRegion: true, child: '
        'Text(message))',
      );
      final state = unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (type) =>
                type.namePart.typeName.lexeme ==
                '_RestorePurchasesSettingState',
          );
      final restore = state.body.members
          .whereType<MethodDeclaration>()
          .singleWhere((method) => method.name.lexeme == '_restore');
      final statements = (restore.body as BlockFunctionBody).block.statements;
      expect('${statements.first}', 'if (_restoring) return;');
      expect(
        '$restore',
        allOf(
          contains('await appPurchases.restore()'),
          contains('access is PremiumAccess ? _Outcome.premium : '
              '_Outcome.nothing'),
          contains('on PurchasesFailure catch (failure)'),
          contains('if (!mounted) return;'),
        ),
      );
      expect(
        code,
        contains('if (_hint case final hint? when kDebugMode) hint'),
      );
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ],
        unorderedEquals([
          'package:flutter/material.dart',
          'app_purchases.dart',
          'package:my_app/core/l10n/l10n.dart',
        ]),
      );
    });
  });

  group('the notes of the purchases role for coding agents', () {
    late Map<String, String> files;

    setUpAll(() async {
      final purchases = await _rendered(
        present: {authRole, settingsScreenRole},
      );
      final session = await renderTemplate(
        authRole,
        data: [
          dataOf(
            authRole,
            const AuthImplementation(
              type: TypeRef('FakeAuth', import: _fakeAuthFile),
              create: FactoryRef('createFakeAuth', import: _fakeAuthFile),
            ),
            module: 'fake_auth',
          ),
        ],
        choice: AuthMode.required,
      );
      files = {...purchases.files, ...session.files};
    });

    test(
        'name what the files of the role declare, in every app and in the '
        'apps with sign-in or a settings screen', () {
      expectNamesOfCode(
        agentNoteOf(purchasesRole),
        {
          PurchasesRole.controllerFile: [
            'appPurchases',
            'AppPurchasesController',
            'AppPurchasesController.value',
            'AppPurchasesController.hasPremium',
            'AppPurchasesController.plans',
            'AppPurchasesController.purchase',
            'AppPurchasesController.restore',
            'AppPurchasesController.start',
            'initPurchases',
            'createPurchasesService',
          ],
          PurchasesRole.serviceFile: [
            'PurchasesService',
            'NoAccess',
            'PremiumAccess',
            'PremiumAccess.manageUrl',
            'Plan',
            'Plan.price',
            'Plan.period',
            'Plan.introOffer',
            'PurchasesFailure',
            'PurchasesFailure.reason',
            'PurchasesFailure.developerHint',
            'PurchasesFailureReason.pending',
            'PurchasesFailureReason.notConfigured',
          ],
        },
        files: files,
      );
      expectNamesOfCode(
        agentNoteOf(purchasesRole, when: {authRole}),
        {
          AuthRole.sessionFile: ['appSession', 'AppSession.uid'],
          PurchasesRole.controllerFile: ['AppPurchasesController.restore'],
        },
        files: files,
      );
      expectNamesOfCode(
        agentNoteOf(purchasesRole, when: {settingsScreenRole}),
        {
          PurchasesRole.settingFile: ['RestorePurchasesSetting'],
        },
        files: files,
      );
      expect(
        agentNoteOf(purchasesRole, when: {settingsScreenRole}).text,
        contains('`${PurchasesRole.settingFile}`'),
      );
    });

    test(
        'name no provider and no kind of product of one, since every plan '
        'gives the same access', () {
      for (final when in <Set<Role>>[
        const {},
        {authRole},
        {settingsScreenRole},
      ]) {
        final text = agentNoteOf(purchasesRole, when: when).text.toLowerCase();
        for (final word in [
          'entitlement',
          'revenuecat',
          'purchases_flutter',
          'storekit',
          'billing library',
        ]) {
          expect(text, isNot(contains(word)), reason: '$when: $word');
        }
      }
    });
  });

  group('the section of the purchases role in the README of the app', () {
    /// The section in an app with the roles in [present].
    Future<String> sectionWith(Set<Role> present) async {
      final rendered = await _rendered(present: present);
      final section = rendered.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.readmeSections,
      );
      expect(section.entryKey, PurchasesRole.readmeHeading);
      expect(section.when, isEmpty);
      return section.entryValue! as String;
    }

    test(
        'tells what appPurchases tells and does, what a screen that sells '
        'shows, how a premium screen is kept from the other users, and what '
        'the app does while purchases are not set up, with the names of the '
        'code', () async {
      final rendered = await _rendered(present: {settingsScreenRole});
      final section = await sectionWith({settingsScreenRole});

      expectNamesOfCodeIn(
        section,
        {
          PurchasesRole.controllerFile: [
            'appPurchases',
            'AppPurchasesController.value',
            'AppPurchasesController.hasPremium',
            'AppPurchasesController.plans',
            'AppPurchasesController.purchase',
            'AppPurchasesController.restore',
          ],
          PurchasesRole.serviceFile: [
            'NoAccess',
            'PremiumAccess',
            'PremiumAccess.expiresAt',
            'PremiumAccess.renews',
            'PremiumAccess.inTrial',
            'PremiumAccess.manageUrl',
            'PurchasesFailure',
            'PurchasesFailure.reason',
            'PurchasesFailure.developerHint',
            'PurchasesFailureReason.notConfigured',
          ],
          PurchasesRole.settingFile: ['RestorePurchasesSetting'],
        },
        files: rendered.files,
      );
      const rules = 'A screen that sells a plan shows what the App Store and '
          'Google Play ask of it:';
      const guard = 'stands behind a guard of the routes that reads '
          '`appPurchases.hasPremium`';
      for (final told in [
        '`${PurchasesRole.controllerFile}`',
        rules,
        'a way to restore purchases',
        'links to the terms of use and the privacy policy',
        'a visible way to close the screen without buying',
        'how to cancel it in the store',
        guard,
        'in debug mode the app prints that hint once',
      ]) {
        expect(section, contains(told));
      }
      expect(section.toLowerCase(), isNot(contains('entitlement')));
    });

    test('tells whose the purchases are, with sign-in or without it', () async {
      const toUser = 'The purchases belong to the user of `appSession`';
      const toInstallation =
          'The purchases belong to this installation of the app.';

      final withAuth = await sectionWith({authRole});
      expect(withAuth, contains(toUser));
      expect(
        withAuth,
        allOf(
          contains('keeps the purchase in the new account'),
          contains('leaves the purchases with the user of this device until '
              'restoring them'),
          contains('never gets the purchases of a user who signed out'),
        ),
      );
      expect(withAuth, isNot(contains(toInstallation)));
      final without = await sectionWith(const {});
      expect(without, contains(toInstallation));
      expect(without, isNot(contains('appSession')));
    });

    test(
        'tells where the user restores purchases, with a settings screen or '
        'without it', () async {
      const entry = 'The entry `RestorePurchasesSetting` of the settings '
          'screen';
      const noSettings = 'This app has no settings screen, so the screen '
          'that sells has to offer the restore itself.';

      final settings = await sectionWith({settingsScreenRole});
      expect(settings, contains(entry));
      expect(settings, contains('`${PurchasesRole.settingFile}`'));
      expect(settings, isNot(contains(noSettings)));
      final without = await sectionWith(const {});
      expect(without, contains(noSettings));
      expect(without, isNot(contains(PurchasesRole.settingFile)));
    });
  });

  group('the rules of the purchases role', () {
    const providerFile = 'lib/core/purchases/store_purchases_service.dart';
    const screen = 'lib/features/paywall/paywall_screen.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_purchases'));
    const ofFeature = ModuleOrigin(ModuleId('paywall'));
    const hint = 'Buy and restore through appPurchases of '
        'lib/core/purchases/app_purchases.dart, which also exports the types '
        'of its answers.';

    test(
        'let each provider contribute one implementation, and no module put '
        'code into the socket of the implementation', () {
      List<SmfIssue> issuesOf(
        ModuleDescriptor module, {
        List<RoleImplementation> implementations = const [],
        List<Contribution> contributions = const [],
      }) =>
          purchasesRole.checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  for (final implementation in implementations)
                    purchasesRole
                        .data(implementation)
                        .withOrigin(ModuleOrigin(module.id)),
                ],
                presentRoles: {purchasesRole},
                context: testContext,
              ),
              module: module,
              contributions: contributions,
            ),
          );
      final implementation = _implementation(async: false);

      expect(issuesOf(_provider, implementations: [implementation]), isEmpty);
      expect(issuesOf(_feature), isEmpty);
      expect(
        issuesOf(_provider).single.message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        issuesOf(_feature, implementations: [implementation]).single.message,
        contains('which only its providers do'),
      );
      final issue = issuesOf(
        _provider,
        implementations: [implementation],
        contributions: const [
          SocketContribution.code(
            PurchasesRole.implementations,
            Fragment('late PurchasesService _purchasesService;'),
          ),
        ],
      ).single;
      expect(issue.message, contains('socket purchases.implementations'));
    });

    test(
        'purchases.factory_calls: a file of a module, or of the template of '
        'another role, that calls createPurchasesService() is reported, '
        'with appPurchases as what to use', () {
      final issues = _structureIssues({
        _calling(providerFile, 'createPurchasesService'): ofProvider,
        _calling(screen, 'createPurchasesService'): ofFeature,
        _calling('lib/core/shop/shop.dart', 'createPurchasesService'):
            RoleTemplateOrigin(_otherRole),
        // Another file of the template of the role itself, and files that
        // neither a module nor the template of a role owns.
        _calling('lib/core/purchases/more.dart', 'createPurchasesService'):
            const RoleTemplateOrigin(purchasesRole),
        _calling('lib/generated.dart', 'createPurchasesService'):
            const PipelineOrigin(),
        _calling('lib/mine.dart', 'createPurchasesService'): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          ('lib/core/shop/shop.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls createPurchasesService(), which no module may '
          'call.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'purchases.factory_calls: only the files of the implementation of '
        'the provider import the file of PurchasesService; any other file of '
        'a module, a widget of the provider too, is reported', () {
      const widget = DartFileIndex(
        path: 'lib/core/purchases/store_button.dart',
        imports: [IndexedImport('purchases_service.dart')],
      );
      const prefixed = DartFileIndex(
        path: screen,
        imports: [
          IndexedImport(
            'package:my_app/core/purchases/purchases_service.dart',
            prefix: 'purchases',
          ),
        ],
      );
      const exporting = DartFileIndex(
        path: 'lib/core/shop/shop.dart',
        exports: [IndexedImport('../purchases/purchases_service.dart')],
      );
      const ofClass = DartFileIndex(
        path: providerFile,
        imports: [IndexedImport('purchases_service.dart')],
      );

      final issues = _structureIssues({
        widget: ofProvider,
        prefixed: ofFeature,
        exporting: RoleTemplateOrigin(_otherRole),
        // The file of the class of the implementation, and that of its
        // function, which the helper adds, may.
        ofClass: ofProvider,
      });

      expect(
        [for (final issue in issues) issue.path],
        [widget.path, screen, 'lib/core/shop/shop.dart'],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} imports ${PurchasesRole.serviceFile}, the file of '
          'PurchasesService, which only the files of the implementation of '
          'the provider of the purchases role import.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'purchases.start_calls: only bootstrap() calls initPurchases(), and '
        'no module calls appPurchases.start()', () {
      const startHint = 'The role starts the purchases in bootstrap(), '
          'before the first frame. Read the access of the user from '
          'appPurchases.';
      const starting = DartFileIndex(
        path: screen,
        imports: [
          IndexedImport('package:my_app/core/purchases/app_purchases.dart'),
        ],
        invocations: [IndexedInvocation('start', target: 'appPurchases')],
      );
      final issues = _structureIssues({
        _calling(AppEntryRole.bootstrapFile, 'initPurchases'): null,
        _calling(providerFile, 'initPurchases'): ofProvider,
        starting: ofFeature,
        // The template of the role starts the controller itself.
        const DartFileIndex(
          path: 'lib/core/purchases/more.dart',
          imports: [IndexedImport('app_purchases.dart')],
          invocations: [IndexedInvocation('start', target: 'appPurchases')],
        ): const RoleTemplateOrigin(purchasesRole),
      });

      expect(
        [for (final issue in issues) (issue.message, issue.hint)],
        [
          (
            '$providerFile calls initPurchases(), which only bootstrap() '
                'calls.',
            startHint,
          ),
          (
            '$screen calls appPurchases.start(), which only initPurchases() '
                'calls.',
            startHint,
          ),
        ],
      );
    });

    test(
        'purchases.implementation_factories: the function of the '
        'implementation is in its file and takes no arguments', () {
      final missing = purchasesRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [
              dataOf(
                purchasesRole,
                _implementation(async: false),
                module: 'fake_purchases',
              ),
            ],
            presentRoles: {purchasesRole},
            context: testContext,
          ),
          files: const {
            'lib/fakes/fake_purchases.dart':
                DartFileIndex(path: 'lib/fakes/fake_purchases.dart'),
          },
        ),
      );
      expect(
        missing.single.message,
        contains('does not declare function createFakePurchases()'),
      );
    });
  });
}
