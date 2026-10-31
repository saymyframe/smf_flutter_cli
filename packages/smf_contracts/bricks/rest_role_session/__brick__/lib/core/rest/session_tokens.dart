import '../auth/app_session.dart';
import 'app_rest.dart';

/// The token of the user of [appSession], for the requests of the app.
final class SessionRestTokens implements RestTokens {
  /// Creates the tokens of the session of the app.
  const SessionRestTokens();

  @override
  String? get owner => appSession.value.uid;

  @override
  Future<String?> current() => _read(appSession.userToken);

  @override
  Future<String?> after(String rejected) =>
      _read(() => appSession.userTokenAfter(rejected));

  Future<String?> _read(Future<String?> Function() read) async {
    try {
      return await read();
    } on AuthFailure catch (failure, stackTrace) {
      Error.throwWithStackTrace(
        RestFailure(
          _reasonOf(failure.reason),
          developerHint: failure.developerHint,
        ),
        stackTrace,
      );
    }
  }

  /// A session that ended on the server, and a disabled account, leave nobody
  /// signed in by now, so the request has no user any more.
  static RestFailureReason _reasonOf(AuthFailureReason reason) =>
      switch (reason) {
        AuthFailureReason.network => RestFailureReason.network,
        AuthFailureReason.tooManyAttempts => RestFailureReason.tooManyRequests,
        AuthFailureReason.recentSignInRequired ||
        AuthFailureReason.userDisabled =>
          RestFailureReason.unauthorized,
        _ => RestFailureReason.unknown,
      };
}
