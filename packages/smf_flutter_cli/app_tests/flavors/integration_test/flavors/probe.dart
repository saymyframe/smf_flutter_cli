// The probe of the flavor of the app, whichever module provides the app
// entry, which the start check runs on a device once the first screen of the
// app settled, and whose check the test of the role runs too
// (default_flavor_test.dart): the app has the flavor that its build asked
// for.
//
// A build of the start of the app that names a flavor tells the probe so with
// a value of the build, as the release start of CI does. A build that names
// none, as the debug start of CI does, has the default flavor of the app, so
// the probe shows on each device what a command without --flavor builds.
//
// It only reads. The id and the name of the app on the device are native, so
// no running app shows them: the app entry role checks them in the projects.
import 'package:flutter/services.dart';

/// The flavor that the build of the app asked for.
const askedFlavor = String.fromEnvironment(
  '{{flavor_define}}',
  defaultValue: '{{default_flavor}}',
);

/// The probe of the start check: the problems of [problemsOfFlavor] with the
/// flavor of the app. It waits for no screen, so it leaves [settle] out.
Future<List<String>> probeFlavor(Future<void> Function() settle) async =>
    problemsOfFlavor(appFlavor, askedFlavor);

/// What is wrong with [flavor], the flavor of a running app, when its build
/// asked for [asked].
List<String> problemsOfFlavor(String? flavor, String asked) => [
      if (flavor != asked)
        'The app has the flavor $flavor, where its build asked for $asked.',
    ];
