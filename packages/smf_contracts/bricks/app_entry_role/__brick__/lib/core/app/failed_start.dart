import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'status_bar_icons.dart';

/// Shows why the app could not start, in place of the splash screen of the
/// system, which would otherwise stay, and reports [error] with its
/// [stackTrace] to the handler of the errors of Flutter.
///
/// `main()` calls it when `bootstrap()` throws, and then returns: the app
/// does not start. The screen comes first, so a handler that throws cannot
/// keep it away. The handlers that the start-up set up before it failed,
/// such as those of crash reporting, hear of the error, and so does a test
/// that runs `main()`.
void showFailedStart(Object error, StackTrace stackTrace) {
  runApp(FailedStartApp(error: error, stackTrace: stackTrace));
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'the start-up of the app',
      context: ErrorDescription('while main() awaited bootstrap()'),
    ),
  );
}

/// The app that runs when the start-up failed: a screen that says so, with
/// [error] and [stackTrace] in a debug build.
///
/// It needs nothing of the start-up: it has neither the theme nor the texts
/// nor the root wrappers of the app, which the start-up sets up, and so its
/// texts are in English. Change them here.
class FailedStartApp extends StatelessWidget {
  /// Creates the app of a start-up that failed with [error] at
  /// [stackTrace].
  const FailedStartApp({
    required this.error,
    required this.stackTrace,
    this.showsError = kDebugMode,
    super.key,
  });

  /// What `bootstrap()` threw.
  final Object error;

  /// Where `bootstrap()` threw [error].
  final StackTrace stackTrace;

  /// Whether the screen shows [error] and [stackTrace]: only in a debug
  /// build, since the message of an error may hold data of the user and
  /// means nothing to a user.
  final bool showsError;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(),
        darkTheme: ThemeData(brightness: Brightness.dark),
        builder: (context, child) => StatusBarIcons(child: child!),
        home: _FailedStartScreen(
          error: error,
          stackTrace: stackTrace,
          showsError: showsError,
        ),
      );
}

class _FailedStartScreen extends StatelessWidget {
  const _FailedStartScreen({
    required this.error,
    required this.stackTrace,
    required this.showsError,
  });

  final Object error;

  final StackTrace stackTrace;

  final bool showsError;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final code = texts.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Courier'],
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Semantics(
              header: true,
              child: Text(
                'The app could not start',
                style: texts.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),
            if (showsError) ...[
              Text(
                'bootstrap() in lib/bootstrap.dart threw:',
                style: texts.bodyLarge,
              ),
              const SizedBox(height: 8),
              SelectableText('$error', style: code),
              const SizedBox(height: 16),
              SelectableText('$stackTrace', style: code),
            ] else
              Text(
                'Close the app and open it again.',
                style: texts.bodyLarge,
              ),
          ],
        ),
      ),
    );
  }
}
