// A test that continuous integration runs in the apps with the
// google_sign_in module, whatever else they have: the way to sign in with
// Google on the real google_sign_in package, over the mocks of its
// platform side (google_sign_in_mocks.dart), which the matrix sets up
// before the tests of each test file.
//
// googleCredential() starts the package once, without the ids of the
// clients of Google, and returns the ID token of the Google account that
// the user chose as a credential of the issuer of Google. A closed sheet
// returns null, the errors with which Google refuses an app that is not
// set up for it fail with notConfigured, and any other error with
// unknown. The app lists the way to sign in on Android and iOS, and its
// icon shows the logo of Google from the assets of the app, in its own
// colours, at the size of the icons of the button.
//
// What a provider of the auth role does with the credential is for the
// test of the ways to sign in of the role, auth_methods.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/sign_in_methods.dart';
import 'package:{{app_name}}/core/google_sign_in/google_sign_in.dart';

import '../google_sign_in_mocks.dart';

/// The image of the logo of Google among the assets of the app.
const _logo = 'lib/core/google_sign_in/assets/google_logo.png';

/// The claims of [idToken], a JSON Web Token.
Map<String, Object?> _claimsOf(String idToken) {
  final payload = idToken.split('.')[1];
  return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))))
      as Map<String, Object?>;
}

