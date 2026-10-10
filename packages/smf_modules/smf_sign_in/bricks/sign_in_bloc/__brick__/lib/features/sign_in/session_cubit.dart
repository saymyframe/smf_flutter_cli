import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';

/// Who uses the app, for the widgets of the app: its state is the session
/// of the app, an `AppSession`, and it emits each change of it.
///
/// The root of the app provides one to every widget, so a widget reads the
/// user with `context.watch<SessionCubit>().state`.
class SessionCubit extends Cubit<AppSession> {
  /// Creates the cubit that follows [_session].
  SessionCubit(this._session) : super(_session.value) {
    _session.addListener(_follow);
  }

  final ValueListenable<AppSession> _session;

  void _follow() => emit(_session.value);

  @override
  Future<void> close() {
    _session.removeListener(_follow);
    return super.close();
  }
}
