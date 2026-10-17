// A test that continuous integration runs in the apps with the
// apple_sign_in module, whatever else they have: the way to sign in with
// Apple on the real sign_in_with_apple package, over the mocks of its
// platform side (apple_sign_in_mocks.dart), which the matrix sets up before
// the tests of each test file.
//
// On iOS, appleCredential() asks Apple for the email address and the full
// name, with the SHA-256 hash of a new raw nonce each time, and returns the
// ID token of Apple with that raw nonce, the authorization code of the
// request and the name, which only the first sign-in has. A closed sheet
// returns null, the unknown error with which Apple answers an app without
// the capability fails with notConfigured, and any other error with
// unknown. On another platform it fails with notConfigured without asking
// Apple. The app lists the way to sign in on iOS only, and its icon takes
// the colour of the label of its button.
//
// What a provider of the auth role does with the credential is for the
// test of the ways to sign in of the role, auth_methods.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/apple_sign_in/apple_sign_in.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/sign_in_methods.dart';

import '../apple_sign_in_mocks.dart';

/// The claims of [idToken], a JSON Web Token.
Map<String, Object?> _claimsOf(String idToken) {
  final payload = idToken.split('.')[1];
  return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))))
      as Map<String, Object?>;
}

/// What a call of appleCredential() ended with, on [platform]: the
/// credential, null, or the reason and the hint of its failure.
Future<Object?> _credentialOn(TargetPlatform platform) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await appleCredential();
  } on AuthFailure catch (failure) {
    return 'failed: ${failure.reason.name}: ${failure.developerHint}';
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// The credential that appleCredential() returns on iOS, which the test
/// expects to be one.
Future<IdTokenCredential> _credential() async {
  final credential = await _credentialOn(TargetPlatform.iOS);
  if (credential is! IdTokenCredential) {
    fail('appleCredential() returned $credential, not a credential.');
  }
  return credential;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A test fails after ten minutes by default; a test that hangs fails
  // sooner.
  const timeout = Timeout(Duration(minutes: 2));

  test(
    'on iOS, appleCredential() asks Apple for the email address and the '
    'full name with the SHA-256 hash of a new raw nonce, and returns the ID '
    'token of Apple with that raw nonce, the code of the request and the '
    'name, which only the first sign-in has',
    () async {
      final requests = signInWithApple.requests.length;
      final first = await _credential();
      final second = await _credential();
      final asked = signInWithApple.requests.sublist(requests);

      String hashOf(String? rawNonce) =>
          sha256.convert(utf8.encode(rawNonce ?? '')).toString();
      expect(
        [
          for (final request in asked) [request['type'], request['scopes']],
        ],
        [
          [
            'appleid',
            ['email', 'fullName']
          ],
          [
            'appleid',
            ['email', 'fullName']
          ],
        ],
        reason: 'Each sign-in asks Apple for an Apple ID, with the email '
            'address and the full name.',
      );
      expect(
        [for (final request in asked) request['nonce']],
        [hashOf(first.rawNonce), hashOf(second.rawNonce)],
        reason: 'The request has the SHA-256 hash of the raw nonce of its '
            'credential, which Apple writes into its token.',
      );
      expect(
        [
          first.rawNonce != second.rawNonce,
          first.rawNonce?.length,
          second.rawNonce?.length,
        ],
        [true, 32, 32],
        reason: 'Each sign-in has a raw nonce of its own.',
      );
      expect(
        [
          for (final credential in [first, second])
            [
              credential.issuer,
              _claimsOf(credential.idToken)['iss'],
              _claimsOf(credential.idToken)['nonce'],
              credential.authorizationCode,
            ],
        ],
        [
          for (final (index, credential) in [first, second].indexed)
            [
              appleTestIssuer,
              appleTestIssuer,
              hashOf(credential.rawNonce),
              signInWithApple.codes[signInWithApple.codes.length - 2 + index],
            ],
        ],
        reason: 'The credential is the ID token of Apple, with the nonce of '
            'its request, and the authorization code of that request, with '
            'which a provider revokes the tokens of Apple.',
      );
      expect(
        [
          for (final credential in [first, second])
            [credential.givenName, credential.familyName],
        ],
        [
          [appleTestGivenName, appleTestFamilyName],
          [null, null],
        ],
        reason: 'Apple gives the name only the first time that the user '
            'signs in to the app.',
      );
      expect(
        '$first',
        'IdTokenCredential($appleTestIssuer)',
        reason: 'The credential names no token.',
      );
    },
    timeout: timeout,
  );

  test(
    'a closed sheet returns null, the unknown error of Apple fails with '
    'notConfigured, and any other error with unknown',
    () async {
      final outcomes = <String, Object?>{};
      for (final code in const [
        'authorization-error/canceled',
        'authorization-error/unknown',
        'authorization-error/failed',
        'not-supported',
      ]) {
        signInWithApple.failNext(code);
        final outcome = await _credentialOn(TargetPlatform.iOS);
        outcomes[code] = switch (outcome) {
          final String failure => failure.split(': ').take(2).join(': '),
          _ => outcome,
        };
      }

      expect(
        outcomes,
        {
          'authorization-error/canceled': null,
          'authorization-error/unknown': 'failed: notConfigured',
          'authorization-error/failed': 'failed: unknown',
          'not-supported': 'failed: unknown',
        },
        reason: 'Closing the sheet of Apple is no failure. Apple answers an '
            'app without the capability Sign in with Apple with an unknown '
            'error.',
      );
      signInWithApple.failNext('authorization-error/unknown');
      expect(
        await _credentialOn(TargetPlatform.iOS),
        allOf(
          contains('the capability Sign in with Apple'),
          contains('See the section "Sign in with Apple" of the README'),
        ),
        reason: 'The hint of the failure names the capability and the '
            'section of the README of the app on it.',
      );
    },
    timeout: timeout,
  );

  test(
    'on every platform but iOS, appleCredential() fails with notConfigured '
    'without asking Apple',
    () async {
      final requests = signInWithApple.requests.length;
      final outcomes = {
        for (final platform in TargetPlatform.values)
          if (platform != TargetPlatform.iOS)
            platform.name: await _credentialOn(platform),
      };

      expect(
        outcomes,
        {
          for (final platform in TargetPlatform.values)
            if (platform != TargetPlatform.iOS)
              platform.name: 'failed: notConfigured: Sign in with Apple works '
                  'on iOS only, and the app runs on ${platform.name}.',
        },
        reason: 'Sign in with Apple works on iOS only in the app.',
      );
      expect(
        signInWithApple.requests.length,
        requests,
        reason: 'No request reached Apple.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the app lists the way to sign in with Apple, on iOS only, whose '
    'deletion asks Apple again, with an icon in the colour of the label',
    (tester) async {
      final methods = [
        for (final method in appSignInMethods)
          if (method.issuer == appleTestIssuer) method,
      ];
      expect(methods, hasLength(1), reason: 'The app has one way of Apple.');
      final method = methods.single;
      final available = <String, bool>{};
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        available[platform.name] = method.isAvailable;
      }
      debugDefaultTargetPlatformOverride = null;

      expect(
        [method.platforms, method.revokesOnDeletion, method.credential],
        [
          {TargetPlatform.iOS},
          true,
          appleCredential,
        ],
        reason: 'The way to sign in works on iOS, and the deletion of an '
            'account that signs in with it asks Apple again.',
      );
      expect(
        available,
        {
          for (final platform in TargetPlatform.values)
            platform.name: platform == TargetPlatform.iOS,
        },
        reason: 'A screen of sign-in shows its button on iOS only.',
      );

      const colour = Color(0xFF1F1F1F);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IconTheme(
            data: const IconThemeData(color: colour, size: 20),
            child: Center(child: method.icon),
          ),
        ),
      );
      expect(method.icon, isA<AppleSignInIcon>());
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        Icons.apple,
        reason: 'The icon is the Apple logo of the Material icons.',
      );
      final glyph = tester.widget<RichText>(
        find.descendant(of: find.byType(Icon), matching: find.byType(RichText)),
      );
      expect(
        [glyph.text.style?.color, tester.getSize(find.byType(Icon))],
        [colour, const Size(20, 20)],
        reason: 'The icon takes the colour and the size of the icons of the '
            'button, as Apple asks of a logo next to a title.',
      );
    },
    timeout: timeout,
  );
}
