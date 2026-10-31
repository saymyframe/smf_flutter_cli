/// A user as the provider of sign-in knows them.
final class AuthUser {
  /// Creates the user [uid].
  const AuthUser({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.issuers = const {},
  });

  /// The id of the user. It stays the same for as long as the user exists,
  /// also when an anonymous user gets an account.
  final String uid;

  /// Whether the user is anonymous: a user that the app signed in itself,
  /// who has no account and nothing to sign in with again.
  final bool isAnonymous;

  /// The email address of the user, or `null` for a user without one, such
  /// as an anonymous user.
  final String? email;

  /// The identity providers whose identities the user signs in with, each
  /// by the issuer of its tokens, such as `https://accounts.example.com`:
  /// the [IdTokenCredential.issuer] of a credential that the user signed in
  /// or linked with. It is empty for a user who signs in with a password
  /// alone, and for an anonymous user.
  final Set<String> issuers;
}

/// What a way to sign in got from an identity provider, such as the token
/// of an account of the user at another service, with which the provider
/// of sign-in signs the user in: [AuthService.signInWith] and
/// [AuthService.linkWith] take it.
sealed class SignInCredential {
  const SignInCredential();
}

/// An OpenID Connect ID token that an identity provider issued, with what
/// came with it.
final class IdTokenCredential extends SignInCredential {
  /// Creates the credential of [idToken], which [issuer] issued.
  const IdTokenCredential({
    required this.issuer,
    required this.idToken,
    this.rawNonce,
    this.authorizationCode,
    this.givenName,
    this.familyName,
  });

  /// The identity provider that issued the token: the `iss` of the token,
  /// an https URL such as `https://accounts.example.com`.
  final String issuer;

  /// The ID token, a JSON Web Token.
  final String idToken;

  /// The nonce whose hash the request for the token had, which the
  /// identity provider wrote into the token, or `null` if the request had
  /// none. The provider of sign-in passes it on where its backend checks
  /// the token against it.
  final String? rawNonce;

  /// The authorization code that came with the token, or `null`. With it, a
  /// provider of sign-in revokes the tokens that the identity provider gave
  /// the app when the account is deleted.
  final String? authorizationCode;

  /// The given name of the user, or `null`, for an identity provider that
  /// tells it apart from the token, and maybe only at the first sign-in.
  final String? givenName;

  /// The family name of the user, as [givenName].
  final String? familyName;

  /// Names the issuer, and no token, so that a token never reaches a log.
  @override
  String toString() => 'IdTokenCredential($issuer)';
}

/// Why a call of sign-in failed.
enum AuthFailureReason {
  /// The email address and the password match no account. A wrong password
  /// and an address without an account are this one reason, so that nobody
  /// learns from the app which addresses have an account.
  ///
  /// It is also the reason of a [SignInCredential] that the provider
  /// refuses, such as one that expired or that was issued for another app,
  /// and of one of another user than the one whose account is deleted.
  invalidCredentials,

  /// The email address has an account already.
  emailInUse,

  /// The identity of a [SignInCredential] belongs to another user already,
  /// so [AuthService.linkWith] gives it to nobody else. The session then
  /// signs in to that user.
  credentialInUse,

  /// The email address of the identity of a [SignInCredential] has an
  /// account that signs in in another way, such as with a password. The
  /// user signs in that way.
  accountExistsWithOtherMethod,

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
/// Every implementation keeps to this, in every mode of the app, whatever
/// the provider generates for the mode:
/// - The service has [currentUser] from the moment it is created: the user
///   who was signed in on this device when the app last ran, without a
///   request to the server. The function that creates the service may be
///   called again, and the service that it returns then has the user who is
///   signed in now.
/// - When the future of a call completes, [currentUser] is the result of
///   the call. [userChanges] tells of every change of [currentUser], also
///   of one that no call here made, and when it tells of a user,
///   [currentUser] is that user.
/// - A call fails only with an [AuthFailure], and every call ends: when the
///   server does not answer, its future completes with
///   [AuthFailureReason.network].
/// - A call that fails leaves the user who is signed in as that user was:
///   an anonymous user stays signed in when [linkPassword] or [linkWith]
///   fails, and so does whoever is signed in when [signIn], [signUp] or
///   [signInWith] fails. The one exception is a call for a user whose
///   session has ended on the server.
/// - [linkPassword], [linkWith] and [deleteAccount] are calls for the user
///   who is signed in. Made when nobody is signed in, or when the session of
///   that user has ended on the server, such a call fails with
///   [AuthFailureReason.recentSignInRequired], and in the second case it
///   signs the user out on the device first. [userToken] reads, so it answers
///   `null` when nobody is signed in, and does the same as those calls when
///   the session of the user has ended on the server.
/// - A [SignInCredential] whose identity provider the provider does not
///   take fails with [AuthFailureReason.notConfigured], with the issuer in
///   the [AuthFailure.developerHint].
abstract interface class AuthService {
  /// The user who is signed in on this device, or `null`.
  AuthUser? get currentUser;

