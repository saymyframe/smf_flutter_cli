import 'dart:convert';
import 'dart:io';

import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';

/// Prints, on one line of JSON, what CI needs to know of the FlutterFire
/// CLI from the module: `version`, the version of flutterfire_cli that the
/// module activates on the machine of a user ([flutterfireVersion]), and
/// `check`, the name of its check of the machine as `smf create --explain`
/// shows it ([FlutterfireCliCheck.description]), which names the versions
/// that the check accepts:
/// `{"version":"1.4.1","check":"FlutterFire CLI 1.4.1 or a later 1.x"}`.
///
/// CI activates that version for the apps that it configures with
/// Firebase, and finds that check in what `smf create --explain` says, so
/// that it tests the version that the module activates, whichever it is.
void main() {
  stdout.writeln(
    jsonEncode({
      'version': flutterfireVersion,
      'check': const FlutterfireCliCheck().description,
    }),
  );
}
