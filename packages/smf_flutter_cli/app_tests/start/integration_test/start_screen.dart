// What the start check of the app (start_check.dart, next to this file)
// makes of the first screen of the app once it settled. It is in a file of
// its own, so that a widget test of the CLI (its app test start_screen)
// checks it on screens that the test shows itself, without starting an app.
import 'package:flutter/widgets.dart';
import 'package:{{app_name}}/core/app/failed_start.dart';

/// The problems of the first screen of the app under [root], once it
/// settled, followed by those that [probes] find, which go through the app
/// from that screen on.
///
/// The app has a [WidgetsApp], which MaterialApp and CupertinoApp build,
/// and no [ErrorWidget] is on the screen. When bootstrap() threw, main() of
/// the app shows the screen of a failed start of the app entry role
/// ([FailedStartApp]) in place of the app: that is a problem, with the
/// first line of the error. The app then has none of what its start-up sets
/// up, so a probe would only fail for what hides the cause, and [probes] do
/// not run. The error and its stack trace go to the log of the device with
/// [debugPrint] instead, where a release app, whose screen shows neither,
/// keeps them.
Future<List<String>> problemsOfFirstScreen(
  Element? root, {
  required Future<List<String>> Function() probes,
}) async {
  var widgetsApps = 0;
  final errors = <String>[];
  FailedStartApp? failedStart;
  void visit(Element element) {
    switch (element.widget) {
      case final FailedStartApp app:
        failedStart ??= app;
      case WidgetsApp():
        widgetsApps++;
      case ErrorWidget(:final message):
        errors.add(_firstLine(message));
    }
    element.visitChildren(visit);
  }

  if (root != null) visit(root);
  final problems = [
    if (failedStart case final failed?)
      'the start-up failed: ${_firstLine(failed.error)}',
    if (widgetsApps == 0) 'the screen has no WidgetsApp',
    for (final error in errors) 'the screen shows an ErrorWidget: $error',
  ];
  if (failedStart case final failed?) {
    debugPrint('bootstrap() threw ${failed.error}\n${failed.stackTrace}');
    return problems;
  }
  return [...problems, ...await probes()];
}

/// The first line of the text of [error].
String _firstLine(Object error) => '$error'.trim().split('\n').first;
