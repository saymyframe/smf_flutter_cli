import '../../core/auth/app_session.dart';
import 'account_cubit.dart';
import 'reset_password_cubit.dart';
import 'session_cubit.dart';
import 'sign_in_cubit.dart';
import 'sign_up_cubit.dart';

/// Creates the cubit of the screen of the sign-in.
///
/// The cubits of the sign-in get the session of the app here, and no other
/// file of the screens names it: a test creates a cubit with a session of
/// its own.
SignInCubit createSignInCubit() => SignInCubit(appSession);

/// Creates the cubit of the screen that creates an account.
SignUpCubit createSignUpCubit() => SignUpCubit(appSession);

/// Creates the cubit of the screen that resets a password.
ResetPasswordCubit createResetPasswordCubit() => ResetPasswordCubit(appSession);

/// Creates the cubit of the screen of the account.
AccountCubit createAccountCubit() => AccountCubit(appSession);

/// Creates the cubit with the session of the app, which the root of the app
/// provides to every widget.
SessionCubit createSessionCubit() => SessionCubit(appSession);
