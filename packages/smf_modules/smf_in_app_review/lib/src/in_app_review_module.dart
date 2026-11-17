import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_in_app_review/bundles/in_app_review_bundle.dart';
import 'package:smf_in_app_review/src/agents.dart';
import 'package:smf_in_app_review/src/readme.dart';

/// The module that asks the store of the platform for its review dialog with
/// the in_app_review package, and so provides the review role.
///
/// The template of the role generates `ReviewService`, the interface of the
/// service of a provider, and `appReview`, which decides when a review is due
/// and which the code of the app calls at a natural break. This module adds
/// `in_app_review`, `url_launcher` and `package_info_plus` to the
/// dependencies of the app and implements the service in
/// `lib/core/review/in_app_review_service.dart`:
/// - it asks for the dialog of StoreKit on iOS and of the In-App Review API
///   of Google Play on Android, and lets the error of a platform that
///   refuses the request through, as the role asks;
/// - it opens exactly the page of the app in its store that `appReview`
///   gives it, outside the app, with `launchUrl` of url_launcher, and never
///   with `openStoreListing()` of the package, which on Android opens the
///   page of the id of the build that runs, such as that of a flavor that
///   has no page;
/// - it gives the version of the app from package_info_plus.
///
/// The module adds the section [readmeHeading] to the README of the app,
/// which tells how to see the dialog on Android, and a note to the section of
/// the role in the guide for coding agents.
final class InAppReviewModule extends SmfModule {
  /// Creates the module.
  const InAppReviewModule();

  /// The id of the module.
  static const id = ModuleId('in_app_review');

  static const _file = ImportRef.app('core/review/in_app_review_service.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The review dialog of the App Store and Google Play with '
            'in_app_review',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(reviewRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(inAppReviewBundle),
        const PubspecContribution.hosted('in_app_review', '^2.0.12'),
        // The version of each is the one that the other modules of the app
        // take, such as those that open links with url_launcher.
        const PubspecContribution.hosted('url_launcher', 'any'),
        const PubspecContribution.hosted('package_info_plus', 'any'),
        reviewRole.data(
          const RoleImplementation(
            type: TypeRef('InAppReviewService', import: _file),
            create: FactoryRef('createInAppReviewService', import: _file),
          ),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          reviewRole.description,
          AgentNote(agentNote),
        ),
      ];
}
