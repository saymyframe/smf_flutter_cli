import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/services.dart' show appFlavor;

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import 'firebase_options_staging.dart' as staging;

/// The options of the Firebase apps of the flavor of this build.
///
/// `appFlavor` is a constant, so a release build keeps only the options of
/// its own flavor.
FirebaseOptions get firebaseOptionsOfFlavor => switch (appFlavor) {
      'dev' => dev.DefaultFirebaseOptions.currentPlatform,
      'staging' => staging.DefaultFirebaseOptions.currentPlatform,
      'prod' => prod.DefaultFirebaseOptions.currentPlatform,
      _ => throw UnsupportedError(
          'The app has no Firebase options for the flavor $appFlavor. A new '
          'flavor goes into this file and into tool/configure_firebase.dart. '
          'A run from Xcode reads the flavor from '
          'ios/Flutter/Generated.xcconfig, which has none after flutter pub '
          'get, so the flavor is null under any scheme: run flutter build ios '
          '--config-only --flavor <flavor> first.',
        ),
    };
