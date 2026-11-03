import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_google_sign_in/src/readme.dart';

/// The name of the method channel through which the app delegate of the
/// iOS app tells `readGoogleSignInIosSetup()` of [googleSignInFile] what
/// the Google Sign-In SDK finds of the setup of the app.
const iosSetupChannel = 'google_sign_in/ios_setup';

/// The Swift statements that the module puts into
/// `didInitializeImplicitFlutterEngine(_:)` of the app delegate
/// ([AppEntryRole.iosAppDelegateEngine]): a handler of [iosSetupChannel]
/// that answers its method `read` with what the Google Sign-In SDK reads of
/// the setup of the app, where google_sign_in_ios and the SDK read it.
///
/// The answer has `serviceInfo`, whether the bundle of the app has
/// `GoogleService-Info.plist`; `serviceInfoClientId`, its `CLIENT_ID`;
/// `infoPlistClientId`, `GIDClientID` of `Info.plist`; and `urlSchemes`,
/// the schemes of each entry of `CFBundleURLTypes` of `Info.plist`. A value
/// that is missing, or not a string, leaves its key out. The handler only
/// reads: the Dart code of the app decides whether the SDK would stop the
/// app.
const iosSetupReader = '''
    // Google sign-in: tells googleCredential() of
    // $googleSignInFile what the Google Sign-In SDK
    // finds of the setup of the app, which stops the app when the iOS client
    // of Google or its URL scheme is missing. It reads them where
    // google_sign_in and the SDK read them.
    FlutterMethodChannel(
      name: "$iosSetupChannel",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "read" else { return result(FlutterMethodNotImplemented) }
      let serviceInfo = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        .flatMap { NSDictionary(contentsOfFile: \$0) as? [String: Any] }
      let urlTypes =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
      var setup: [String: Any] = [
        "serviceInfo": serviceInfo != nil,
        "urlSchemes": urlTypes.flatMap { \$0["CFBundleURLSchemes"] as? [String] ?? [] },
      ]
      setup["serviceInfoClientId"] = serviceInfo?["CLIENT_ID"] as? String
      setup["infoPlistClientId"] = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
      result(setup)
    }''';
