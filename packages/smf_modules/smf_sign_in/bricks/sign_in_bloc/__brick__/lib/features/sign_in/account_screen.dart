import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import 'account_cubit.dart';
import 'account_view.dart';
import 'session_cubit.dart';
import 'sign_in_composition.dart';
import 'sign_in_state.dart';

/// The screen of the account: the [AccountView] with the state of an
/// [AccountCubit], and the address of the account from the [SessionCubit]
/// of the app.
///
/// It neither closes itself nor navigates once the user is signed out or
/// the account is deleted: the router leaves the screen then.
{{{smf_router__screen_annotations__sign_in__account_screen}}}
class AccountScreen extends StatelessWidget {
  /// Creates the screen.
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createAccountCubit(),
    child: BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final session = context.watch<SessionCubit>().state;
        return AccountView(
          email: session is AccountSession ? session.email : null,
          busy: state.busy,
          failure: state.failure,
          onSignOut: context.read<AccountCubit>().signOut,
          onDeleteAccount: context.read<AccountCubit>().deleteAccount,
        );
      },
    ),
  );
}