  /// Tells of each change of [currentUser], once [currentUser] has changed:
  /// a broadcast stream. When it tells of a user, [currentUser] is that
  /// user. It may also tell of a user who has not changed.
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
  /// user on the device. When it fails, that user stays signed in.
  Future<void> signIn({required String email, required String password});

  /// Creates an account for [email] with [password] and signs in to it.
  ///
  /// For an address that has an account already, it fails with
  /// [AuthFailureReason.emailInUse] and changes nothing: that account keeps
  /// its password, and whoever is signed in stays signed in.
  ///
  /// It is also called while the user of another account is signed in, and
  /// the user of the new account then replaces that user on the device.
  /// For an anonymous user, the session calls [linkPassword] instead.
  Future<void> signUp({required String email, required String password});

  /// Gives the anonymous user who is signed in an account for [email] with
  /// [password]. The user keeps the [AuthUser.uid] and is no longer
  /// anonymous.
  ///
  /// For an address that has an account already, it fails with
  /// [AuthFailureReason.emailInUse] and changes nothing: the anonymous user
  /// stays signed in, with the same id.
  Future<void> linkPassword({required String email, required String password});

  /// Signs in with [credential], which a way to sign in got from an
  /// identity provider: to the user of its identity, whom it creates when
  /// the identity is new.
  ///
  /// It is also called while a user is signed in, an anonymous one or the
  /// user of another account: the user of the identity then replaces that
  /// user on the device. When it fails, that user stays signed in.
  ///
  /// It takes a credential that [linkWith] refused just before, with
  /// [AuthFailureReason.credentialInUse] or
  /// [AuthFailureReason.accountExistsWithOtherMethod]: the session passes
  /// the identical object. An identity provider may take a credential only
  /// once, so the service signs in with what its backend answered the
  /// refused link for that object, or with the credential itself when the
  /// backend gave nothing. For an identity whose email address has an
  /// account that signs in in another way, it fails with
  /// [AuthFailureReason.accountExistsWithOtherMethod] or signs in to that
  /// account, as the backend of the provider decides.
  Future<void> signInWith(SignInCredential credential);

  /// Gives the user who is signed in the identity of [credential]: the user
  /// keeps the [AuthUser.uid], is no longer anonymous, and signs in with
  /// that identity from then on. The session calls it for an anonymous
  /// user.
  ///
  /// When the identity belongs to another user, it fails with
  /// [AuthFailureReason.credentialInUse], and when its email address has an
  /// account of another user, with
  /// [AuthFailureReason.accountExistsWithOtherMethod]. Either way it changes
  /// nothing: the user stays signed in, with the same id.
  ///
  /// When it fails with either reason, it keeps what its backend answered
  /// for this credential object, such as a credential to sign in with,
  /// without holding the token longer than needed. The session passes the
  /// identical object to [signInWith], which uses that answer, or the
  /// credential itself when the backend gave nothing.
  Future<void> linkWith(SignInCredential credential);

  /// Creates an anonymous user, with an id of its own, and signs in as that
  /// user.
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
  /// It succeeds for a user who has just signed in, in whichever way, and
  /// for an anonymous user who was just created. For a user who signed in
  /// longer ago, such as one whom the service found on the device when it
  /// was created, it may fail with
  /// [AuthFailureReason.recentSignInRequired]. It then succeeds once the
  /// user has signed in again, in whichever way the account allows.
  ///
  /// With [fresh], a credential that a way to sign in of the user got just
  /// before, the service first signs the user in again with it, so the
  /// deletion needs no recent sign-in, and revokes the tokens that the
  /// identity provider gave the app where its backend can, such as with
  /// [IdTokenCredential.authorizationCode]. A credential of another user
  /// fails with [AuthFailureReason.invalidCredentials], and a revocation
  /// that fails, such as one that the backend is not set up for, with
  /// [AuthFailureReason.notConfigured]. Either way nothing is deleted.
  Future<void> deleteAccount({SignInCredential? fresh});

  /// The token with which a server of the app tells who the user is, or
  /// `null` when nobody is signed in. An anonymous user has one too.
  ///
  /// It comes from the device when it can, and the service refreshes one that
  /// is about to expire on its own, so most reads make no request. With
  /// [forceRefresh] it asks the server of the provider for a new token, which
  /// differs from the one before and which the reads after it give. A token
  /// that the server issued in the same second may come back the same.
  ///
  /// A read changes no user, and leaves whoever is signed in, but in the case
  /// below. [userChanges] may tell of the same user again after it, as after
  /// any change of the token, which the session ignores.
  ///
  /// It fails with [AuthFailureReason.network] when it needs the server and
  /// does not reach it, and with [AuthFailureReason.tooManyAttempts] when the
  /// server refuses for now. It fails with
  /// [AuthFailureReason.recentSignInRequired] for a user whose session has
  /// ended on the server, or may fail with [AuthFailureReason.userDisabled]
  /// for one whom the server disabled: the service signs that user out on the
  /// device first, while that user is still signed in. Anything else is
  /// [AuthFailureReason.unknown], with what the provider answered as its
  /// [AuthFailure.developerHint]. No hint of a failure has the token.
  Future<String?> userToken({bool forceRefresh = false});
}
