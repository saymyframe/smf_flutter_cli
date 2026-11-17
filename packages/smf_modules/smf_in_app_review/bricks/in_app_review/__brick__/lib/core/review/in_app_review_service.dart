import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'review_service.dart';

/// Creates the reviews of the app on in_app_review, with the app. It asks
/// the user nothing.
ReviewService createInAppReviewService() => const InAppReviewService._();

/// The reviews of the app on in_app_review: the review dialog of StoreKit
/// on iOS and of the In-App Review API of Google Play on Android.
///
/// The page of the app in its store opens with url_launcher, exactly as
/// `appReview` gives it, and never through `openStoreListing()` of
/// in_app_review, which on Android opens the page of the id of the build
/// that runs, such as that of a flavor that has no page in Google Play.
/// The version of the app comes from package_info_plus.
///
/// Google Play shows the dialog only in an app that it installed, such as
/// from an internal test track. On a device without the review service of
/// Google Play, such as an emulator without the Play Store, [isAvailable]
/// is `false` and [requestReview] fails, so the app records no request and
/// asks again later. On a device with the Play Store, for an app that
/// Google Play did not install, such as a local build, [requestReview]
/// completes and shows nothing, and the app counts the request, so it does
/// not ask again in that version of the app.
final class InAppReviewService implements ReviewService {
  const InAppReviewService._();

  @override
  Future<bool> isAvailable() async {
    try {
      return await InAppReview.instance.isAvailable();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<bool> openStorePage(Uri page) async {
    try {
      return await launchUrl(page, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> appVersion() async {
    try {
      final version = (await PackageInfo.fromPlatform()).version.trim();
      return version.isEmpty ? null : version;
    } on Object {
      return null;
    }
  }
}
