// What the tests of the setting of analytics collection share: a device
// that answers the platform side of the fixture analytics as the SDK of a
// provider does, which keeps the setting of collection across the starts of
// the app, the start-up of the app, and the start of the fixture analytics
// at the next launch.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';

/// Whether the app collects analytics from its first start, as the analytics
/// role chose: `--analytics-collection` of `smf create`. The matrix fills it
/// from the choice of the role, not from the options that it gave
/// `smf create`, so an app that got none has the first value, true.
final bool collectedFromFirstStart =
    bool.parse('{{collected_from_first_start}}');

/// The platform side of the fixture analytics as a device on which the app
/// never ran: it answers the fixture analytics as the SDK of a provider
/// does, which keeps on the device the setting of collection that the code
/// chose, across the starts of the app.
///
/// It replaces the mocks of the fixture that the matrix set up.
final class FixtureAnalyticsDevice {
  /// Answers the platform side of the fixture analytics from now on.
  FixtureAnalyticsDevice() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fixtureAnalyticsChannel, _answer);
  }

  /// The setting of collection that the device keeps, or `null` while the
  /// code of the app never chose.
  bool? kept;

  /// Whether the device collects what reaches it, as its last start or the
  /// code of the app decided.
  bool collects = false;

  /// The names of the events that the device collected, in order.
  final List<String> collected = [];

  Future<Object?> _answer(MethodCall call) async {
    final arguments = call.arguments as Map<Object?, Object?>?;
    switch (call.method) {
      case 'start':
        // A start takes the default of the app only while the device kept
        // nothing, and an SDK collects when nothing says otherwise.
        collects = kept ?? (arguments?['collectByDefault'] as bool?) ?? true;
      case 'setAnalyticsCollectionEnabled':
        final enabled = arguments!['enabled']! as bool;
        kept = enabled;
        collects = enabled;
      case 'logEvent':
        if (collects) collected.add(arguments!['name']! as String);
    }
    return null;
  }
}

/// Runs the start-up of the app, which starts the analytics services, and
/// then puts back the handlers of the errors and the widget of an error,
/// which it may replace, as the start-up of an app that reports its crashes
/// does: these tests do not look at them.
///
/// Returns the lines that the start-up printed with debugPrint. Fails when
/// the start-up throws.
Future<List<String>> startUp() async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  final printed = <String>[];
  final debugPrintBefore = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) =>
      printed.addAll((message ?? '').split('\n'));
  try {
    await bootstrap();
  } finally {
    debugPrint = debugPrintBefore;
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  return printed;
}

/// Starts the fixture analytics again, as the next launch of the app does:
/// its platform side starts once more on the same device, which kept what
/// the code chose.
Future<void> startAgain() => initFixtureAnalytics();
