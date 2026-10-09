/// Gives the account [accountUid] what a guest had: the function that
/// [takeGuestData] returns.
typedef GiveGuestData = Future<void> Function(String accountUid);

/// Takes what the guest [guestUid] has in the app, and returns the function
/// that gives it to an account, or `null` when there is nothing to move.
///
/// A guest is an anonymous user. When a guest signs in to an account that
/// exists already, the user of the app changes from the guest to that
/// account, and what was kept under the id of the guest, such as a cart on
/// a server, would be left behind. So the session of the app calls this
/// function before the sign-in, while the guest is still signed in and may
/// read that data, and calls the function that it returns once the user of
/// the account is signed in:
///
/// ```dart
/// Future<GiveGuestData?> takeGuestData(String guestUid) async {
///   final cart = await carts.read(guestUid);
///   if (cart.isEmpty) return null;
///   return (accountUid) => carts.add(accountUid, cart);
/// }
/// ```
///
/// Only read here: the sign-in may still fail, and then the guest stays. An
/// error thrown here fails the sign-in before it starts. An error of the
/// function that this one returns is reported as an error of the app, and
/// the user stays signed in.
///
/// Call no method of `appSession` here, nor in the function that this one
/// returns. The sign-in is one of its calls, which run one after another,
/// so such a call would wait for the sign-in, and the sign-in for it.
///
/// It is not called when a guest signs up, since the guest then keeps the
/// id and everything under it, nor in an app without anonymous users.
Future<GiveGuestData?> takeGuestData(String guestUid) async => null;
