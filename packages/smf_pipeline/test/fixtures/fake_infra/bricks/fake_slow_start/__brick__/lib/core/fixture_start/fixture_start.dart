import 'dart:async';

import 'package:flutter/widgets.dart';

/// What the start-up of the fixture does, as the start-up of a real app
/// may: it waits for a timer, as it would wait for a service that takes a
/// moment to answer; it leaves a timer running, as a refresh that it
/// schedules; and it shows the errors of a build with a widget of its own.
Future<void> startFixture() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  Timer(const Duration(seconds: 1), () {});
  ErrorWidget.builder = (details) =>
      ErrorWidget.withDetails(message: details.exceptionAsString());
}
