import 'package:flutter/foundation.dart';

import '../../core/purchases/app_purchases.dart';

/// Whether the user has premium access, as the guard of the routes that
/// need it asks: while the value is `false`, the router opens the paywall
/// over the page that the user is on in place of such a route, and once it
/// is `true`, the router closes the paywall and shows the route.
ValueListenable<bool> paywallHasPremium() => appPurchases.hasPremium;
