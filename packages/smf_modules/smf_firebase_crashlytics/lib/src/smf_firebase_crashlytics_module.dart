import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

class SmfFirebaseCrashlyticsModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
        name: kFirebaseCrashlytics,
        description: 'SMF Firebase Crashlytics module',
        dependsOn: {kFirebaseCore},
        pubDependency: {'firebase_crashlytics: ^5.0.1'},
      );

  @override
  List<Contribution> get sharedFileContributions => [
        InsertImport(
          file: 'lib/main.dart',
          import: "import 'dart:isolate';",
        ),
        InsertImport(
          file: 'lib/main.dart',
          import: "import "
              "'package:firebase_crashlytics/firebase_crashlytics.dart';",
        ),
        InsertImport(
          file: 'lib/main.dart',
          import: "import "
              "'package:flutter/foundation.dart' "
              "show PlatformDispatcher, kDebugMode;",
        ),
        InsertIntoFunction(
          file: 'lib/main.dart',
          function: 'main',
          afterStatement: 'Firebase.initializeApp',
          insert: '''
                    
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (kDebugMode) {
      onError?.call(details);
    }
  
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  
  // Pass all uncaught asynchronous errors 
  // that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  Isolate.current.addErrorListener(
    RawReceivePort((pair) async {
      final List<dynamic> errorAndStacktrace = pair;
      await FirebaseCrashlytics.instance.recordError(
        errorAndStacktrace.first,
        errorAndStacktrace.last,
        fatal: true,
      );
    }).sendPort,
  );
    
      ''',
        ),
      ];
}
