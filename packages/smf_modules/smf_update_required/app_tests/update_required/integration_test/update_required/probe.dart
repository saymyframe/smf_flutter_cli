// The probe of the update_required module, which the start check runs on a
// device once the first screen of the app settled. A device is the only place
// where the version of the app comes from the platform side of
// package_info_plus, from what the build wrote into the app.
//
// It uses no test framework and only reads, in well under a second: the
// version that the app read must be numbers between dots, as the module
// compares them, and whether the version may run must agree with the lowest
// version that remote config has, with the store page of the reviews and
// with the lowest version that the user let pass for this launch. It assumes
// nothing of the screen that the app shows or of the probes that ran before
// it, and it never shows the screen "Update required" itself.
//
// The tests of the module run it too (update_required/gate_test.dart).
import 'package:{{app_name}}/core/review/app_review.dart';
import 'package:{{app_name}}/features/update_required/update_status.dart';
import 'package:{{app_name}}/features/update_required/version_compare.dart';

/// The probe of the start check: what is wrong with the screen "Update
/// required" of the running app. See the top of the file. It needs no
/// screen to settle, so it does not call [settle].
Future<List<String>> probeUpdateRequired(
  Future<void> Function() settle,
) async {
  final problems = <String>[];
  final version = updateStatus.version;
  if (version == null) {
    problems.add(
      'The app does not know its version, so the screen "Update required" '
      'never shows: package_info_plus gave none.',
    );
  } else if (versionNumbers(version) == null) {
    problems.add(
      'The version that the app reads, "$version", is not numbers between '
      'dots, so the screen "Update required" never shows.',
    );
  }
  final minimum = updateStatus.minimum;
  final below = version != null && versionBelow(version, minimum);
  final expected =
      !(below && appReview.hasStorePage && minimum != updateStatus.waived);
  final supported = updateStatus.supported.value;
  if (supported != expected) {
    problems.add(
      'The app ${supported ? 'runs' : 'shows the screen "Update required"'} '
      'with the version $version and the lowest version "$minimum", the store '
      'page ${appReview.hasStorePage ? '' : 'missing '}and the lowest version '
      '"${updateStatus.waived}" let pass: it should '
      '${expected ? 'run' : 'show the screen'}.',
    );
  }
  return problems;
}
