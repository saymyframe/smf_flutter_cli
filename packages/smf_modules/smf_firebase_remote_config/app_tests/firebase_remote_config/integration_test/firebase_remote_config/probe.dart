// The probe of the firebase_remote_config module, which the start check runs
// on a device once the first screen of the app settled: the only place
// where the platform side of the plugin is the Firebase SDK. The service of
// remote config of the app fetches the values of the Firebase project of the
// build within 5 seconds. A fetch that fails, or that takes longer, is a
// problem, with the error of Firebase, such as a Firebase Remote Config API
// that the project has not enabled. The probe makes a fetch of its own and
// awaits it: Firebase tells of a fetch that failed in lastFetchStatus on
// Android, but not on iOS, where it stays noFetchYet. It activates nothing,
// so the values of the app stay as they are. It uses no test framework. The
// tests of the module run it too (probe_test.dart and delivery_test.dart).
//
// The probe also starts a check that outlives it and the start check, once
// in a run of the app: whether a value that the Firebase project publishes
// while the app runs becomes active in the app (checkDelivery). Only a
// server with a key of the project can publish one, and the value may take
// longer than the minute that the probes share, so the check asks the
// script of CI that started the app, .github/scripts/start_app.sh of the
// repository of SMF, to answer once the start check passed. It writes a
// request, smf_start_request_firebase_remote_config, into the temporary
// directory of the app: the name of a parameter of the check, and the value
// to publish. The script copies the request, runs the command that it was
// given for firebase_remote_config, a test of the module that publishes the
// value with the key of a service account, and then waits for the verdict
// that the check writes into smf_start_report_firebase_remote_config there:
// `passed`, or `failed: ` and the problem. The check sees the value with
// getValue() of Firebase, which changes only once the app activated the
// value: so `passed` shows the whole way, from the publish through the
// real-time updates of Firebase and the service of the app to the
// activation by the controller of the remote config role. The app follows
// the project only while it has a parameter, so in an app without
// parameters the check asks for nothing and writes at once that it cannot
// pass. Each file is written next to its place and renamed, so that it is
// there only whole. Where nothing answers, as in a start without the answer
// or of a release app, whose files the script cannot read, the check writes
// its verdict once its time is up, and nothing reads it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/widgets.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';

/// How long the probe waits for its fetch: the probes of the start check
/// share a minute.
const Duration fetchTimeout = Duration(seconds: 5);

/// The name of the exchange of the check with start_app.sh, in the names of
/// its files and of the answer that the script is given.
const String exchangeName = 'firebase_remote_config';

/// The start of the name of a parameter of the check, which the nonce of the
/// check follows.
const String parameterPrefix = 'remote_config_ci_';

/// How long the check waits for the value once it asked for it: longer than
/// start_app.sh waits for the answer and the verdict, so that the script
/// tells what it waited for when nothing comes.
const Duration valueTimeout = Duration(minutes: 10);

/// How often the check looks at the value of the parameter in the app.
const Duration lookInterval = Duration(seconds: 1);

/// How often the check prints that it still waits for the value, with the
/// state of the app, so that the log of a start whose value does not come
/// tells whether the app was in the foreground.
const Duration reminderInterval = Duration(seconds: 30);

/// The check of a value of remote config that the probe started, if it
/// started one.
Future<String>? _delivery;

/// The probe of the start check: the problems of [problemsOfFetch]. It also
/// starts [checkDelivery] the first time, without waiting for it. It waits
/// for no screen, so it leaves [settle] out.
Future<List<String>> probeFirebaseRemoteConfig(
  Future<void> Function() settle,
) {
  _delivery ??= checkDelivery();
  return problemsOfFetch();
}

/// What is wrong with a fetch of the values of the Firebase project through
/// the service of remote config of the app: nothing when it ends within
/// [timeout], or why it failed or did not end.
Future<List<String>> problemsOfFetch({
  Duration timeout = fetchTimeout,
}) async {
  const needs = 'The Firebase project of the build needs the Firebase Remote '
      'Config API (firebaseremoteconfig.googleapis.com), and the API key of '
      'the app must allow it.';
  try {
    await createRemoteConfigService().fetch().timeout(timeout);
  } on TimeoutException {
    return [
      'A fetch of Firebase Remote Config did not end within $timeout. $needs',
    ];
  } on Object catch (error) {
    return [
      'A fetch of Firebase Remote Config failed: '
          '${'$error'.trim().split('\n').first} $needs',
    ];
  }
  return const [];
}

