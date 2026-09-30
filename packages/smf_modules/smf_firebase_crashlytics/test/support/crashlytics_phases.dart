/// What `flutterfire configure` of flutterfire_cli 1.4 adds to the Xcode
/// project of an app with Crashlytics on macOS, repeated in the tests: the
/// build phase for Crashlytics of
/// `lib/src/firebase/firebase_apple_writes.dart`, which differs between 1.4.0
/// and 1.4.1, so [crashlyticsPhases] has both. firebase_core activates
/// 1.4.1, the lowest version that it accepts. When it activates or accepts
/// another version, which the README of the app names, compare that file of
/// the versions and add the phase of the new one here; a test checks that
/// the phases have those of the versions that the README names.
library;

/// The build phase for Crashlytics that `flutterfire configure` adds on macOS
/// to the target Runner of the Xcode project of an app that depends on
/// firebase_crashlytics, by version of flutterfire_cli: the object that the
/// program of Ruby of `addFlutterFireDebugSymbolsScript` in
/// `lib/src/firebase/firebase_apple_writes.dart` writes with the gem
/// xcodeproj 1.27.0 into the project of an app without build
/// configurations of its own, as SMF generates it. The id of the object is
/// random.
///
/// These are the programs of the two versions, run on the Xcode project of
/// an app of SMF; the phase of 1.4.1 is, byte for byte, that of an app
/// which flutterfire_cli 1.4.1 configured.
const crashlyticsPhases = {
  '1.4.0': r'''
		718736FC2635C7119A5BDAE0 /* FlutterFire: "flutterfire upload-crashlytics-symbols" */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
			);
			inputPaths = (
			);
			name = "FlutterFire: \"flutterfire upload-crashlytics-symbols\"";
			outputFileListPaths = (
			);
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "\n#!/bin/bash\nPATH=\"${PATH}:$FLUTTER_ROOT/bin:${PUB_CACHE}/bin:$HOME/.pub-cache/bin\"\n\nif [ -z \"$PODS_ROOT\" ] || [ ! -d \"$PODS_ROOT/FirebaseCrashlytics\" ]; then\n  # Cannot use \"BUILD_DIR%/Build/*\" as per Firebase documentation, it points to \"flutter-project/build/ios/*\" path which doesn't have run script\n  DERIVED_DATA_PATH=$(echo \"$BUILD_ROOT\" | sed -E 's|(.*DerivedData/[^/]+).*|\\1|')\n  PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT=\"${DERIVED_DATA_PATH}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run\"\nelse\n  PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT=\"$PODS_ROOT/FirebaseCrashlytics/run\"\nfi\n\n# Command to upload symbols script used to upload symbols to Firebase server\nflutterfire upload-crashlytics-symbols --upload-symbols-script-path=\"$PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT\" --platform=ios --apple-project-path=\"${SRCROOT}\" --env-platform-name=\"${PLATFORM_NAME}\" --env-configuration=\"${CONFIGURATION}\" --env-project-dir=\"${PROJECT_DIR}\" --env-built-products-dir=\"${BUILT_PRODUCTS_DIR}\" --env-dwarf-dsym-folder-path=\"${DWARF_DSYM_FOLDER_PATH}\" --env-dwarf-dsym-file-name=\"${DWARF_DSYM_FILE_NAME}\" --env-infoplist-path=\"${INFOPLIST_PATH}\" --default-config=default\n";
		};
''',
  '1.4.1': r'''
		0A794B254CF08D7406803316 /* FlutterFire: "flutterfire upload-crashlytics-symbols" */ = {
			isa = PBXShellScriptBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			inputFileListPaths = (
			);
			inputPaths = (
			);
			name = "FlutterFire: \"flutterfire upload-crashlytics-symbols\"";
			outputFileListPaths = (
			);
			outputPaths = (
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "\n#!/bin/bash\nPATH=\"${PATH}:$FLUTTER_ROOT/bin:${PUB_CACHE}/bin:$HOME/.pub-cache/bin\"\n\nif [ -n \"$PODS_ROOT\" ] && [ -f \"$PODS_ROOT/FirebaseCrashlytics/run\" ]; then\n  # CocoaPods installation.\n  PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT=\"$PODS_ROOT/FirebaseCrashlytics/run\"\nelif [ -n \"$BUILD_DIR\" ] && [ -f \"$BUILD_DIR/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run\" ]; then\n  # Swift Package Manager installation. Flutter resolves Swift Package Manager\n  # checkouts into \"$BUILD_DIR/SourcePackages\" (i.e. \"<project>/[ios|macos]/build/SourcePackages\"),\n  # rather than the Xcode DerivedData directory used for a plain Xcode project.\n  PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT=\"$BUILD_DIR/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run\"\nelse\n  # Fall back to the Xcode DerivedData directory in case Swift Package Manager\n  # checkouts are not resolved relative to \"$BUILD_DIR\" (older/alternative setups).\n  # Cannot use \"BUILD_DIR%/Build/*\" as per Firebase documentation, it points to \"flutter-project/build/ios/*\" path which doesn't have run script\n  DERIVED_DATA_PATH=$(echo \"$BUILD_ROOT\" | sed -E 's|(.*DerivedData/[^/]+).*|\\1|')\n  PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT=\"${DERIVED_DATA_PATH}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run\"\n\n  if [ ! -f \"$PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT\" ]; then\n    # Last resort: search both known Swift Package Manager checkout roots in case\n    # the exact expected layout above does not match this Xcode/Flutter version.\n    FOUND_UPLOAD_SCRIPT=$(find \"$BUILD_DIR\" \"${DERIVED_DATA_PATH}\" -type f -path '*firebase-ios-sdk/Crashlytics/run' -print -quit 2>/dev/null)\n    if [ -n \"$FOUND_UPLOAD_SCRIPT\" ]; then\n      PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT=\"$FOUND_UPLOAD_SCRIPT\"\n    fi\n  fi\nfi\n\n# Command to upload symbols script used to upload symbols to Firebase server\nflutterfire upload-crashlytics-symbols --upload-symbols-script-path=\"$PATH_TO_CRASHLYTICS_UPLOAD_SCRIPT\" --platform=ios --apple-project-path=\"${SRCROOT}\" --env-platform-name=\"${PLATFORM_NAME}\" --env-configuration=\"${CONFIGURATION}\" --env-project-dir=\"${PROJECT_DIR}\" --env-built-products-dir=\"${BUILT_PRODUCTS_DIR}\" --env-dwarf-dsym-folder-path=\"${DWARF_DSYM_FOLDER_PATH}\" --env-dwarf-dsym-file-name=\"${DWARF_DSYM_FILE_NAME}\" --env-infoplist-path=\"${INFOPLIST_PATH}\" --default-config=default\n";
		};
''',
};

