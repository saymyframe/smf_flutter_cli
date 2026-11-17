// What the tests of the email_feedback module share, in the apps with the
// module: the start of the app with main() of lib/main.dart, which the app
// entry role puts into every app, a context below the root of the app in
// the language that the device asks for, what a call completed with within
// two seconds of frames, what reached the handlers of the errors, the parts
// of a link of a mail, and the sheet with the address.
//
// The start-up of an app runs once in a test file, so each file of the tests
// has one test. The matrix sets up the mocks of the platform side of every
// module of the app before the tests of each test file
// (flutter_test_config.dart), and writes of_app.dart next to this file: the
// texts of the module in each language of the app.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'of_app.dart';

/// A widget test fails after ten minutes by default; a test that hangs
/// fails sooner.
const timeout = Timeout(Duration(minutes: 3));

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, as the start-up of a module may wait for a
/// timer or for input and output. An error of main() fails the test. The
/// handlers of errors that the start-up installs and the builder of the
/// widget of an error go back to those of the test once main() returns.
Future<void> startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  Object? error;
  StackTrace? stackTrace;
  try {
    await tester.runAsync(() async {
      try {
        await app.main();
      } on Object catch (thrown, stack) {
        error = thrown;
        stackTrace = stack;
      }
    });
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  if (error != null) fail('main() threw $error\n$stackTrace');
  await tester.pumpAndSettle();
}

/// Has the device ask for the language [code], one of the languages of the
/// app, which the app is in then, as each text of the module in it.
Future<void> useLanguage(WidgetTester tester, String code) async {
  tester.platformDispatcher.localesTestValue = [Locale(code)];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpAndSettle();
}

/// The navigator at the root of the app, which shows its screens.
NavigatorState rootNavigatorOf(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// The key of the content of the page that [contextBelowRoot] shows.
const _pageKey = ValueKey('email_feedback page of the test');

/// Shows a page of the test over the app, on top of the navigator at the
/// root of the app, and returns a context in it: a context below the root of
/// the app, with the texts of the app, as that of a button on a screen of the
/// app is. With [theme], the page has that theme, which a sheet that it
/// opens takes too. With [nested], the context is on a page of a navigator
/// of its own inside that page, as that of a screen in a tab of the main
/// navigation is. [closeTestPage] closes it.
Future<BuildContext> contextBelowRoot(
  WidgetTester tester, {
  ThemeData? theme,
  bool nested = false,
}) async {
  unawaited(
    rootNavigatorOf(tester).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          const content = ColoredBox(
            key: _pageKey,
            color: Color(0xFFFFFFFF),
            child: SizedBox.expand(),
          );
          final Widget page = nested
              ? Navigator(
                  onGenerateRoute: (settings) => PageRouteBuilder<void>(
                    settings: settings,
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        content,
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                )
              : content;
          return theme == null ? page : Theme(data: theme, child: page);
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ),
  );
  await tester.pump();
  return tester.element(find.byKey(_pageKey));
}

/// Closes the route on top of the navigator at the root of the app, such as
/// a page that [contextBelowRoot] showed, and waits until it is gone.
Future<void> closeTestPage(WidgetTester tester) async {
  rootNavigatorOf(tester).pop();
  await tester.pumpAndSettle();
}

/// What [call] completes with, or the error that it fails with, once frames
/// of a tenth of a second each let it complete, two seconds of them at
/// most, rather than once the screen settled. Both are `null` if it did not
/// complete by then.
Future<({bool? answer, Object? error})> answerWithin(
  WidgetTester tester,
  Future<bool> call,
) async {
  bool? answer;
  Object? error;
  var done = false;
  unawaited(
    call.then(
      (value) {
        answer = value;
        done = true;
      },
      onError: (Object thrown) {
        error = thrown;
        done = true;
      },
    ),
  );
  for (var frame = 0; frame < 20 && !done; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (answer: answer, error: error);
}

/// The errors that reached the handler of the errors of Flutter and the
/// handler of the uncaught errors of the platform while [action] ran, each
/// as its text.
Future<({List<String> flutter, List<String> platform})> errorsWhile(
  Future<void> Function() action,
) async {
  final flutter = <String>[];
  final platform = <String>[];
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  FlutterError.onError = (details) => flutter.add('${details.exception}');
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    platform.add('$error');
    return true;
  };
  try {
    await action();
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
  }
  return (flutter: flutter, platform: platform);
}

/// The parts of the query of [raw], the text of a link of a mail, each by
/// its name and decoded from its percent escapes alone: a `+` stays a plus,
/// as a mail app shows it.
Map<String, String> partsOf(String raw) {
  final query = raw.substring(raw.indexOf('?') + 1);
  return {
    for (final part in query.split('&'))
      part.substring(0, part.indexOf('=')):
          Uri.decodeComponent(part.substring(part.indexOf('=') + 1)),
  };
}

/// The texts of the module in [language], by their names.
Map<String, String> textsIn(String language) => emailFeedbackTexts[language]!;

/// The sheet with the address, while it shows.
Finder get sheet => find.byType(BottomSheet);

/// [text] where the sheet shows it.
Finder inSheet(String text) =>
    find.descendant(of: sheet, matching: find.text(text));

/// The paragraph in which [shown] draws its text.
RenderParagraph paragraphOf(WidgetTester tester, Finder shown) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: shown,
        matching: find.byType(RichText),
        matchRoot: true,
      ),
    );

/// A letter, a mark that belongs to one, a digit, or a no-break space, which
/// keeps the words around it together: a line that starts between two of
/// them starts inside a word.
final RegExp _joined = RegExp(
  r'[\p{L}\p{M}\p{N}\u00A0\u2007\u202F]',
  unicode: true,
);

/// Checks that [paragraph], which shows [text], keeps its words whole in
/// [language]: no line starts between two letters or digits, or at a
/// no-break space.
void expectWholeWords(
  RenderParagraph paragraph,
  String text, {
  required String language,
}) {
  double? lineOf(int index) => paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: index, extentOffset: index + 1),
      )
      .firstOrNull
      ?.top;
  for (var index = 1; index < text.length; index++) {
    if (!_joined.hasMatch(text[index - 1]) || !_joined.hasMatch(text[index])) {
      continue;
    }
    final (before, after) = (lineOf(index - 1), lineOf(index));
    if (before == null || after == null) continue;
    expect(
      after,
      closeTo(before, 0.5),
      reason: 'On the small phone, "$text" breaks between its words and not '
          'inside one, at ${text.substring(0, index)}|${text.substring(index)}, '
          'in $language.',
    );
  }
}
