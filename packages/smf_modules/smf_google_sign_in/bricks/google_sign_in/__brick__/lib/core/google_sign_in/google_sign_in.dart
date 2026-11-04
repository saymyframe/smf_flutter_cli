import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../auth/app_session.dart';

/// The issuer of the ID tokens of Google.
const String _issuer = '{{{issuer}}}';

/// The logo of Google, the "G", an image that `pubspec.yaml` declares among
/// the assets of the app. Flutter takes the file of the same name in
/// `2.0x/` and `3.0x/` next to it for a screen with more pixels.
const String _logo = '{{{logo}}}';

/// The start of google_sign_in, which [googleCredential] waits for: the
/// package is started once, before its first sign-in.
Future<void>? _start;

/// Whether [_start] completed. A call after that does not wait for it
/// again: a future that completed lets each call that awaits it go on in a
/// microtask of the zone that started it, which may run none any more, as
/// the fake time of a widget test that is over before a later test signs in
/// in real time.
bool _started = false;

/// The method channel through which `{{{app_delegate}}}`
/// tells what the Google Sign-In SDK finds of the setup of the iOS app.
const MethodChannel _iosSetup = MethodChannel('{{{ios_setup_channel}}}');

/// What the Google Sign-In SDK finds of the setup of the iOS app before it
/// shows its sheet, as `{{{app_delegate}}}` reads it from
/// the files of the app: the iOS client of Google and the URL schemes of
/// the app.
///
/// The SDK stops the app with an exception that google_sign_in does not
/// catch when it has no iOS client of Google, when the id of the client is
/// empty, or when the reversed id of the client is not among the URL
/// schemes of the app, which it compares in lower case. That is
/// `-signInWithOptions:` of `GIDSignIn.m` in the Google Sign-In SDK 9,
/// which google_sign_in_ios 6.3 resolves. [problem] tells which of them the
/// app lacks, so that [googleCredential] fails in place of the SDK. A later
/// version of the SDK may stop the app for something else, so read that
/// method again when google_sign_in moves to another version.
@immutable
final class GoogleSignInIosSetup {
  const GoogleSignInIosSetup._({
    required this.answered,
    this.hasServiceInfo = false,
    this.clientId,
    this.source,
    this.urlSchemes = const [],
  });

  /// Whether `{{{app_delegate}}}` answered. Without its
  /// answer the app cannot tell whether the SDK would stop it, so [problem]
  /// tells of that.
  final bool answered;

  /// Whether the app has `GoogleService-Info.plist`.
  final bool hasServiceInfo;

  /// The id of the iOS client of Google that the SDK takes: the `clientId`
  /// that the app gives `initialize()`, or else `CLIENT_ID` of
  /// `GoogleService-Info.plist`, or else `GIDClientID` of
  /// `{{{info_plist}}}`; `null` when none has one.
  final String? clientId;

  /// Where [clientId] comes from, as a hint names it, or `null` without a
  /// client.
  final String? source;

  /// The URL schemes of `CFBundleURLTypes` of `{{{info_plist}}}`,
  /// in lower case.
  final List<String> urlSchemes;

  /// The URL scheme that the SDK needs: [clientId] reversed at its dots, in
  /// lower case, or `null` without a client.
  String? get urlScheme =>
      clientId?.split('.').reversed.join('.').toLowerCase();

  /// What the app lacks for which the SDK would stop it, or `null` when the
  /// SDK can show its sheet.
  String? get problem {
    if (!answered) {
      return '{{{app_delegate}}} does not answer the method channel '
          '{{{ios_setup_channel}}}, through which the app learns whether the '
          'Google Sign-In SDK finds the iOS client of Google and its URL '
          'scheme';
    }
    final clientId = this.clientId;
    if (clientId == null) {
      final serviceInfo = hasServiceInfo
          ? 'GoogleService-Info.plist has no CLIENT_ID'
          : 'the app has no GoogleService-Info.plist';
      return 'the iOS app has no iOS client of Google: $serviceInfo, and '
          '{{{info_plist}}} has no GIDClientID';
    }
    if (clientId.isEmpty) {
      return 'the id of the iOS client of Google in $source is empty';
    }
    final scheme = urlScheme!;
    if (urlSchemes.contains(scheme)) return null;
    return '{{{info_plist}}} has no URL scheme $scheme, the reversed '
        'id of the iOS client of Google in $source, among CFBundleURLSchemes '
        'of CFBundleURLTypes: add it there';
  }
}