/// The name of the build phase for Crashlytics that flutterfire adds, which
/// it finds the phase by when it configures the app again.
const crashlyticsPhaseName =
    'FlutterFire: "flutterfire upload-crashlytics-symbols"';

/// The script of the build phase for Crashlytics of flutterfire_cli
/// [version]: the `shellScript` of its object in [crashlyticsPhases],
/// without the quoting of the Xcode project (`\n`, `\"` and `\\`).
String crashlyticsPhaseScript(String version) {
  final quoted = RegExp(r'shellScript = "((?:[^"\\]|\\.)*)";')
      .firstMatch(crashlyticsPhases[version]!)![1]!;
  return quoted.replaceAllMapped(
    RegExp(r'\\(.)'),
    (match) => match[1] == 'n' ? '\n' : match[1]!,
  );
}

/// [project], the text of an Xcode project, with the build phase for
/// Crashlytics of flutterfire_cli [version] among its phases of shell
/// scripts; see [crashlyticsPhases].
String withCrashlyticsPhase(String project, String version) {
  const end = '/* End PBXShellScriptBuildPhase section */';
  if (!project.contains(end)) {
    throw ArgumentError.value(project, 'project', 'has no shell scripts');
  }
  return project.replaceFirst(end, '${crashlyticsPhases[version]!}$end');
}
