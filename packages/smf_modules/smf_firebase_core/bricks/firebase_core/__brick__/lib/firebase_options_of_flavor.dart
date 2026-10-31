import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/services.dart' show appFlavor;

import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;
import 'firebase_options_staging.dart' as staging_options;

/// The options of the Firebase apps of the flavor of this build.
///
/// `appFlavor` is a constant, so a release build keeps only the options of
/// its own flavor.
FirebaseOptions get firebaseOptionsOfFlavor => switch (appFlavor) {
      'dev' => dev_options.DefaultFirebaseOptions.currentPlatform,
      'staging' => staging_options.DefaultFirebaseOptions.currentPlatform,
      'prod' => prod_options.DefaultFirebaseOptions.currentPlatform,
      _ => throw UnsupportedError(
          'The app has no Firebase options for the flavor $appFlavor. A new '
          'flavor goes into this file and into tool/configure_firebase.dart. '
          'A run from Xcode of the scheme Runner reads the flavor from '
          'ios/Flutter/Generated.xcconfig, which has none after flutter pub '
          'get: select the scheme of a flavor, or run flutter build ios '
          '--config-only --flavor <flavor> first.',
        ),
    };