/// The setup of Google sign-in of the iOS app, as
/// `{{{app_delegate}}}` answers on the method channel
/// `{{{ios_setup_channel}}}`, or `null` on another platform, where nothing
/// is asked.
///
/// [clientId] is the id of the iOS client that the app gives
/// `GoogleSignIn.instance.initialize()`, which the package takes before the
/// ids of the files of the app. [googleCredential] gives none, so it reads
/// the setup without one; a change that gives `initialize()` an id gives it
/// here too.
///
/// An app delegate that does not answer gives a setup whose
/// [GoogleSignInIosSetup.problem] says so: then the app cannot tell whether
/// the SDK would stop it.
Future<GoogleSignInIosSetup?> readGoogleSignInIosSetup({
  String? clientId,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  final Map<String, Object?> answer;
  try {
    answer =
        await _iosSetup.invokeMapMethod<String, Object?>('read') ?? const {};
  } on MissingPluginException {
    return const GoogleSignInIosSetup._(answered: false);
  }
  final (String?, String?) client = switch (answer) {
    _ when clientId != null => (
        clientId,
        'the clientId that the app gives initialize()',
      ),
    {'serviceInfoClientId': final String id} => (
        id,
        'CLIENT_ID of GoogleService-Info.plist',
      ),
    {'infoPlistClientId': final String id} => (
        id,
        'GIDClientID of {{{info_plist}}}',
      ),
    _ => (null, null),
  };
  return GoogleSignInIosSetup._(
    answered: true,
    hasServiceInfo: answer['serviceInfo'] == true,
    clientId: client.$1,
    source: client.$2,
    urlSchemes: [
      for (final scheme in answer['urlSchemes'] as List<Object?>? ?? const [])
        if (scheme is String) scheme.toLowerCase(),
    ],
  );
}

/// Asks Google for a credential with the sheet of Google sign-in, and
/// returns it, or `null` when the user closed the sheet.
///
/// The first call starts google_sign_in with `GoogleSignIn.instance
/// .initialize()`, without the ids of the clients of Google, so the package
/// finds them in the files of the app where the provider of sign-in puts
/// them. The credential is the ID token of the Google account that the user
/// chose.
///
/// A client of Google that is missing in the app, or a Google project that
/// does not know the app, fails with `notConfigured`, with a hint at the
/// section of the README of the app on it, "{{{readme}}}". Any other error
/// fails with `unknown`.
///
/// On iOS, the Google Sign-In SDK stops the app rather than fail when the
/// app has no iOS client of Google, an empty one, or not its URL scheme,
/// and the package does not catch what the SDK throws then. So each call on
/// iOS first reads the setup of the app with [readGoogleSignInIosSetup],
/// and fails with `notConfigured`, with the [GoogleSignInIosSetup.problem]
/// in its hint, without asking the SDK.
///
/// On Android, Credential Manager answers a key that Google does not know
/// as a cancel, after the user picked an account. Its description tells it
/// from a closed sheet: "[16] Account reauth failed." rather than "[16]
/// Cancelled by user.". A device that cannot reach Google gets the same
/// answer, so the hint names both.
Future<SignInCredential?> googleCredential() async {
  if ((await readGoogleSignInIosSetup())?.problem case final problem?) {
    throw _notConfigured(
      problem,
      cause: 'The Google Sign-In SDK stops an iOS app whose setup it cannot '
          'use, so the app did not ask it.',
    );
  }
  final GoogleSignInAccount account;
  try {
    if (!_started) {
      await (_start ??= GoogleSignIn.instance.initialize());
      _started = true;
    }
    account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled
          when (error.description ?? '').contains('Account reauth failed'):
        throw _notConfigured(
          error.description!,
          cause: 'On Android, Credential Manager answers so when Google does '
              'not know the SHA-1 of the key that signed this build of the '
              'app, and also when the device cannot reach Google.',
        );
      case GoogleSignInExceptionCode.canceled:
        return null;
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        throw _notConfigured(error.description ?? error.code.name);
      // Credential Manager on Android answers so when Google does not take
      // the server client of the app, `default_web_client_id` or the
      // `serverClientId` of `initialize()`, as a web client of the Google
      // project, such as the id of an Android client or of no client.
      case GoogleSignInExceptionCode.unknownError
          when RegExp(r'\b28444\b').hasMatch(error.description ?? ''):
        throw _notConfigured(error.description!);
      default:
        throw AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
    }
  } on Object catch (error) {
    throw AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
  }
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw const AuthFailure(
      AuthFailureReason.unknown,
      developerHint: 'Google gave no ID token.',
    );
  }
  return IdTokenCredential(issuer: _issuer, idToken: idToken);
}

/// The failure of a sign-in with Google that the app or the Google project
/// is not set up for, with [message], what Google answered, and [cause],
/// what Google answers so for when [message] does not tell it.
AuthFailure _notConfigured(String message, {String? cause}) => AuthFailure(
      AuthFailureReason.notConfigured,
      developerHint: 'Google sign-in is not set up for the app ($message).'
          '${cause == null ? '' : ' $cause'} See the section "{{{readme}}}" '
          'of the README of the app.',
    );

/// The icon of the button of Google sign-in: the "G" of Google in its own
/// colours, at the size of the icons of the button, as the branding
/// guidelines of Google ask of a custom button.
class GoogleSignInIcon extends StatelessWidget {
  /// Creates the icon.
  const GoogleSignInIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size;
    // The label of the button names Google.
    return Image.asset(
      _logo,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
