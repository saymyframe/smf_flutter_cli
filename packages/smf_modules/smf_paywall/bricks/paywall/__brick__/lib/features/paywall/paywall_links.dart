import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// The name of the key of the address of the terms of use in `.env`.
const String paywallTermsKey = '{{terms_key}}';

/// The name of the key of the address of the privacy policy in `.env`.
const String paywallPrivacyKey = '{{privacy_key}}';

/// The standard license agreement of Apple, which the terms of use of the
/// paywall lead to on iOS while `.env` has no address of the terms of use.
final Uri appleStandardEula = Uri.parse(
  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
);

/// The address of the terms of use that the paywall links to: the value of
/// [paywallTermsKey] in `.env`, or on iOS and macOS the standard license
/// agreement of Apple while that value is empty or no web address, and
/// otherwise `null`, for no link.
Uri? paywallTermsUrl() =>
    webAddressOf({{{env_paywall_terms_url}}}) ??
    switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => appleStandardEula,
      _ => null,
    };

/// The address of the privacy policy that the paywall links to: the value
/// of [paywallPrivacyKey] in `.env`, or `null`, for no link, while that
/// value is empty or no web address.
Uri? paywallPrivacyUrl() => webAddressOf({{{env_paywall_privacy_url}}});

/// The keys of `.env` whose values the paywall cannot link to, since they
/// are empty or no web address: in a debug build, the paywall names them
/// for the developer of the app.
List<String> missingPaywallKeys() => [
  if (webAddressOf({{{env_paywall_terms_url}}}) == null) paywallTermsKey,
  if (webAddressOf({{{env_paywall_privacy_url}}}) == null) paywallPrivacyKey,
];

/// [value] as a web address, with `https` or `http` and a host, or `null`
/// for an empty value and for anything else.
Uri? webAddressOf(String? value) {
  final address = Uri.tryParse(value?.trim() ?? '');
  if (address == null || address.host.isEmpty) return null;
  return address.isScheme('https') || address.isScheme('http') ? address : null;
}

/// Opens [url] outside the app: a page in the browser, or a page of the
/// store in the app of the store.
Future<void> openPaywallLink(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
