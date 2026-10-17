import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/app_session.dart';

/// The issuer of the tokens of the identity provider of the fixture.
const String fixtureIssuer = '{{{issuer}}}';

/// The subject of the identity of the user at the identity provider of the
/// fixture, which every credential of [fixtureCredential] is of.
const String fixtureSubject = 'fixture-identity';

/// The email address of that identity.
const String fixtureEmail = 'identity@sign-in.fixture.example.com';

/// Asks the identity provider of the fixture for a credential, as the sheet
/// of an identity provider does, and returns it a turn of the event loop
/// later: a credential of the one identity of the fixture, each time.
///
/// Its token is a test token, a JSON Web Token without a signature whose
/// payload has the issuer, the subject and the email address of the
/// identity, which a provider of sign-in in the tests of an app takes.
Future<SignInCredential?> fixtureCredential() async {
  await Future<void>.delayed(Duration.zero);
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = part({'alg': 'none', 'typ': 'JWT'});
  final payload = part({
    'iss': fixtureIssuer,
    'sub': fixtureSubject,
    'email': fixtureEmail,
  });
  return IdTokenCredential(issuer: fixtureIssuer, idToken: '$header.$payload.');
}

/// The icon of the button of the way to sign in of the fixture, which takes
/// the colour of its label.
class FixtureSignInIcon extends StatelessWidget {
  /// Creates the icon.
  const FixtureSignInIcon({super.key});

  @override
  Widget build(BuildContext context) => const Icon(Icons.key);
}