/// Checks that a value that the Firebase project publishes while the app
/// runs becomes active in the app, with start_app.sh as the server that
/// publishes it: asks for a parameter of its own with a nonce as its value
/// in a request in [directory], looks at the value of the parameter in
/// Firebase every [look], and waits at most [valueWait] for it, printing
/// every [reminder] that it still waits. Then writes its verdict there,
/// `passed` or `failed: ` and the problem, prints it and returns it.
///
/// The [directory] is the temporary directory of the app unless a test
/// gives another.
Future<String> checkDelivery({
  Directory? directory,
  Duration valueWait = valueTimeout,
  Duration look = lookInterval,
  Duration reminder = reminderInterval,
}) async {
  final files = directory ?? Directory.systemTemp;
  String verdict;
  try {
    final problem = await _problemOfDelivery(
      files,
      valueWait,
      look,
      reminder,
    );
    verdict = problem == null ? 'passed' : 'failed: $problem';
  } on Object catch (error) {
    verdict = 'failed: the check threw ${'$error'.trim().split('\n').first}';
  }
  try {
    _write(files, 'smf_start_report_$exchangeName', verdict);
  } on Object catch (error) {
    debugPrint('The check of a value of remote config wrote no verdict: '
        '$error');
  }
  debugPrint('The check of a value of remote config $verdict');
  return verdict;
}

/// What is wrong with the value that the check asks for in [directory], or
/// `null` if it became active in the app.
Future<String?> _problemOfDelivery(
  Directory directory,
  Duration valueWait,
  Duration look,
  Duration reminder,
) async {
  if (RemoteValues.defaults.isEmpty) {
    return 'the app has no parameter of remote config, so it follows no '
        'value that the project publishes, and no value can become active '
        'while it runs';
  }
  final nonce = _nonce();
  final parameter = '$parameterPrefix$nonce';
  final config = FirebaseRemoteConfig.instance;
  final reminders = Timer.periodic(
    reminder,
    (_) => debugPrint(
      'The check of a value of remote config still waits for it, in the '
      'state ${WidgetsBinding.instance.lifecycleState} of the app.',
    ),
  );
  try {
    _write(
      directory,
      'smf_start_request_$exchangeName',
      jsonEncode({'parameter': parameter, 'value': nonce}),
    );
    debugPrint(
      'The check of a value of remote config asked for $parameter, in the '
      'state ${WidgetsBinding.instance.lifecycleState} of the app, and waits '
      'for it.',
    );
    final until = DateTime.now().add(valueWait);
    while (true) {
      final value = config.getValue(parameter);
      if (value.source == ValueSource.valueRemote) {
        final text = value.asString();
        return text == nonce
            ? null
            : 'the parameter that the check asked for became active with '
                'the value "$text" rather than "$nonce"';
      }
      if (!DateTime.now().isBefore(until)) {
        return 'the parameter that the check asked for did not become '
            'active in the app in ${_timeOf(valueWait)}, in the state '
            '${WidgetsBinding.instance.lifecycleState} of the app: the app '
            'makes a value active once Firebase tells of it in real time, '
            'which needs the Firebase Remote Config Realtime API '
            '(firebaseremoteconfigrealtime.googleapis.com) in the project';
      }
      await Future<void>.delayed(look);
    }
  } finally {
    reminders.cancel();
  }
}

/// Writes [text] as one line into the file [name] in [directory], next to
/// it first and then renamed, so that the file is there only whole.
void _write(Directory directory, String name, String text) {
  final file = File('${directory.path}/$name');
  File('${file.path}.part')
    ..writeAsStringSync('$text\n', flush: true)
    ..renameSync(file.path);
}

/// A nonce that no other run of the check has: 16 random bytes in hex.
String _nonce() {
  final random = Random.secure();
  return [
    for (var byte = 0; byte < 16; byte++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// [duration] in seconds, or in milliseconds if it is not a whole second.
String _timeOf(Duration duration) => duration.inMilliseconds % 1000 == 0
    ? '${duration.inSeconds} s'
    : '${duration.inMilliseconds} ms';
