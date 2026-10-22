import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/purchases/app_purchases.dart';

/// The access of the user, for the widgets of the app: its state is the
/// `AppAccess` of the purchases of the app, `NoAccess` or `PremiumAccess`,
/// and it emits each change of it.
///
/// The root of the app provides one to every widget, so a widget reads the
/// access with `context.watch<PremiumCubit>().state`.
class PremiumCubit extends Cubit<AppAccess> {
  /// Creates the cubit that follows [_purchases].
  PremiumCubit(this._purchases) : super(_purchases.value) {
    _purchases.addListener(_follow);
  }

  final ValueListenable<AppAccess> _purchases;

  void _follow() => emit(_purchases.value);

  @override
  Future<void> close() {
    _purchases.removeListener(_follow);
    return super.close();
  }
}
