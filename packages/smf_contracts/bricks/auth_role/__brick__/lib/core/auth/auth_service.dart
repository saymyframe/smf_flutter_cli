/// A user as the provider of sign-in knows them.
final class AuthUser {
  /// Creates the user [uid].
  const AuthUser({required this.uid, required this.isAnonymous, this.email});

  /// The id of the user. It stays the same for as long as the user exists,
  /// also when an anonymous user gets an account.
  final String uid;

  /// Whether the user is anonymous: a user that the app signed in itself,
  /// who has no account and nothing to sign in with again.
  final bool isAnonymous;

  /// The email address of the user, or `null` for a user without one, such
  /// as an anonymous user.
  final String? email;
}

/// Why a call of sign-in failed.
enum AuthFailureReason {
  /// The email address and the password match no account. A wrong password
  /// and an address without an account are this one reason, so that nobody
  /// learns from the app which addresses have an account.
  invalidCredentials,

  /// The email address has an account already.
  emailInUse,

  /// The provider takes no password as weak as this one.
  weakPassword,

  /// The text is no email address.
  invalidEmail,

  /// The account is disabled.
  userDisabled,

  /// Too many attempts: the provider takes no more for a while.
  tooManyAttempts,

  /// The device did not reach the provider.
  network,

  /// The call needs a user who signed in a short while ago, as the deletion
  /// of an account does: the user signs in again and repeats it.
  ///
  /// It is also the reason of a call for a user whose session has ended on
  /// the server. The service signs that user out on the device before it
  /// fails.
  recentSignInRequired,

  /// Sign-in is not set up at the provider, such as a way to sign in that
  /// is not enabled there. This is a mistake in the setup of the app, which
  /// [AuthFailure.developerHint] explains.
  notConfigured,

  /// Anything else. [AuthFailure.developerHint] has the error.
  unknown,
}

/// The failure of a call of sign-in: the only thing that such a call throws.
final class AuthFailure implements Exception {
  /// Creates the failure for [reason].
  const AuthFailure(this.reason, {this.developerHint});

  /// Why the call failed. The app shows a text of its own for each reason.
  final AuthFailureReason reason;

  /// What went wrong in the words of the provider, for the developer of the
  /// app, or `null`. It is no text for the user: show it in debug mode
  /// only.
  final String? developerHint;

  @override
  String toString() => developerHint == null
      ? 'AuthFailure: ${reason.name}'
      : 'AuthFailure: ${reason.name} ($developerHint)';
}

/// The accounts of the users of the app and the user of this device, as the
/// provider of sign-in keeps them.
///
/// The provider implements it. The code of the app does not call it: it
/// signs in through `appSession` of `app_session.dart`, which calls this
/// service and does what is the same with every provider.
///
/// Every implementation keeps to this:
/// - The service has [currentUser] from the moment it is created: the user
///   who was signed in on this device when the app last ran, without a
///   request to the server. The function that creates the service may be
///   called again, and the service that it returns then has the user who is
///   signed in now.
/// - When the future of a call completes, [currentUser] is the result of
///   the call. [userChanges] tells of every change of [currentUser], also
///   of one that no call here made.
/// - A call fails only with an [AuthFailure], and every call ends: when the
///   server does not answer, its future completes with
///   [AuthFailureReason.network].
/// - [linkPassword] and [deleteAccount] are calls for the user who is
///   signed in. Made when nobody is signed in, or when the session of that
///   user has ended on the server, such a call fails with
///   [AuthFailureReason.recentSignInRequired], and in the second case it
///   signs the user out on the device first.
abstract interface class AuthService {
  /// The user who is signed in on this device, or `null`.
  AuthUser? get currentUser;

  /// Tells of each change of [currentUser], once [currentUser] has changed:
  /// a broadcast stream. It may also tell of a user who has not changed.
  ///
  /// An error that it sends changes nothing: the session reports it as an
  /// error of the app and goes on listening.
  Stream<AuthUser?> get userChanges;

  /// Signs in to the account of [email] with [password].
  ///
  /// A wrong password and an address without an account both fail with
  /// [AuthFailureReason.invalidCredentials].
  ///
  /// It is also called while a user is signed in, an anonymous one or the
  /// user of another account: the user of this account then replaces that
  /// user on the device.
  Future<void> signIn({required String email, required String password});

  /// Creates an account for [email] with [password] and signs in to it.
  ///
  /// It is also called while the user of another account is signed in, and
  /// the user of the new account then replaces that user on the device.
  /// For an anonymous user, the session calls [linkPassword] instead.
  Future<void> signUp({required String email, required String password});

  /// Gives the anonymous user who is signed in an account for [email] with
  /// [password]. The user keeps the [AuthUser.uid] and is no longer
  /// anonymous.
  Future<void> linkPassword({required String email, required String password});

  /// Creates an anonymous user and signs in as that user.
  Future<void> signInAnonymously();

  /// Sends the message with which the owner of the account of [email] sets
  /// a new password.
  ///
  /// It completes whether [email] has an account or not, so that nobody
  /// learns from the app which addresses have one.
  Future<void> sendPasswordReset(String email);

  /// Signs the user out on this device. It completes when nobody is signed
  /// in too.
  Future<void> signOut();

  /// Deletes the user who is signed in, an anonymous one too, and signs
  /// out.
  ///
  /// It may fail with [AuthFailureReason.recentSignInRequired], and then
  /// succeeds once the user has signed in again, in whichever way the
  /// account allows.
  Future<void> deleteAccount();
}
