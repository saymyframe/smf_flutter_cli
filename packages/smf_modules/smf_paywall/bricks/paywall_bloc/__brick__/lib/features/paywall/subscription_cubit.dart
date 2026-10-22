import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/purchases/app_purchases.dart';

/// The state of the screen of the subscription: the access of the user from
/// the purchases of the app, which it follows, and the page of the store
/// where the user manages the plan.
class SubscriptionCubit extends Cubit<AppAccess> {
  /// Creates the cubit that follows [_purchases] and opens a page with
  /// [openLink].
  SubscriptionCubit(
    this._purchases, {
    required Future<void> Function(Uri url) openLink,
  }) : _openLink = openLink,
       super(_purchases.value) {
    _purchases.addListener(_follow);
  }

  final AppPurchasesController _purchases;
  final Future<void> Function(Uri url) _openLink;

  /// Opens [url], the page of the store where the user manages the plan.
  Future<void> manage(Uri url) => _openLink(url);

  void _follow() => emit(_purchases.value);

  @override
  Future<void> close() {
    _purchases.removeListener(_follow);
    return super.close();
  }
}