/// What a call of googleCredential() ended with: the credential, null, or
/// the reason and the hint of its failure.
Future<Object?> _outcome() async {
  try {
    return await googleCredential();
  } on AuthFailure catch (failure) {
    return 'failed: ${failure.reason.name}: ${failure.developerHint}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A test fails after ten minutes by default; a test that hangs fails
  // sooner.
  const timeout = Timeout(Duration(minutes: 2));

  test(
    'googleCredential() starts google_sign_in once, without the ids of the '
    'clients of Google, and returns the ID token of the Google account as a '
    'credential of Google',
    () async {
      final signIns = googleSignIn.signIns;
      final credentials = [
        for (final platform in [TargetPlatform.android, TargetPlatform.iOS])
          await () async {
            debugDefaultTargetPlatformOverride = platform;
            try {
              return await _outcome();
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          }(),
      ];

      expect(
        googleSignIn.signIns - signIns,
        2,
        reason: 'Each call asks Google once.',
      );
      expect(
        [
          for (final start in googleSignIn.starts)
            [
              start.clientId,
              start.serverClientId,
              start.nonce,
              start.hostedDomain,
            ],
        ],
        [
          [null, null, null, null],
        ],
        reason: 'The app starts google_sign_in once, before its first '
            'sign-in, and without ids, so that the package reads the ids of '
            'the clients of Google from the files of the app.',
      );
      expect(
        [
          for (final credential in credentials)
            switch (credential) {
              IdTokenCredential() => [
                  credential.issuer,
                  _claimsOf(credential.idToken)['iss'],
                  _claimsOf(credential.idToken)['sub'],
                  _claimsOf(credential.idToken)['email'],
                  credential.rawNonce,
                  credential.authorizationCode,
                  '$credential',
                ],
              _ => credential,
            },
        ],
        [
          for (var call = 0; call < 2; call++)
            [
              googleTestIssuer,
              googleTestIssuer,
              googleTestUser,
              googleTestEmail,
              null,
              null,
              'IdTokenCredential($googleTestIssuer)',
            ],
        ],
        reason: 'The credential is the ID token of the Google account, of '
            'the issuer of Google, without a raw nonce or a code, and it '
            'names no token.',
      );
    },
    timeout: timeout,
  );

  test(
    'a closed sheet returns null, the errors with which Google refuses an '
    'app that is not set up for it fail with notConfigured, and any other '
    'error with unknown',
    () async {
      final outcomes = <String, Object?>{};
      for (final (name, error) in <(String, Object)>[
        (
          'canceled',
          const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        ),
        (
          'clientConfigurationError',
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
            description: 'serverClientId must be provided on Android',
          ),
        ),
        (
          'providerConfigurationError',
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.providerConfigurationError,
            description: 'Credential Manager not supported.',
          ),
        ),
        (
          'unknownError of a key that Google does not know',
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: '[28444] Developer console is not set up correctly.',
          ),
        ),
        (
          'the exception of Google sign-in on iOS',
          PlatformException(
            code: 'google_sign_in',
            message: 'Your app is missing support for the following URL '
                'schemes: com.googleusercontent.apps.123',
            details: 'NSInvalidArgumentException',
          ),
        ),
        (
          'interrupted',
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
          ),
        ),
        (
          'another unknownError',
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'No credential available.',
          ),
        ),
        (
          'another exception of the platform',
          PlatformException(code: 'channel-error'),
        ),
      ]) {
        googleSignIn.failNext(error);
        final outcome = await _outcome();
        outcomes[name] = switch (outcome) {
          final String failure => failure.split(': ').take(2).join(': '),
          _ => outcome,
        };
      }

      expect(
        outcomes,
        {
          'canceled': null,
          'clientConfigurationError': 'failed: notConfigured',
          'providerConfigurationError': 'failed: notConfigured',
          'unknownError of a key that Google does not know':
              'failed: notConfigured',
          'the exception of Google sign-in on iOS': 'failed: notConfigured',
          'interrupted': 'failed: unknown',
          'another unknownError': 'failed: unknown',
          'another exception of the platform': 'failed: unknown',
        },
        reason: 'Closing the sheet of Google is no failure. Google refuses '
            'an app without its clients, or whose key it does not know.',
      );
      googleSignIn.failNext(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'serverClientId must be provided on Android',
        ),
      );
      expect(
        await _outcome(),
        allOf(
          contains('serverClientId must be provided on Android'),
          contains('See the section "Google sign-in" of the README'),
        ),
        reason: 'The hint of the failure tells what Google answered and '
            'names the section of the README of the app on Google sign-in.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the app lists the way to sign in with Google on Android and iOS, with '
    'the logo of Google, which the app bundles with a file for each of the '
    'screens with more pixels, in its own colours at the size of the icons '
    'of the button',
    (tester) async {
      final methods = [
        for (final method in appSignInMethods)
          if (method.issuer == googleTestIssuer) method,
      ];
      expect(methods, hasLength(1), reason: 'The app has one way of Google.');
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
          {TargetPlatform.android, TargetPlatform.iOS},
          false,
          googleCredential,
        ],
        reason: 'The way to sign in works on Android and iOS, and the '
            'deletion of an account that signs in with it asks Google '
            'nothing.',
      );
      expect(
        available,
        {
          for (final platform in TargetPlatform.values)
            platform.name: platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS,
        },
        reason: 'A screen of sign-in shows its button on Android and iOS '
            'only.',
      );

      // The image of the logo, as the app bundles it.
      final sizes = await tester.runAsync(() async {
        final assets = await AssetManifest.loadFromAssetBundle(rootBundle);
        return {
          for (final variant
              in assets.getAssetVariants(_logo) ?? <AssetMetadata>[])
            variant.key: (
              variant.targetDevicePixelRatio,
              await () async {
                final data = await rootBundle.load(variant.key);
                final codec = await ui.instantiateImageCodec(
                  data.buffer.asUint8List(),
                );
                final image = (await codec.getNextFrame()).image;
                return (image.width, image.height);
              }(),
            ),
        };
      });
      expect(
        sizes,
        {
          _logo: (null, (18, 18)),
          'lib/core/google_sign_in/assets/2.0x/google_logo.png': (
            2.0,
            (36, 36)
          ),
          'lib/core/google_sign_in/assets/3.0x/google_logo.png': (
            3.0,
            (54, 54)
          ),
        },
        reason: 'The app bundles the logo of Google, an image of 18 logical '
            'pixels, with a file for each of the screens with two and with '
            'three pixels for a logical pixel.',
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
      expect(method.icon, isA<GoogleSignInIcon>());
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        [
          (image.image as AssetImage).assetName,
          image.color,
          image.excludeFromSemantics,
          tester.getSize(find.byType(Image)),
        ],
        [_logo, null, true, const Size(20, 20)],
        reason: 'The icon shows the logo of Google in its own colours, at '
            'the size of the icons of the button, and leaves the name of '
            'Google to the label of the button.',
      );
      Object? error;
      await tester.runAsync(
        () => precacheImage(
          image.image,
          tester.element(find.byType(Image)),
          onError: (exception, stackTrace) => error = exception,
        ),
      );
      expect(error, isNull, reason: 'The logo loads on the screen.');
    },
    timeout: timeout,
  );
}
