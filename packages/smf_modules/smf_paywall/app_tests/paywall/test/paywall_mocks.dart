// What the tests that continuous integration runs in an app with the
// paywall module need of the module, whichever module they test: the guard
// of premium access lets them through. Without it, the router opens the
// paywall in place of every route that needs premium access, as for a user
// who bought nothing, and the walk of the routes fails on that guard. The
// matrix sets it up before the tests of every module of such an app
// (MatrixAppTest.mocks).
//
// The purchase goes through the purchases of the app, so it is a purchase
// of whichever module provides them, whose own mocks keep what the user of
// the device bought in memory and let any purchase succeed. A test of
// purchases that needs a user without them identifies a throwaway user and
// then a fresh one, as the tests of the purchases role do. The tests of the
// paywall itself tell the mocks to buy nothing (paywallIsUnderTest).
import 'dart:async';

import 'package:{{app_name}}/core/purchases/app_purchases.dart';

/// Whether [grantPremium] leaves the app as its first launch finds it, with
/// nothing bought.
///
/// A test file of the paywall sets it while its main() declares its tests,
/// which is before the matrix sets up the mocks of the app for them.
bool paywallIsUnderTest = false;

/// Buys the first plan of the offer before the app starts, unless the test
/// file is one of the paywall itself.
///
/// The purchases of the app have not started yet, so the calls wait for the
/// first start of `appPurchases`, which is over once the plan is bought.
/// That start is the one of the start-up of the app in every test of the
/// app, so the first frame of the app has premium access. A test file that
/// starts no purchases leaves the calls waiting, which harms nothing. One
/// that starts `appPurchases` with a service of its own before any start-up
/// would get the calls on that service, so such a file sets
/// [paywallIsUnderTest] too.
void grantPremium() {
  if (paywallIsUnderTest) return;
  unawaited(
    appPurchases.plans().then((plans) => appPurchases.purchase(plans.first)),
  );
}
