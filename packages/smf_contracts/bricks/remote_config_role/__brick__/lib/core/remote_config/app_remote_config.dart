import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'remote_config_service.dart';
import 'remote_values.dart';

export 'remote_values.dart';

/// The values of remote config of the app: `appRemoteConfig.value` has a
/// getter for each parameter of the app.
///
/// It tells its listeners when the value of a parameter changes. A widget
/// follows it with a `ValueListenableBuilder`, and code that must not change
/// on the screen reads it once, such as in `initState`.
final appRemoteConfig = AppRemoteConfigController._();

/// Keeps the values of remote config of the app up to date with the service
/// of the provider of remote config. The app has one, [appRemoteConfig].
///
/// The values never hold the start of the app: [start] makes active what
/// the last fetch got, which the device keeps, and waits for that at most
/// [startWait]. In an app with parameters, the controller then asks the
/// backend for new values in the background, in a later turn of the event
/// loop, and again each time the user comes back to the app, and makes them
/// active at once. Where the service tells of values that the backend
/// publishes while the app runs, the controller makes each active as it
/// comes. While the app has no parameter, it asks the backend nothing and
/// listens to nothing.
///
/// The calls of the service run one after another, and the controller drops
/// those of a service that it no longer has. An error of the service keeps
/// the values, reaches no handler of the uncaught errors of the app, and
/// prints in a debug build. So does a value that the type of its parameter
/// does not take, once, and the parameter reads its default.
///
/// It tells its listeners of a change only when the values of the
/// parameters of the app change: from the completion of a call of the
/// service, from the values that the service tells of, and from [start],
/// which takes the defaults back. Never while a widget builds.
final class AppRemoteConfigController extends ChangeNotifier
    implements ValueListenable<RemoteValues> {
  AppRemoteConfigController._();

  /// How long [start] waits at most for the values that the device kept.
  static const startWait = Duration(seconds: 1);

  /// How often the service may ask the backend at most, also across
  /// launches of the app: every 12 hours in a release build, which keeps the
  /// app within the quotas of a backend, and at each fetch in a debug build,
  /// so that a value that a developer changed shows at the next start.
  static const fetchInterval = kDebugMode ? Duration.zero : Duration(hours: 12);

  /// How long a fetch may take.
  static const fetchTimeout = Duration(seconds: 10);

  /// How much longer than [fetchTimeout] the controller waits for a fetch of
  /// a provider that does not stop, before it goes on with the other calls
  /// of the service.
  static const fetchGrace = Duration(seconds: 5);

  /// Whether the app has a parameter: an app without one asks the backend
  /// nothing.
  static bool get _asks => RemoteValues.defaults.isNotEmpty;

  RemoteValues _values = RemoteValues.initial;

  /// What the controller does with the service of the last start, if any.
  _Run? _run;

  /// Tells when the user comes back to the app.
  _ResumeObserver? _observer;

  /// The values of parameters that their types do not take, which the
  /// controller printed.
  final Set<String> _printed = {};

  /// The values of the parameters of the app.
  @override
  RemoteValues get value => _values;

  /// Starts with [service]: opens it, makes active what the last fetch got,
  /// which the device keeps, and takes those values. In an app with
  /// parameters, it then fetches new values in the background, in a later
  /// turn of the event loop, and follows those that the service tells of.
  ///
  /// `initRemoteConfig()` calls it in `bootstrap()`. It waits at most
  /// [startWait]: values that come later still become [value], and the app
  /// starts without waiting for them.
  ///
  /// It may be called again, with the service that the app has from then
  /// on: `initRemoteConfig()` does so in a test of the next launch of the
  /// app, and a test gives it a service of its own. The controller then drops
  /// the calls of the service before, and [value] has the defaults until the
  /// new service gives its values.
  Future<void> start(RemoteConfigService service) {
    unawaited(_run?.updates?.cancel());
    final run = _run = _Run(service);
    _set(RemoteValues.initial);
    if (_observer == null) {
      final observer = _observer = _ResumeObserver(_onResume);
      WidgetsBinding.instance.addObserver(observer);
    }
    final ready = _inTurn(run, () => _open(run));
    // In a later turn of the event loop, so that the code that runs right
    // after the start reads what the start made active, and the first frame
    // does not wait for the backend.
    if (_asks) unawaited(ready.then((_) => Timer.run(() => _follow(run))));
    return ready.timeout(startWait, onTimeout: () {});
  }

  /// Opens the service of [run], and makes active what the device kept.
  Future<void> _open(_Run run) async {
    await run.service.open(
      RemoteValues.defaults,
      fetchInterval: fetchInterval,
      fetchTimeout: fetchTimeout,
    );
    run.opened = true;
    await _activate(run);
  }

  /// Follows the backend with the service of [run], once it opened: listens
  /// to the values that the service tells of, if it tells of any, and
  /// fetches. It runs in a turn of the event loop of its own, where no call
  /// awaits it, so an error of the service that it meets is printed as any
  /// other, and the fetch still comes.
  void _follow(_Run run) {
    if (!identical(run, _run) || !run.opened) return;
    final service = run.service;
    try {
      if (service.liveUpdates) {
        run.updates = service.updates.listen(
          (_) => _activateLater(run),
          onError: (Object error) => _report(error),
        );
      }
    } on Object catch (error) {
      _report(error);
    }
    _fetchLater(run);
  }

  /// The user came back to the app: in an app with parameters, the
  /// controller fetches again, which the provider throttles to
  /// [fetchInterval].
  void _onResume() {
    final run = _run;
    if (run != null && _asks && run.opened) _fetchLater(run);
  }

  /// Fetches with the service of [run] in its turn and makes what it got
  /// active, unless a fetch waits for its turn already.
  void _fetchLater(_Run run) {
    if (run.fetchWaits) return;
    run.fetchWaits = true;
    unawaited(
      _inTurn(run, () async {
        run.fetchWaits = false;
        await run.service.fetch().timeout(fetchTimeout + fetchGrace);
        await _activate(run);
      }),
    );
  }

  /// Makes active in its turn what the service of [run] told of, unless an
  /// activation waits for its turn already.
  void _activateLater(_Run run) {
    if (run.activationWaits) return;
    run.activationWaits = true;
    unawaited(
      _inTurn(run, () {
        run.activationWaits = false;
        return _activate(run);
      }),
    );
  }

  /// Makes active what the last fetch of the service of [run] got, and takes
  /// the active values, while the controller has that service.
  Future<void> _activate(_Run run) async {
    if (!identical(run, _run)) return;
    await run.service.activate();
    if (identical(run, _run)) {
      _set(RemoteValues.of(run.service.values, onInvalid: _printInvalid));
    }
  }

  /// Runs [job] once the calls of [run] made before it are over, unless the
  /// controller has another service by then. An error of [job] keeps the
  /// values.
  Future<void> _inTurn(_Run run, Future<void> Function() job) async {
    final earlier = run.last;
    final done = Completer<void>();
    final own = run.last = done.future;
    try {
      if (earlier != null) await earlier;
      if (identical(run, _run)) await job();
    } on Object catch (error) {
      _report(error);
    } finally {
      if (identical(run.last, own)) run.last = null;
      done.complete();
    }
  }

  /// Takes [values] as [value], and tells the listeners when that changes
  /// it.
  void _set(RemoteValues values) {
    if (values == _values) return;
    _values = values;
    notifyListeners();
  }

  /// Prints [error] of the service in a debug build, which no caller sees.
  void _report(Object error) {
    if (kDebugMode) {
      debugPrint('Remote config keeps its values; its service failed: $error');
    }
  }

  /// Prints once in a debug build that [text], the value that the backend
  /// gives [parameter], is not of the type of the parameter.
  void _printInvalid(String parameter, String text) {
    if (!kDebugMode || !_printed.add('$parameter=$text')) return;
    final type = switch (RemoteValues.defaults[parameter]) {
      bool() => 'bool',
      int() => 'int',
      double() => 'double',
      _ => 'String',
    };
    debugPrint(
      'Remote config gives $parameter the value "$text", which is no $type, '
      'so the app reads its default.',
    );
  }
}

/// What the controller does with the service of one start: the calls of the
/// service run one after another, and those of a service that the
/// controller no longer has are dropped.
final class _Run {
  _Run(this.service);

  final RemoteConfigService service;

  /// The call that was made last, while a call is on its way: the next one
  /// waits for it.
  Future<void>? last;

  /// Whether the service opened.
  bool opened = false;

  /// Whether a fetch waits for its turn, so that a return to the app
  /// meanwhile needs no other.
  bool fetchWaits = false;

  /// Whether an activation of what the service told of waits for its turn.
  bool activationWaits = false;

  /// The values that the service tells of, while the controller follows
  /// them.
  StreamSubscription<void>? updates;
}

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

/// Returns the service of the provider of remote config, which
/// [initRemoteConfig] created: `bootstrap()` awaits it before the first
/// frame, and there is none to return before that.
///
/// The code of the app does not call it: it reads the values from
/// [appRemoteConfig].
RemoteConfigService createRemoteConfigService() => _remoteConfigService;

{{{smf_remote_config__implementations}}}
