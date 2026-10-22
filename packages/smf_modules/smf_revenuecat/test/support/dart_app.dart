import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// A stand-in for the part of Flutter's foundation library that the file of
/// the module uses, with the signatures of Flutter 3.44. The app runs in
/// debug mode, and a test sets the platform that the app runs on, which
/// Flutter has as a getter.
const _foundation = '''
const bool kDebugMode = true;

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

TargetPlatform defaultTargetPlatform = TargetPlatform.android;
''';

/// A stand-in for the part of Flutter's services library that the file of
/// the module uses: what a plugin fails with.
const _services = r'''
class PlatformException implements Exception {
  PlatformException({required this.code, this.message, this.details});

  final String code;
  final String? message;
  final dynamic details;

  @override
  String toString() => 'PlatformException($code, $message, $details)';
}
''';

/// A stand-in for the part of purchases_flutter that the module uses, with
/// the signatures of purchases_flutter 10.18: the static methods of
/// `Purchases` and the models of their answers, with the codes of
/// RevenueCat in their order.
///
/// A test scripts and reads it through the top-level names: `revenueCatCalls`,
/// each call that reached the platform; `failNext`, the error that the next
/// call of a method fails with; `holdNext`, the methods whose next call
/// waits for a completer; `anonymous`, whether the user is anonymous; and
/// `customerInfo` and `offerings`, what RevenueCat answers.
const _purchasesFlutter = r'''
import 'dart:async';

import 'package:flutter/services.dart';

final List<String> revenueCatCalls = [];
final Map<String, PlatformException> failNext = {};
final Map<String, Completer<void>> holdNext = {};
bool anonymous = true;
CustomerInfo customerInfo = const CustomerInfo(EntitlementInfos({}));
Offerings offerings = const Offerings({});

Future<void> _called(String call) async {
  final method = call.split(' ').first;
  revenueCatCalls.add(call);
  final held = holdNext.remove(method);
  if (held != null) await held.future;
  final failure = failNext.remove(method);
  if (failure != null) throw failure;
}

enum PurchasesErrorCode {
  unknownError,
  purchaseCancelledError,
  storeProblemError,
  purchaseNotAllowedError,
  purchaseInvalidError,
  productNotAvailableForPurchaseError,
  productAlreadyPurchasedError,
  receiptAlreadyInUseError,
  invalidReceiptError,
  missingReceiptFileError,
  networkError,
  invalidCredentialsError,
  unexpectedBackendResponseError,
  receiptInUseByOtherSubscriberError,
  invalidAppUserIdError,
  operationAlreadyInProgressError,
  unknownBackendError,
  invalidAppleSubscriptionKeyError,
  ineligibleError,
  insufficientPermissionsError,
  paymentPendingError,
  invalidSubscriberAttributesError,
  logOutWithAnonymousUserError,
  configurationError,
  unsupportedError,
  emptySubscriberAttributesError,
  productDiscountMissingIdentifierError,
  unknownNonNativeError,
  productDiscountMissingSubscriptionGroupIdentifierError,
  customerInfoError,
  systemInfoError,
  beginRefundRequestError,
  productRequestTimeout,
  apiEndpointBlocked,
  invalidPromotionalOfferError,
  offlineConnectionError,
  featureNotAvailableInCustomEntitlementsComputationMode,
  signatureVerificationFailed,
  featureNotSupportedWithStoreKit1,
  invalidWebPurchaseToken,
  purchaseBelongsToOtherUser,
  expiredWebPurchaseToken,
  testStoreSimulatedPurchaseError,
}

enum PeriodType { intro, normal, trial, prepaid, unknown }

enum PeriodUnit { day, week, month, year, unknown }

enum IntroEligibilityStatus {
  introEligibilityStatusUnknown,
  introEligibilityStatusIneligible,
  introEligibilityStatusEligible,
  introEligibilityStatusNoIntroOfferExists,
}

class PurchasesConfiguration {
  PurchasesConfiguration(this.apiKey);

  final String apiKey;
  String? appUserID;
}

class EntitlementInfo {
  const EntitlementInfo(
    this.productIdentifier, {
    this.isActive = true,
    this.willRenew = false,
    this.periodType = PeriodType.normal,
    this.expirationDate,
    this.productPlanIdentifier,
  });

  final bool isActive;
  final bool willRenew;
  final String productIdentifier;
  final PeriodType periodType;
  final String? expirationDate;
  final String? productPlanIdentifier;
}

class EntitlementInfos {
  const EntitlementInfos(this.active);

  final Map<String, EntitlementInfo> active;
}

class CustomerInfo {
  const CustomerInfo(this.entitlements, {this.managementURL});

  final EntitlementInfos entitlements;
  final String? managementURL;
}

class IntroductoryPrice {
  const IntroductoryPrice(
    this.price,
    this.priceString,
    this.cycles,
    this.periodUnit,
    this.periodNumberOfUnits,
  );

  final double price;
  final String priceString;
  final int cycles;
  final PeriodUnit periodUnit;
  final int periodNumberOfUnits;
}

class StoreProduct {
  const StoreProduct(
    this.identifier,
    this.title,
    this.price,
    this.priceString,
    this.currencyCode, {
    this.introductoryPrice,
    this.subscriptionPeriod,
  });

  final String identifier;
  final String title;
  final double price;
  final String priceString;
  final String currencyCode;
  final IntroductoryPrice? introductoryPrice;
  final String? subscriptionPeriod;
}

class Package {
  const Package(this.identifier, this.storeProduct);

  final String identifier;
  final StoreProduct storeProduct;
}

class Offering {
  const Offering(this.identifier, this.availablePackages);

  final String identifier;
  final List<Package> availablePackages;

  Package? getPackage(String identifier) {
    for (final package in availablePackages) {
      if (package.identifier == identifier) return package;
    }
    return null;
  }
}

class Offerings {
  const Offerings(this.all, {this.current});

  final Map<String, Offering> all;
  final Offering? current;
}

class PurchaseParams {
  const PurchaseParams.package(Package this.package);

  final Package? package;
}

class PurchaseResult {
  const PurchaseResult(this.customerInfo);

  final CustomerInfo customerInfo;
}

class LogInResult {
  LogInResult({required this.created, required this.customerInfo});

  final bool created;
  final CustomerInfo customerInfo;
}

class IntroEligibility {
  IntroEligibility(this.status);

  IntroEligibilityStatus status;
}

typedef CustomerInfoUpdateListener = void Function(CustomerInfo customerInfo);

class Purchases {
  static final Set<CustomerInfoUpdateListener> listeners = {};

  static Future<void> configure(PurchasesConfiguration configuration) =>
      _called('setupPurchases ${configuration.apiKey}');

  static void addCustomerInfoUpdateListener(
    CustomerInfoUpdateListener listener,
  ) =>
      listeners.add(listener);

  static Future<bool> get isAnonymous async {
    await _called('isAnonymous');
    return anonymous;
  }

  static Future<LogInResult> logIn(String appUserID) async {
    await _called('logIn $appUserID');
    anonymous = false;
    return LogInResult(created: true, customerInfo: customerInfo);
  }

  static Future<CustomerInfo> logOut() async {
    await _called('logOut');
    anonymous = true;
    return customerInfo;
  }

  static Future<CustomerInfo> getCustomerInfo() async {
    await _called('getCustomerInfo');
    return customerInfo;
  }

  static Future<Offerings> getOfferings() async {
    await _called('getOfferings');
    return offerings;
  }

  static Future<PurchaseResult> purchase(PurchaseParams params) async {
    await _called('purchasePackage ${params.package!.identifier}');
    return PurchaseResult(customerInfo);
  }

  static Future<CustomerInfo> restorePurchases() async {
    await _called('restorePurchases');
    return customerInfo;
  }

  static Future<Map<String, IntroEligibility>>
      checkTrialOrIntroductoryPriceEligibility(
    List<String> productIdentifiers,
  ) async {
    await _called('checkTrialOrIntroductoryPriceEligibility');
    return {
      for (final id in productIdentifiers)
        id: IntroEligibility(
          IntroEligibilityStatus.introEligibilityStatusEligible,
        ),
    };
  }
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of Flutter and of
/// purchases_flutter that the code of the module uses, so that it can be
/// analyzed and run with the Dart SDK alone: the tests of the package run
/// without the Flutter SDK, which purchases_flutter needs.
///
/// The other files of the app need more of Flutter, so the analyzer checks
/// the files of the owners it is given, and a script that runs the app
/// imports none of the others. The real package runs in the tests of the
/// generated apps. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync('smf_revenuecat_');
    final files = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final file in files) {
      write('app/${file.path}', file.text);
    }
    write('flutter/lib/foundation.dart', _foundation);
    write('flutter/lib/services.dart', _services);
    write('purchases_flutter/lib/purchases_flutter.dart', _purchasesFlutter);
    write('app/pubspec.yaml', 'name: contract_app\n');
    // The stand-ins are in the language of the app too.
    final languageVersion = _languageVersionOf(app);
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
            ('purchases_flutter', '../../purchases_flutter/'),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': languageVersion,
            },
        ],
      }),
    );
    return DartApp._(root, files);
  }

  final Directory _root;
  final List<RenderedFile> _files;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The errors and warnings that the analyzer finds in the files of
  /// [owners], each with the path of its file.
  Future<List<String>> analysisProblems(Set<ContributionOrigin> owners) async {
    final appPath = _appPath;
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in _files) {
        if (!owners.contains(file.owner)) continue;
        // The analyzer takes only the paths of the system, such as
        // C:\app\lib\main.dart on Windows.
        final path = Uri.directory(appPath).resolve(file.path).toFilePath();
        final result = await collection
            .contextFor(path)
            .currentSession
            .getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          problems.add('${file.path}: cannot be resolved: $result');
          continue;
        }
        for (final diagnostic in result.diagnostics) {
          if (diagnostic.severity == Severity.info) continue;
          problems.add(
            '${file.path}:${result.lineInfo.getLocation(diagnostic.offset)}: '
            '${diagnostic.message}',
          );
        }
      }
      return problems;
    } finally {
      await collection.dispose();
    }
  }

  /// Runs [script], a Dart library whose `main(List<String>, SendPort)`
  /// imports the app by its package, `contract_app`, in an isolate of its
  /// own, and returns the first message it sends.
  ///
  /// Throws a [StateError] with the error if the isolate fails, or if it
  /// sends nothing in time.
  Future<Object?> run(String script) async {
    final file = File('${_root.path}/check.dart')..writeAsStringSync(script);
    final result = Completer<Object?>();
    void fail(String message) {
      if (!result.isCompleted) result.completeError(StateError(message));
    }

    final messages = ReceivePort()
      ..listen((message) {
        if (!result.isCompleted) result.complete(message);
      });
    final errors = ReceivePort()
      ..listen((error) => fail('The script failed: $error'));
    // The isolate sends its message before it ends, so an end that comes
    // first means that it sent none.
    final exits = ReceivePort()
      ..listen((_) => fail('The script ended without a message.'));
    Isolate? isolate;
    try {
      isolate = await Isolate.spawnUri(
        file.uri,
        const [],
        messages.sendPort,
        onError: errors.sendPort,
        onExit: exits.sendPort,
        packageConfig: Uri.file('$_appPath/.dart_tool/package_config.json'),
      );
      return await result.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError('The script sent nothing in time.'),
      );
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
      exits.close();
    }
  }

  /// Deletes the directory of the app.
  void delete() => _root.deleteSync(recursive: true);
}

/// The language version of [app]: that of the lower bound of the SDK
/// constraint of its pubspec, such as 3.12 for `^3.12.0`.
String _languageVersionOf(RenderedApp app) {
  final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
  final sdk = (pubspec['environment'] as YamlMap)['sdk'] as String;
  final version = RegExp(r'(\d+)\.(\d+)').firstMatch(sdk)!;
  return '${version[1]}.${version[2]}';
}
