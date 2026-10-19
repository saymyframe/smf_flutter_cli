import 'package:smf_contracts/core.dart';

/// The page of the site of SMF that guides the developer of an app through
/// the steps of its setup that are done by hand (see [ManualStep]).
///
/// The page reads the ids of the steps from its query, as
/// `?steps=<wire>,<wire>` (see [ManualStepId.wire]), and shows the guide of
/// each, in that order. The site keeps a guide for every id of the catalog
/// of the steps (`setup_steps.json` of the package), those that the apps no
/// longer have too, since a link that a run once printed names them.
const setupGuidePage = 'https://doc.saymyframe.com/setup';

/// The link to [setupGuidePage] for [steps], the ids of the steps by hand
/// of an app in their order, such as
/// `https://doc.saymyframe.com/setup?steps=app_entry.ios_app_id,firebase_messaging.apns_key`:
/// the `SetupLink` of `smf create`.
///
/// The wires are lower snake_case with a dot, which a query carries as they
/// are, so the link puts them there by hand: `Uri(queryParameters:)` would
/// write each comma between them as `%2C`.
Uri setupGuideLinkOf(List<ManualStepId> steps) => Uri.parse(
      '$setupGuidePage?steps=${[for (final id in steps) id.wire].join(',')}',
    );
