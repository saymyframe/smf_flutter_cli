import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'purchases_service.dart';

export 'purchases_service.dart' hide PurchasesService;

/// The purchases of the app: whether the user has premium access, known
/// before the first frame, the plans that the app sells, and the way to buy
/// and to restore them.
///
/// Its `value` is the [AppAccess] of the user, and it tells its listeners
/// when that changes. A widget follows it with a `ValueListenableBuilder`.
final appPurchases = AppPurchasesController();

/// Keeps the access of the user up to date with the service of the provider
/// of purchases, and buys and restores through that service. The app has
/// one, [appPurchases].
///
/// Every call here fails only with a [PurchasesFailure], whose reason the
/// app shows in a text of its own. An error of another kind becomes a
/// failure with the reason [PurchasesFailureReason.unknown] and the error as
/// its [PurchasesFailure.developerHint].
///
/// The calls run one after another, in the order they were made, and so
/// does what the controller does itself when the user of the app changes or
/// comes back to the app. Before each, the controller identifies the user
/// with the service, unless the service has that user already. So a
/// purchase belongs to the user who made it: a change of the user waits for
/// it.
///
/// An error that no caller sees, of the start, of a change of the user, of
/// the return of the user to the app or of the changes that the service
/// tells of, changes nothing. A failure [PurchasesFailureReason.notConfigured]
/// prints its hint once in debug mode, [PurchasesFailureReason.network] and
/// [PurchasesFailureReason.unavailable] say nothing, and any other error
/// reaches the handlers of the uncaught errors of the app. So the app starts
/// and runs without purchases when the provider is not set up.
final class AppPurchasesController extends ChangeNotifier
    implements ValueListenable<AppAccess> {
  /// Creates a controller. The app creates [appPurchases] and no other. A
  /// test creates one to start it with a service of its own, or with a
  /// shorter [startWait], and disposes of it.
  AppPurchasesController({this.startWait = const Duration(seconds: 3)});

  /// How long [start] waits at most for the access of the user and for the
  /// calls made before it.
  final Duration startWait;

  PurchasesService? _service;
  StreamSubscription<AppAccess>? _accessChanges;
  String? Function()? _userId;
  Listenable? _userChanges;
  AppAccess _access = const NoAccess();
  bool _disposed = false;

  /// The service and the user that the service was last identified with,
  /// or `null` while no identification with the service succeeded.
  _Identity? _identified;

  /// Whether [start] was called.
  bool _starting = false;

  /// Completes when the controller has started for the first time, which a
  /// call made before waits for.
  final Completer<void> _started = Completer<void>();

  /// The call that was made last, while a call is on its way: the next one
  /// waits for it. It is `null` when none is, and a call then awaits
  /// nothing. A future that completed in another zone would hold the call
  /// back in a widget test, where the app starts in real time and the test
  /// goes on in fake time.
  Future<void>? _lastCall;

  /// Whether a look at the user and at the access waits for its turn, so
  /// that the changes and returns that come meanwhile need no other.
  bool _lookWaits = false;

  /// Tells when the user comes back to the app.
  _ResumeObserver? _observer;

  /// The hints of the failures [PurchasesFailureReason.notConfigured] that
  /// the controller printed.
  final Set<String?> _printed = {};

  /// The access of the user.
  @override
  AppAccess get value => _access;

  /// Whether the user has premium access, as a guard of the routes reads it.
  ///
  /// It is computed from [value] each time it is read, and its listeners
  /// are those of the controller. A listener is also called for a change of
  /// [value] that leaves this value as it was, such as a plan that renews.
  late final ValueListenable<bool> hasPremium = _PremiumFlag(this);

  /// Starts with [service]: identifies the user with it, takes the access of
  /// the user, and follows the changes of the access that the service tells
  /// of.
  ///
  /// [userId] returns the id of the user of the app, or `null` for the user
  /// of this device, and [userChanges] tells when it may have changed, such
  /// as the session of an app with sign-in. Without them, the purchases are
  /// those of the user of this device. When the user changes, [value] is
  /// [NoAccess] until the service has the new user, and the controller takes
  /// no change of the access that the service tells of meanwhile.
  ///
  /// `initPurchases()` calls it in `bootstrap()`, so [value] is known before
  /// the first frame. It waits for the access at most [startWait]: an access
  /// that comes later still becomes [value], and the app starts without
  /// waiting for it.
  ///
  /// A call made before the first start waits for it: [plans], [purchase]
  /// and [restore]. Such calls run in their order once the start has the
  /// access, and the future of this start completes after them, and after
  /// the calls that their completions make right away: it completes once no
  /// call is on its way in the microtask after the last one ended. The mocks
  /// of the tests of an app use this: `plans().then(...)` that buys a plan,
  /// made before `bootstrap()`, gives the app premium access before its first
  /// frame. A test makes such a call outside the body of a test, as in a
  /// `setUpAll`: made in the body of a widget test, it waits in the fake time
  /// of that body, and a start that runs in real time never completes.
  ///
  /// It may be called again, with the service that the controller has from
  /// then on: `initPurchases()` does so in a test of the next launch of the
  /// app, and a test gives it a service of its own. Such a start takes its
  /// turn after the calls that are on their way, and [value] is then that of
  /// the new service.
  Future<void> start(
    PurchasesService service, {
    String? Function()? userId,
    Listenable? userChanges,
  }) =>
      _start(service, userId, userChanges)
          .timeout(startWait, onTimeout: () {});

  /// The plans of the current offer of the app, at least one, in the order
  /// of the provider. Show them only to a user without premium access.
  Future<List<Plan>> plans() => _call((service, _) => service.plans());

  /// Buys [plan] through the sheet of the store, and completes with `true`
  /// once the user has bought it, or with `false` when the user cancelled,
  /// which is no failure. [value] is then the access that the purchase gave.
  ///
  /// A payment that waits for an approval fails with
  /// [PurchasesFailureReason.pending]: the access comes once the store took
  /// the payment.
  Future<bool> purchase(Plan plan) => _call((service, identity) async {
        final access = await service.purchase(plan);
        if (access == null) return false;
        _take(identity, access);
        return true;
      });

  /// Gives the user what the store account of the user bought, such as on a
  /// new device, and completes with the access of the user then, which is
  /// [value] from then on.
  Future<AppAccess> restore() => _call((service, identity) async {
        final access = await service.restore();
        _take(identity, access);
        return access;
      });

  /// Stops following the service, the user and the lifecycle of the app. A
  /// call that is on its way still ends as it would have, but tells no
  /// listener.
  @override
  void dispose() {
    _disposed = true;
    unawaited(_accessChanges?.cancel());
    _userChanges?.removeListener(_onUserChange);
    if (_observer case final observer?) {
      WidgetsBinding.instance.removeObserver(observer);
    }
    super.dispose();
  }

  Future<void> _start(
    PurchasesService service,
    String? Function()? userId,
    Listenable? userChanges,
  ) async {
    if (_starting) {
      await _turn(() => _use(service, userId, userChanges));
    } else {
      _starting = true;
      await _use(service, userId, userChanges);
      _started.complete();
    }
    await _settled();
  }

  /// Takes [service] as the service of the controller, with the user of
  /// [userId], and looks at the user and at the access.
  Future<void> _use(
    PurchasesService service,
    String? Function()? userId,
    Listenable? userChanges,
  ) async {
    unawaited(_accessChanges?.cancel());
    _userChanges?.removeListener(_onUserChange);
    _service = service;
    _userId = userId;
    _userChanges = userChanges?..addListener(_onUserChange);
    _identified = null;
    _set(const NoAccess());
    _accessChanges = service.accessChanges.listen(
      (access) => _onAccessChange(service, access),
      onError: _report,
    );
    if (_observer == null) {
      final observer = _observer = _ResumeObserver(_lookLater);
      WidgetsBinding.instance.addObserver(observer);
    }
    await _quietly(_look);
  }

  /// Completes once no call is on its way, and none was made in the
  /// microtask after the last one ended.
  Future<void> _settled() async {
    while (true) {
      final last = _lastCall;
      if (last != null) {
        await last;
        continue;
      }
      await Future<void>.microtask(() {});
      if (_lastCall == null) return;
    }
  }

  /// Runs [call] with the service and the user of the app, once the calls
  /// made before it are over, and turns whatever it throws that is no
  /// [PurchasesFailure] into one.
  Future<T> _call<T>(
    Future<T> Function(PurchasesService service, _Identity identity) call,
  ) =>
      _turn(() async {
        try {
          final service = _service!;
          final before = _identified;
          final identity = await _identify(service);
          // A call that identified the user again, as after an
          // identification that failed, is followed by a look at the access
          // of the user.
          if (identity != before) _lookLater();
          return await call(service, identity);
        } on PurchasesFailure {
          rethrow;
        } on Object catch (error, stackTrace) {
          Error.throwWithStackTrace(
            PurchasesFailure(
              PurchasesFailureReason.unknown,
              developerHint: '$error',
            ),
            stackTrace,
          );
        }
      });

  /// Runs [job] once the calls made before it are over, and not before the
  /// controller has started for the first time.
  Future<T> _turn<T>(Future<T> Function() job) async {
    final earlier =
        _lastCall ?? (_started.isCompleted ? null : _started.future);
    final done = Completer<void>();
    final own = _lastCall = done.future;
    if (earlier != null) await earlier;
    try {
      return await job();
    } finally {
      if (identical(_lastCall, own)) _lastCall = null;
      done.complete();
    }
  }

  /// Identifies the user of the app with [service], unless [service] has
  /// that user already, and returns the identity.
  Future<_Identity> _identify(PurchasesService service) async {
    final user = _userId?.call();
    final identified = _identified;
    if (identified != null &&
        identical(identified.service, service) &&
        identified.user == user) {
      return identified;
    }
    // Until the identification succeeds, the service has no user that the
    // controller knows of, and the user has no access.
    _identified = null;
    _set(const NoAccess());
    await service.identify(user);
    final identity = (service: service, user: user);
    if (identical(service, _service)) _identified = identity;
    return identity;
  }

  /// Identifies the user, and takes the access of that user.
  Future<void> _look() async {
    final service = _service!;
    final identity = await _identify(service);
    _take(identity, await service.access());
  }

  /// Looks at the user and at the access in its turn, unless a look waits
  /// for its turn already.
  void _lookLater() {
    if (_lookWaits || _disposed) return;
    _lookWaits = true;
    unawaited(
      _turn(() {
        _lookWaits = false;
        return _quietly(_look);
      }),
    );
  }

  /// The user of the app may have changed. If it has, [value] is [NoAccess]
  /// until the service has the new user.
  void _onUserChange() {
    final identified = _identified;
    if (identified != null && identified.user == _userId?.call()) return;
    _set(const NoAccess());
    _lookLater();
  }

  /// Takes [access], which [service] told of, while [service] has the user
  /// of the app.
  void _onAccessChange(PurchasesService service, AppAccess access) {
    final identified = _identified;
    if (identified != null && identical(identified.service, service)) {
      _take(identified, access);
    }
  }

  /// Takes [access], the answer of the service of [identity], as [value],
  /// while the controller has that service and the service has the user of
  /// [identity], who is still the user of the app. The answer for a user
  /// who is no longer the user of the app changes nothing.
  void _take(_Identity identity, AppAccess access) {
    final identified = _identified;
    if (identified != null &&
        identical(identified.service, identity.service) &&
        identical(identity.service, _service) &&
        identified.user == identity.user &&
        identity.user == _userId?.call()) {
      _set(access);
    }
  }

  /// Takes [access] as [value], and tells the listeners when that changes
  /// it, unless the controller was disposed of.
  void _set(AppAccess access) {
    if (_disposed || access == _access) return;
    _access = access;
    notifyListeners();
  }

  /// Runs [job], whose errors no caller sees, and reports what it throws.
  Future<void> _quietly(Future<void> Function() job) async {
    try {
      await job();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
    }
  }

  /// Reports [error], which no caller sees.
  void _report(Object error, StackTrace stackTrace) {
    switch (error) {
      case PurchasesFailure(
            reason: PurchasesFailureReason.notConfigured,
            :final developerHint,
          ):
        if (kDebugMode && _printed.add(developerHint)) {
          debugPrint(
            'Purchases are not set up, so the app runs without them: '
            '$developerHint',
          );
        }
      case PurchasesFailure(
          reason: PurchasesFailureReason.network ||
              PurchasesFailureReason.unavailable,
        ):
        break;
      default:
        Zone.current.handleUncaughtError(error, stackTrace);
    }
  }
}

/// A service and the user that it was identified with.
typedef _Identity = ({PurchasesService service, String? user});

/// Calls [_onResume] each time the app is resumed, whatever state it was in
/// before.
final class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResume);

  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}

/// Whether the user of a controller has premium access: its value is
/// computed from the access each time it is read, and its listeners are
/// those of the controller.
final class _PremiumFlag implements ValueListenable<bool> {
  const _PremiumFlag(this._controller);

  final AppPurchasesController _controller;

  @override
  bool get value => _controller.value is PremiumAccess;

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);
}

/// Returns the service of the provider of purchases, which [initPurchases]
/// created: `bootstrap()` awaits it before the first frame, and there is
/// none to return before that.
///
/// The code of the app does not call it: it uses [appPurchases].
PurchasesService createPurchasesService() => _purchasesService;

{{{smf_purchases__implementations}}}
