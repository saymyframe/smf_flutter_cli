// The probe of the purchases role, whichever module provides it, which the
// start check runs on a device once the first screen of the app settled,
// the only place where the platform side of the provider is the real one,
// and which the test of the role runs too (provider_test.dart): the access
// that the app shows is the one that the service of the provider gives for
// the user of the app.
//
// It uses no test framework. It only reads: it buys nothing, restores
// nothing and identifies no user, so the store account of the device and
// the purchases of the app stay as they are. A provider that is not set up,
// such as one without its keys, or a store that does not answer, as on a
// device without the store, fails the call with a reason that the role
// passes over too: that is no problem while the app shows no premium
// access. Any other failure reaches the start check, which reports it.
import 'package:{{app_name}}/core/purchases/app_purchases.dart';

/// The reasons of a failure of the service that tell of the setup of the
/// provider or of the store, not of the app: the controller of the role says
/// nothing of them either.
const Set<PurchasesFailureReason> _passing = {
  PurchasesFailureReason.notConfigured,
  PurchasesFailureReason.network,
  PurchasesFailureReason.unavailable,
  PurchasesFailureReason.storeProblem,
};

/// The probe of the start check: what is wrong with the purchases of the
/// app as the start-up left them. It waits for no screen, so it leaves
/// [settle] out.
Future<List<String>> probePurchases(Future<void> Function() settle) async {
  final shown = appPurchases.value;
  final AppAccess answer;
  try {
    answer = await createPurchasesService().access();
  } on PurchasesFailure catch (failure) {
    if (!_passing.contains(failure.reason)) rethrow;
    return [
      if (shown is PremiumAccess)
        'The app shows premium access, but the service of the provider '
            'fails with ${failure.reason.name}.',
    ];
  }
  return [
    if (answer != shown)
      'The access of the app is not the one that the service of the provider '
          'gives for the user of the app.',
  ];
}
