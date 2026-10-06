// What the tests of the home module share, in the apps with the module:
// the name of the app as the module writes it, with its symbol and its
// number in the cell of the card, the steps of the screen, the start of the
// app with main() of lib/main.dart, which the app entry role puts into
// every app, the way to the screen through the navigation of the router
// role, whichever screen the app starts on, and a new screen over the app,
// for what a screen does when it is first shown.
//
// The matrix writes texts.dart next to this file: the texts of the screen
// in each language of the app. It sets up the mocks of the platform side of
// every module of the app before the tests of each test file
// (flutter_test_config.dart), so the start-up runs whatever other modules
// the app has, and a guard of the routes of another module is open.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/home/home_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'texts.dart';

/// The words of the name of the package of the app, such as `my` and `app`
/// for `my_app`.
final List<String> _words = '{{app_name}}'.split('_');

/// The name of the app as the module writes it: the name of its package
/// in title case, such as `My App` for `my_app`.
final String appName = _words
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

/// The symbol of the app in the cell of the card: the first letter of its
/// name in upper case, and then the first letter of its second word, or the
/// second letter of a name of one word, such as `Ma` for `my_app`.
final String appSymbol = () {
  final next = _words.length > 1 ? _words[1] : _words.first.substring(1);
  return '${_words.first[0].toUpperCase()}${next.isEmpty ? '' : next[0]}';
}();

/// The number in the cell of the card: how many letters and digits the name
/// of the app has, 5 for `my_app`.
final String appNumber = '${_words.join().length}';

/// The image of the mark of Say My Frame among the assets of the app.
const markAsset = 'lib/features/home/assets/smf_mark.png';

/// The steps of the screen, in their order: the names of the title and of
/// the text of each among the texts of the module, and the path or the
/// address that it is about, which a tap copies.
const steps = [
  (
    title: 'stepScreenTitle',
    text: 'stepScreenText',
    code: 'lib/features/home/home_screen.dart',
  ),
  (title: 'stepFeatureTitle', text: 'stepFeatureText', code: 'lib/features/'),
  (title: 'stepDocsTitle', text: 'stepDocsText', code: 'doc.saymyframe.com'),
];

/// The names of the greetings of the screen among the texts of the module,
/// each with the first and the last hour of the day that it greets at.
const greetings = [
  (name: 'greetingMorning', hours: (0, 11)),
  (name: 'greetingAfternoon', hours: (12, 17)),
  (name: 'greetingEvening', hours: (18, 23)),
];

/// The screen of the module that the user sees.
final Finder home = find.byType(HomeScreen);

/// What the screen of the module shows of [matching].
Finder shown(Finder matching) => find.descendant(of: home, matching: matching);

/// The texts of the screen in the language that the device asks for (see
/// [useLanguage]), each by its name in the module.
Map<String, String> texts = homeTexts.values.first;

/// The text of the screen with the name [name], on the screen.
Finder text(String name) => shown(find.text(texts[name]!));

/// Has the device ask for [language], a language of the app, which the app
/// follows while its user chose none.
Future<void> useLanguage(WidgetTester tester, String language) async {
  tester.platformDispatcher.localesTestValue = [Locale(language)];
  texts = homeTexts[language]!;
  await tester.pumpAndSettle();
}

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as a timer or the platform side of a module,
/// does not keep the fake time of the test waiting forever. An error of
/// [action] fails the test, which tester.runAsync would only report to the
/// handler of the errors of Flutter.
Future<void> inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// Starts the app as on a device, with what its main() puts around it,
/// waits for its first screen and goes to the screen of the module.
///
/// main() runs in real time, as the start-up of a module may wait for a
/// timer or for input and output. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the
/// widget of an error go back to those of the test once main() returns.
///
/// The app may start on another screen, so the test goes to the route of
/// the module from the navigator of the page that the user sees, as code
/// of the app does.
Future<void> startAtHome(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await inRealTime(tester, 'main()', app.main);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  await tester.pumpAndSettle();
  appRouter
      .navigatorOf(tester.element(find.byType(Navigator).last))
      .go(const HomeHomeLocation());
  await tester.pumpAndSettle();
  expect(
    home,
    findsOneWidget,
    reason: 'The route of the module shows its screen.',
  );
}

/// Shows a new screen of the module over the app, at once, and returns
/// before its first frame: what a screen does when it is first shown, such
/// as its entrance, is that of this one. It greets by the time that [now]
/// tells, or by the time of the machine, and is in a theme of [brightness],
/// or in the theme of the app.
///
/// The screen goes on top of the navigator at the root of the app, so it
/// has the theme and the texts of the app, and covers the screen of the
/// route of the module, which [home] then leaves out. [closeNewHome]
/// closes it.
void showNewHome(
  WidgetTester tester, {
  DateTime Function()? now,
  Brightness? brightness,
}) {
  final screen = now == null ? const HomeScreen() : HomeScreen(now: now);
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push<void>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          brightness == null
              ? screen
              : Theme(data: ThemeData(brightness: brightness), child: screen),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

/// Closes the screen that [showNewHome] showed.
Future<void> closeNewHome(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();
}

/// The deep green of Say My Frame, the colour of the card of the screen.
const brandGreen = Color(0xFF0F3326);

/// The card that tells that the app is ready: the box in the deep green of
/// Say My Frame around its title.
Finder card() => find.ancestor(
      of: text('readyTitle'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            switch (widget.decoration) {
              BoxDecoration(:final color) => color == brandGreen,
              _ => false,
            },
      ),
    );

/// The cells that the card of the screen draws next to the cell of the app:
/// what paints them.
Finder cells() =>
    find.descendant(of: card(), matching: find.byType(CustomPaint));

/// How far each part of the screen has come in, from 0 for a part that is
/// not shown yet to 1 for one that is there.
List<double> entrance(WidgetTester tester) => [
      for (final part in tester.widgetList<Opacity>(
        shown(find.byType(Opacity)),
      ))
        part.opacity,
    ];

/// Records what the app copies, as the platform gets it, and returns the
/// list that each copy goes to.
List<String> recordCopies(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied
            .add((call.arguments as Map<Object?, Object?>)['text']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}
