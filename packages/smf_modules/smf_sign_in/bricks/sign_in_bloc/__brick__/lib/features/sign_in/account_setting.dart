import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import '../../core/router/navigation.dart';
import 'account_setting_row.dart';
import 'session_cubit.dart';

/// The entry of the account on the settings screen: the
/// [AccountSettingRow] with who is signed in, from the [SessionCubit] of
/// the app, which leads to the screen of the account.
///
/// For a user without an account, the router shows the sign-in over the
/// settings screen first, and the screen of the account once the user is
/// signed in.
class AccountSetting extends StatelessWidget {
  /// Creates the entry.
  const AccountSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    return AccountSettingRow(
      signedIn: session is AccountSession,
      email: session is AccountSession ? session.email : null,
      onTap: () => context.nav.signIn.account().push<void>(),
    );
  }
}
