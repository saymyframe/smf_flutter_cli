// What the start check of the app (start_check.dart, next to this file)
// makes of the first screen of the app once it settled. It is in a file of
// its own, so that a widget test of the CLI (its app test start_screen)
// checks it on screens that the test shows itself, without starting an app.
import 'package:flutter/widgets.dart';

/// The problems of the first screen of the app under [root], once it
/// settled, followed by those that [probes] find, which go through the app
/// from that screen on.
///
/// The app has a [WidgetsApp], which MaterialApp and CupertinoApp build,
/// and no [ErrorWidget] is on the screen.
Future<List<String>> problemsOfFirstScreen(
  Element? root, {
  required Future<List<String>> Function() probes,
}) async {
  var widgetsApps = 0;
  final errors = <String>[];
  void visit(Element element) {
    switch (element.widget) {
      case WidgetsApp():
        widgetsApps++;
      case ErrorWidget(:final message):
        errors.add(_firstLine(message));
    }
    element.visitChildren(visit);
  }

  if (root != null) visit(root);
  return [
    if (widgetsApps == 0) 'the screen has no WidgetsApp',
    for (final error in errors) 'the screen shows an ErrorWidget: $error',
    ...await probes(),
  ];
}

/// The first line of the text of [error].
String _firstLine(Object error) => '$error'.trim().split('\n').first;
