/// The tests that the matrix of CI adds to the apps of the modules of
/// `smf create`, for `tool/matrix.dart` and for the app of several
/// providers of the fixture registry. No library of the binary imports it.
library;

import 'package:smf_apple_sign_in/smf_apple_sign_in.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_firebase_messaging/smf_firebase_messaging.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_google_sign_in/smf_google_sign_in.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_launcher_icons/smf_launcher_icons.dart';
import 'package:smf_local_notifications/smf_local_notifications.dart';
import 'package:smf_onboarding/smf_onboarding.dart';
import 'package:smf_paywall/smf_paywall.dart';
import 'package:smf_revenuecat/smf_revenuecat.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_sign_in/smf_sign_in.dart';

/// The tests that the matrix of the modules of `smf create` adds to its
/// apps, which the CLI and the packages of its modules keep in their
/// `app_tests`, and the roles whose contract they check with every
/// provider; `tool/matrix.dart` runs them in CI.
///
/// Only that tool, the tests of the CLI and the app of several providers of
/// the fixture registry, which runs them next to other providers of their
/// roles, use them: they name the modules whose app tests they register and
/// the roles whose contract those check, which the binary knows nothing of.
Future<MatrixAppTests> smfAppTests() async {
  final cli = await appTestsDirectoryOf('smf_flutter_cli');
  final firebaseCore = await appTestsDirectoryOf('smf_firebase_core');
  final crashlytics = await appTestsDirectoryOf('smf_firebase_crashlytics');
  final analytics = await appTestsDirectoryOf('smf_firebase_analytics');
  final firebaseAuth = await appTestsDirectoryOf('smf_firebase_auth');
  final googleSignIn = await appTestsDirectoryOf('smf_google_sign_in');
  final appleSignIn = await appTestsDirectoryOf('smf_apple_sign_in');
  final messaging = await appTestsDirectoryOf('smf_firebase_messaging');
  final home = await appTestsDirectoryOf('smf_home_flutter');
  final launcherIcons = await appTestsDirectoryOf('smf_launcher_icons');
  final localNotifications = await appTestsDirectoryOf(
    'smf_local_notifications',
  );
  final onboarding = await appTestsDirectoryOf('smf_onboarding');
  final paywall = await appTestsDirectoryOf('smf_paywall');
  final revenueCat = await appTestsDirectoryOf('smf_revenuecat');
  final settings = await appTestsDirectoryOf('smf_settings');
  final sharedPreferences = await appTestsDirectoryOf(
    'smf_shared_preferences',
  );
  final signIn = await appTestsDirectoryOf('smf_sign_in');
  return MatrixAppTests(
    [
      // The app starts and shows its first screen: a check that CI builds
      // as the entry of the app and starts on an Android emulator and on an
      // iOS simulator with .github/scripts/start_app.sh, in the apps that
      // it adds it to with --add-app-tests. It knows no module, only main()
      // of lib/main.dart, which the app entry role puts into every app
      // whichever module provides it, so the CLI keeps it and it applies to
      // every app. In the apps of the matrix it is only analyzed, and
      // flutter test runs the tests that the modules put into each app.
      // Once the first screen settled, it runs the probes of the tests that
      // go into the app with it, which go through the roles of the app,
      // such as the walk of its routes.
      MatrixAppTest(
        '$cli/start',
        appliesTo: (_) => true,
        readsStartProbes: true,
      ),
      // The start-up of the app initializes Firebase, with the options of the
      // flavor of the tests as flutterfire would write them, and the mocks of
      // Firebase Core, which the matrix sets up for the tests of every module
      // of the app.
      MatrixAppTest(
        '$firebaseCore/firebase_core',
        appliesTo: _has(FirebaseCoreModule.id),
        devDependencies: const ['firebase_core_platform_interface'],
        mocks: const MatrixMocks(
          'test/firebase_core_mocks.dart',
          'mockFirebaseCore',
        ),
      ),
      // The crash reporter of the module reaches Crashlytics, and the
      // errors that nothing catches reach it through the handlers that the
      // start-up of the app installs. The tests look only at what reaches
      // Crashlytics, not at the other crash reporters that the app may
      // have.
      MatrixAppTest(
        '$crashlytics/firebase_crashlytics',
        appliesTo: _has(FirebaseCrashlyticsModule.id),
        devDependencies: const ['firebase_crashlytics_platform_interface'],
        mocks: const MatrixMocks(
          'test/firebase_crashlytics_mocks.dart',
          'mockFirebaseCrashlytics',
        ),
      ),
      // The analytics service of the module reaches Firebase Analytics. The
      // test leaves out the other analytics services that the app may have.
      MatrixAppTest(
        '$analytics/firebase_analytics',
        appliesTo: _has(FirebaseAnalyticsModule.id),
        mocks: const MatrixMocks(
          'test/firebase_analytics_mocks.dart',
          'mockFirebaseAnalytics',
        ),
      ),
      // The first screen of an app with a router is logged once, under the
      // name of the screen that the app starts on (see _startScreenOf),
      // whichever module provides the router, which calls the listener of
      // the screen of Firebase Analytics: a test of the router role too, so
      // it finds the apps with a router by their roles.
      MatrixAppTest(
        '$analytics/screen_views',
        appliesTo: (app) =>
            _has(FirebaseAnalyticsModule.id)(app) &&
            app.hook!.presentRoles.contains(routerRole),
        values: (app) => {'start_screen': _startScreenOf(app)},
        roles: {routerRole},
      ),
      // The sign-in service of the module on Firebase Authentication: what
      // each of its calls sends to Firebase, with a password and with the
      // credentials of Google and Apple; the credential that Firebase gave
      // with a refused link, which the sign-in after it takes; the
      // revocation of the tokens of Apple before a deletion; the reason
      // that it gives each code of Firebase, in the form in which Android
      // and iOS send it; the user whom it finds on the device when it is
      // created; a call for a user whose session has ended on the server,
      // which signs that user out; and the language in which it asks
      // Firebase for the message of a password reset, the one that the app
      // is in (see _messageLanguagesOf). The tests use the service of the
      // module, and leave what every provider of the auth role does to the
      // test of the role. The mocks are a backend in memory with no account
      // and nobody signed in, which takes the test tokens of Google and
      // Apple, and the matrix sets them up for the tests of every module of
      // the app, since the start-up of the app starts the session of the
      // app on Firebase Authentication. Its probe compares, on a device, the
      // user of the session with the one that the Firebase SDK has there.
      MatrixAppTest(
        '$firebaseAuth/firebase_auth',
        appliesTo: _has(FirebaseAuthModule.id),
        devDependencies: const ['firebase_auth_platform_interface'],
        generatedFiles: _messageLanguagesOf,
        mocks: const MatrixMocks(
          'test/firebase_auth_mocks.dart',
          'mockFirebaseAuth',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/firebase_auth/probe.dart',
          'probeFirebaseAuth',
        ),
      ),
      // The way to sign in with Google of the module, on the real
      // google_sign_in package: the package is started once, without the
      // ids of the clients of Google, and the credential is the ID token of
      // the Google account; a closed sheet returns null, the errors with
      // which Google refuses an app that is not set up for it fail with
      // notConfigured, and any other error with unknown; and the app lists
      // it on Android and iOS, with the logo of Google from its assets. The
      // mocks replace the platform implementation of the package with
      // Google for one account, and the matrix sets them up for the tests
      // of every module of the app, such as the test of the ways to sign in
      // of the auth role. The test has no probe for the start check: nobody
      // can sign in on a device.
      MatrixAppTest(
        '$googleSignIn/google_sign_in',
        appliesTo: _has(GoogleSignInModule.id),
        devDependencies: const ['google_sign_in_platform_interface'],
        mocks: const MatrixMocks(
          'test/google_sign_in_mocks.dart',
          'mockGoogleSignIn',
        ),
      ),
      // The way to sign in with Apple of the module, on the real
      // sign_in_with_apple package: on iOS, the request has the SHA-256
      // hash of a new raw nonce, and the credential is the ID token of
      // Apple with that raw nonce, the authorization code of the request
      // and the name, which only the first sign-in has; a closed sheet
      // returns null, the unknown error of an app without the capability
      // fails with notConfigured, and any other error with unknown; on
      // another platform it fails with notConfigured without asking Apple;
      // and the app lists it on iOS only, with an icon in the colour of the
      // label. The mocks answer the method channel of the package as Apple
      // does on iOS, for one user and with the nonce of the request in the
      // ID token, and the matrix sets them up for the tests of every module
      // of the app, such as the test of the ways to sign in of the auth
      // role. The test has no probe for the start check: nobody can sign in
      // on a device.
      MatrixAppTest(
        '$appleSignIn/apple_sign_in',
        appliesTo: _has(AppleSignInModule.id),
        mocks: const MatrixMocks(
          'test/apple_sign_in_mocks.dart',
          'mockSignInWithApple',
        ),
      ),
      // The push service of the module on Firebase Cloud Messaging: what
      // each of its calls sends to Firebase, on Android and on iOS, such as
      // the presentation options of iOS, which let a notification show in
      // the foreground, and never a request for the permission to show
      // notifications; the address, which is the registration token, and
      // none where Firebase has none or fails; and a message in the
      // foreground, a tap, a new token and the message whose tap launched
      // the app, with the data of a message as texts, through the service
      // and through appPush. The tests use the service of the module, and
      // leave what every provider of the push role does to the test of the
      // role. The mocks are a device in memory with a registration token
      // that stays the same, and the matrix sets them up for the tests of
      // every module of the app, since the start-up of the app starts the
      // push messages. Its probe compares, on a device, the address of the
      // app with the token that the Firebase SDK has there, and then asks
      // the script of CI that started the app for a push message to that
      // address, the answer firebase_messaging, which CI gives the app with
      // Firebase on Android.
      MatrixAppTest(
        '$messaging/firebase_messaging',
        appliesTo: _has(FirebaseMessagingModule.id),
        mocks: const MatrixMocks(
          'test/firebase_messaging_mocks.dart',
          'mockFirebaseMessaging',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/firebase_messaging/probe.dart',
          'probeFirebaseMessaging',
          answer: 'firebase_messaging',
        ),
      ),
      // The purchases service of the module on RevenueCat: the key of .env
      // that a build takes, the key of the Test Store only in a debug build,
      // and no call of RevenueCat without a key or before RevenueCat is
      // configured; what each call sends to RevenueCat, on Android and on
      // iOS, and the reason that each code of RevenueCat gets, also a code
      // that is no number, and a cancel, which is no failure; the plans from
      // the current offering, with the intro offers that the user may take,
      // and the access from the entitlement premium; and a grant of the
      // backend, which reaches appPurchases once the cache of the customer
      // info is emptied. The tests use the service of the module, and leave
      // what every provider of the purchases role does to the tests of the
      // role. The mocks are RevenueCat, its backend and the store account of
      // a device in memory, which the matrix sets up for the tests of every
      // module of the app, since the start-up of the app starts the
      // purchases, and the matrix writes the keys of the tests into .env for
      // the platforms, with that of the Test Store empty, so that the
      // service is configured in every test of the app (see
      // _revenueCatKeysOf). Its probe compares, on a device, the access and
      // the plans of the app with what the RevenueCat SDK gives there, and
      // then asks the script of CI that started the app for premium access,
      // the answer revenuecat, which CI grants in the RevenueCat project of
      // CI to the apps that it starts without external services.
      MatrixAppTest(
        '$revenueCat/revenuecat',
        appliesTo: _has(RevenueCatModule.id),
        envValues: _revenueCatKeysOf,
        mocks: const MatrixMocks(
          'test/revenuecat_mocks.dart',
          'mockRevenueCat',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/revenuecat/probe.dart',
          'probeRevenueCat',
          answer: 'revenuecat',
        ),
      ),
      // The onboarding of the module: on its first launch, the app shows
      // it in place of the screen that it starts on (see
      // _startScreenFileOf), and the button of its last page or Skip saves
      // that it is finished and shows that screen; an app that finds it
      // finished goes straight there. The onboarding has its texts in each
      // language of the app, as the device asks for it (see
      // _onboardingTextsFileOf). The router
      // leaves the onboarding, whichever module provides it, as the router
      // role says of the guards of the routes: a test of the router role
      // too. The mocks finish the onboarding before the app starts, in
      // memory, and the matrix sets them up for the tests of every module
      // of the app, which expect the screens that the guard of the
      // onboarding would keep them from. Its probe goes through the
      // onboarding on a device, where a first launch finds nothing saved,
      // unless the onboarding is finished there. The test comes before the
      // walk of the routes in this list, whose probe then goes through the
      // routes of an app past its onboarding. For the route of the
      // onboarding, whose flow is over by then, the walk expects the screen
      // that the app starts on, or the target of a guard that does not
      // allow there. So on a device the start check leaves the app with the
      // onboarding finished.
      MatrixAppTest(
        '$onboarding/onboarding',
        appliesTo: _has(OnboardingModule.id),
        generatedFiles: (app, packageName) => {
          ..._startScreenFileOf(app, packageName),
          ..._onboardingTextsFileOf(app),
        },
        roles: {routerRole},
        mocks: const MatrixMocks(
          'test/onboarding_mocks.dart',
          'finishOnboarding',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/onboarding/probe.dart',
          'probeOnboarding',
        ),
      ),
      // The settings screen of the module. Its title is in the language of
      // the app: the test goes through the languages of the app that the
      // module has its title in, which the matrix writes from the
      // localization role of the app, English alone for an app without the
      // role. Below the title it shows the entries of the app in one
      // group, or, in an app without settings, a note for its developer
      // with the path of the file of the screen, which a tap copies. And
      // it has a back button only on top of another screen, where the
      // button leads back. For these, the matrix writes how many entries
      // the screen has and whether it is a destination of the main
      // navigation, where code cannot push it (see _settingsOfAppOf).
      MatrixAppTest(
        '$settings/settings',
        appliesTo: _has(SettingsModule.id),
        generatedFiles: (app, packageName) => {
          ..._settingsLanguagesOf(app, packageName),
          ..._settingsOfAppOf(app),
        },
      ),
      // The preferences of the module reach shared_preferences, and read
      // what it has when they are opened, lists in the form that each
      // platform returns them in. The mocks keep the platform side of the
      // package in memory, and the matrix sets them up for the tests of
      // every module of the app, since the start-up of the app opens the
      // preferences. Its probe opens the preferences again on a device,
      // where the platform side is the real one, and reads back what it
      // saved.
      MatrixAppTest(
        '$sharedPreferences/shared_preferences',
        appliesTo: _has(SharedPreferencesModule.id),
        devDependencies: const ['shared_preferences_platform_interface'],
        mocks: const MatrixMocks(
          'test/shared_preferences_mocks.dart',
          'mockSharedPreferences',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/shared_preferences/probe.dart',
          'probeSharedPreferences',
        ),
      ),
      // The notifications service of the module on
      // flutter_local_notifications: what each of its calls sends to the
      // plugin, on Android and on iOS, such as the channel of the app with a
      // high importance, the cancel of the scheduled notification of an id
      // that is shown, and an inexact alarm at a time in UTC; a request that
      // shows the question of the system, or opens the settings of the
      // system where the system shows none; and the taps on a notification,
      // the one that launched the app included, with the data of the
      // notification. The tests use the service of the module, and leave
      // what every provider of the notifications role does to the test of
      // the role. The mocks are a device in memory on which the app may not
      // show notifications and has not asked, and the matrix sets them up
      // for the tests of every module of the app, since the start-up of the
      // app opens the notifications. Its probe checks, on an Android
      // device, the channel of the app that the service created.
      MatrixAppTest(
        '$localNotifications/local_notifications',
        appliesTo: _has(LocalNotificationsModule.id),
        mocks: const MatrixMocks(
          'test/local_notifications_mocks.dart',
          'mockLocalNotifications',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/local_notifications/probe.dart',
          'probeLocalNotifications',
        ),
      ),
      // The start screen of the module, a welcome to the developer of the
      // app, wherever the app starts: it names the app, greets by the time
      // of the day and lists the next steps with their paths, with its
      // texts in each language of the app (see _homeTextsFileOf); a tap on
      // a step copies its path and says so; its parts come in once, at
      // once in an app that asks for less motion; and it fits a small
      // phone with a large text size. The tests go to the route of the
      // module through the navigation of the router role, so they hold in
      // an app that starts on another screen too.
      MatrixAppTest(
        '$home/home',
        appliesTo: _has(HomeModule.id),
        generatedFiles: (app, packageName) => _homeTextsFileOf(app),
      ),
      // The screens of sign-in of the module, in each mode of the auth
      // role, which the app has as a constant: an app that asks for an
      // account shows the sign-in on its first launch in place of the
      // screen that it starts on (see _signInOfAppOf), and an app that
      // everyone may use shows it once code asks for it; a sign-up, a
      // sign-in and a sign-out go through the session of the app, and an
      // anonymous user keeps the id with the account; the forms show what
      // is wrong with an email address and a password, the text of each
      // failure of a call in each language of the app, and that a call is
      // on its way; a password reset tells where the message went; and the
      // screens fit a small phone with a large text size. The sign-in and
      // the sign-up have a button for each way to sign in of the app that
      // works on the platform, from appSignInMethods of the auth role, which
      // signs in through the session with the mocks of the module of the way
      // to sign in, spins while its call is on its way and shows its failure
      // below the buttons, on Android and on iOS. The screen of
      // the account signs out and deletes the account, which it asks about
      // first in a sheet, with texts of its own for a deletion that the
      // provider refused, and the entry of the settings screen leads to
      // it, through the sign-in for a user without an account. For them
      // the matrix writes the settings screen of the app, whether it is a
      // destination of the main navigation, and the entry that the module
      // gave it, from the settings screen role and the layout role (see
      // _signInOfAppOf). The screens only change the session: the router
      // shows them and leaves them, whichever module provides it, as the
      // router role says of the guards of the routes and of the routes that
      // ask for a condition, so this is a test of the router role too.
      // The mocks sign a test account up before the app starts, through
      // the session, and the matrix sets them up for the tests of every
      // module of the app, which expect the screens that the guards of the
      // sign-in would keep them from. The test has no probe for the start
      // check: nobody can sign in on a device, and the walk of the routes
      // shows the screens there.
      MatrixAppTest(
        '$signIn/sign_in',
        appliesTo: _has(SignInModule.id),
        generatedFiles: _signInOfAppOf,
        roles: {routerRole},
        mocks: const MatrixMocks(
          'test/sign_in_mocks.dart',
          'signUpTestAccount',
        ),
      ),
      // The paywall of the module, over the purchases of the app,
      // whichever module provides them: a request for the screen of the
      // subscription, whose route needs premium access, opens the paywall
      // over the page, a restore that finds nothing says so, the close
      // button drops the request, and once the user bought a plan with the
      // mocks of the provider, the router closes the paywall and shows the
      // screen of the subscription; the paywall that code pushes closes the
      // same way. Over a service of the test, the paywall shows grey cards
      // while the plans load, a card for each plan with its price and its
      // intro offer, the button, what the plan costs after its trial and
      // the terms of the selected plan, the text of each failure, a busy
      // button, plans that are not available with a note for the developer,
      // also after a restore there, the link to the address of .env and the
      // key that has none (see _paywallLinksOf); the
      // screen of the subscription tells the plan and when it renews or
      // ends, opens the page of the store and closes once the access ends;
      // and the paywall fits a small phone with a large text size. For them
      // the matrix writes the screen that the app starts on, the settings
      // screen of the app with the entry of the module, if the app has one,
      // whether that screen is a destination of the main navigation, and
      // the texts of the module in each language of the app (see
      // _paywallOfAppOf). The router shows the paywall and closes it,
      // whichever module provides it, as the router role says of the routes
      // that ask for a condition, so this is a test of the router role too.
      // The mocks buy the first plan of the offer before the app starts,
      // through the purchases of the app, and the matrix sets them up for
      // the tests of every module of the app, which expect the screens that
      // the guard of premium access would keep them from. The test has no
      // probe for the start check: the walk of the routes shows the paywall
      // on a device, where nothing is bought.
      MatrixAppTest(
        '$paywall/paywall',
        appliesTo: _has(PaywallModule.id),
        devDependencies: const ['url_launcher_platform_interface'],
        envValues: _paywallLinksOf,
        generatedFiles: _paywallOfAppOf,
        roles: {routerRole},
        mocks: const MatrixMocks('test/paywall_mocks.dart', 'grantPremium'),
      ),
      // The step of the paywall module in the onboarding, in the apps with
      // the module and the onboarding screen role, whichever module
      // provides it: the list of the steps of the app has the step once, a
      // new onboarding screen shows it while the user has no premium access,
      // in each language of the app, and its button shows the paywall over
      // the onboarding. The close button and back close the paywall, and
      // once the user bought a plan with the mocks of the provider of
      // purchases, the step closes the paywall itself, since the router does
      // not know its route; each time the onboarding goes on, and the page
      // below it stays. Then a new onboarding screen leaves the step out.
      // For it the matrix writes the onboarding screen of the app (see
      // _paywallStepOf), and the texts of the step among those of the test
      // of the paywall, whose helpers it uses and which runs in every app
      // that this test runs in. The onboarding shows the step and goes on,
      // and the router leaves the routes without a page over its pages as
      // they are while the guard of premium access notifies, whichever
      // modules provide the two roles, so this is a test of both roles too.
      // It has no probe for the start check: nothing is bought on a device.
      MatrixAppTest(
        '$paywall/paywall_step',
        appliesTo: (app) =>
            app.modules.contains(PaywallModule.id) &&
            app.hook!.presentRoles.contains(onboardingScreenRole),
        generatedFiles: _paywallStepOf,
        roles: {routerRole, onboardingScreenRole},
      ),
      // The services of the apps whose modules register some in the DI
      // container, whichever module provides it.
      await diRoleAppTest(),
      // The events of the apps with the events role, whichever module
      // provides it.
      await eventsRoleAppTest(),
      // The preferences of the apps with the preferences role, whichever
      // module provides it.
      await preferencesRoleAppTest(),
      // The values of the apps with the env role whose modules give it
      // keys, whichever module provides it: each getter of AppEnv returns
      // the value that .env gives its key, and null for a key that .env
      // leaves empty. The values are those that the tests of the modules of
      // the app give their keys, such as those of the test of revenuecat.
      await envRoleAppTest(),
      // The sign-in of the apps with the auth role, whichever module
      // provides it, in the mode that the role chose for each: the service
      // of the provider keeps its contract, and the session of the app
      // does what the mode says.
      await authRoleAppTest(),
      // The ways to sign in of the apps whose modules give the auth role
      // one, whichever modules provide the role and the ways to sign in:
      // the service takes the credentials of identities of each issuer of
      // the app as the role says, and the session signs in with the
      // credential that the function of each way to sign in returns, under
      // the mocks of its module, in each mode of the role.
      await authMethodsAppTest(),
      // The notifications of the apps with the notifications role,
      // whichever module provides it: the permission follows what the
      // service says and what the app asked, a request asks once, the taps
      // of the app and of an owner go apart, a scheduled notification is
      // listed until it is cancelled or shown, and the next start keeps
      // what was scheduled and the permission.
      await notificationsRoleAppTest(),
      // The entry of the notifications on the settings screen of the apps
      // with the notifications role and the settings screen role, whichever
      // modules provide them: it shows whether the app may show
      // notifications in the language of the app, a tap asks while the app
      // has not asked and opens the settings of the system after that, and
      // the entry follows what the user changed there.
      await notificationsSettingAppTest(),
      // The step of the onboarding that asks for the permission to show
      // notifications, in the apps with the notifications role and the
      // onboarding screen role, whichever modules provide them: the
      // onboarding shows it only while the app has not asked, and its action
      // asks.
      await notificationsStepAppTest(),
      // The push messages of the apps with the push role, whichever module
      // provides it: the app follows the address of the service, shows a
      // message in the foreground where the platform does not, gives each
      // tap once, and the next start has the same address.
      await pushRoleAppTest(),
      // The purchases of the apps with the purchases role, whichever module
      // provides it: appPurchases over a scripted service and over the
      // service of the provider, the purchases of each user apart, and the
      // next start with what a user bought.
      await purchasesRoleAppTest(),
      // The purchases of the users of the session, in the apps with the
      // purchases role and the auth role, whichever modules provide them,
      // in each mode of the auth role.
      await purchasesSessionAppTest(),
      // The purchases of the user of the device at the next start, in the
      // apps with the purchases role and without the auth role.
      await purchasesDeviceAppTest(),
      // The entry that restores purchases on the settings screen of the
      // apps with the purchases role and the settings screen role,
      // whichever modules provide them: a tap restores once and shows what
      // the restore found in the language of the app, and the entry takes
      // no second tap while a restore is on its way.
      await purchasesSettingAppTest(),
      // The routes of the apps with a router, whichever module provides
      // it: the test starts the app and goes to each location that needs
      // no values.
      await routerWalkAppTest(),
      // The settings screen of the apps with the settings screen role,
      // whichever module provides it: the route that the provider names
      // shows the screen, and the screen shows every entry that the
      // modules of the app give the role once, one below the other in the
      // order of the role.
      MatrixAppTest(
        '$cli/settings_screen_role',
        appliesTo: (app) => app.hook!.presentRoles.contains(settingsScreenRole),
        generatedFiles: _settingsOf,
        roles: {settingsScreenRole},
      ),
      // The theme mode of the apps with the theme role, whichever module
      // provides it: the root of the app takes the mode that is chosen, and
      // the screen below it gets the light or the dark theme of the
      // provider; a choice is saved under the key of the role; and the next
      // start has the mode that is saved. A test of the app entry role too,
      // whose provider builds the root.
      await themeRoleAppTest(),
      // The entry of the theme mode on the settings screen, in the apps
      // with the theme role and the settings screen role, whichever modules
      // provide them: the screen shows the entry, which shows the mode of
      // the app, also one that other code chose, and a tap on a mode
      // chooses it.
      MatrixAppTest(
        '$cli/theme_setting',
        appliesTo: (app) => app.hook!.presentRoles
            .containsAll(const [themeRole, settingsScreenRole]),
        values: _themeValuesOf,
        generatedFiles: _themeSettingOf,
        roles: {themeRole},
      ),
      // The languages and the texts of the apps with the localization
      // role, whichever module provides it: the root supports the languages
      // of the app, with a delegate of each kind for each of them, the app
      // and its texts follow the language that the user chose, and the
      // choice is saved and restored. Its probe goes through the languages
      // on a device.
      await localizationRoleAppTest(),
      // The flavor of a running app, whichever module provides the app
      // entry: a command without --flavor builds the default flavor of the
      // role, which only a run of the flutter tool shows. Its probe sees on
      // a device the flavor that the build asked for: the default flavor in
      // the debug start of CI, and the one for a release in its release
      // start. Only in the apps with every module, which run flutter test
      // for other tests already.
      await flavorsAppTest(among: (app) => app.everyModuleWith != null),
      // The setting of the language on the settings screen of the apps
      // with the localization role and the settings screen role, whichever
      // modules provide them: its sheet chooses a language of the app,
      // which the app is then in and remembers, or the languages of the
      // device.
      await languageSettingAppTest(),
      // The native projects of the apps with the app icon role, whichever
      // module provides it, once the step of the provider has run: an image
      // for each density and an adaptive icon on Android, and on iOS an icon
      // set for each name of the build configurations, whose icon for the
      // App Store has no alpha and the pixels of the source.
      MatrixAppTest(
        '$cli/app_icon_role',
        appliesTo: (app) => app.hook!.presentRoles.contains(appIconRole),
        devDependencies: const ['xml'],
        values: (_) => const {
          'image_file': AppIconRole.imageFile,
          'foreground_file': AppIconRole.foregroundFile,
          'android_manifest_file': AppEntryRole.androidManifestFile,
          'xcode_project_file': AppEntryRole.xcodeProjectFile,
        },
        roles: {appIconRole},
      ),
      // What the real flutter_launcher_icons leaves in the Xcode project,
      // with the script of the module: the setting that it damages is back,
      // and one icon has every build configuration. A later version of the
      // tool that damages another line fails here.
      MatrixAppTest(
        '$launcherIcons/launcher_icons',
        appliesTo: _has(LauncherIconsModule.id),
        values: (_) => const {
          'xcode_project_file': AppEntryRole.xcodeProjectFile,
        },
      ),
    ],
    // Each provider of the router role gets a test of the listeners of the
    // screen, the fixture registry tests the rest of the role, and each
    // provider of the DI role, of the events role, of the preferences
    // role, of the env role, of the auth role, of the notifications role,
    // of the push role, of the purchases role, of the settings screen role,
    // of the theme role, of the localization role and of the app icon role
    // gets the tests of its role. Each provider of the app entry role gets
    // the test of the theme role, which checks that its root rebuilds.
    testedRoles: {
      routerRole,
      diRole,
      eventsRole,
      preferencesRole,
      envRole,
      authRole,
      notificationsRole,
      pushRole,
      purchasesRole,
      settingsScreenRole,
      themeRole,
      appEntryRole,
      localizationRole,
      appIconRole,
    },
  );
}

/// The test of the events role that the CLI keeps in its
/// `app_tests/events_role`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them: once the start-up of
/// the app ran, every listener of a type gets each event of that type once,
/// in the order the events were fired; a listener of another type gets none
/// of them, and no error; an event fired before the stream of `on<T>()` is
/// listened to is not in it, even after `on<T>()` returned the stream; and a
/// cancelled subscription gets no more events.
///
/// The test knows only the role and fires events of its own through
/// `createCommunicationService()` of the role. The matrix of the fixtures
/// runs it too, only in the apps with every module, which run other tests
/// already.
Future<MatrixAppTest> eventsRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/events_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(eventsRole) &&
          (among?.call(app) ?? true),
      roles: {eventsRole},
    );

/// The test of the preferences role that the CLI keeps in its
/// `app_tests/preferences_role`, for the apps with the role, whichever
/// module provides it, that [among] accepts, or all of them: once the
/// start-up of the app opened the preferences, a value of each type is read
/// back as it was saved, and as `null` by the reads of the other types,
/// which do not throw; a key that was removed has no value; a write
/// replaces what its key had, a value of another type too; the preferences
/// keep a copy of a list that they are given, and a read returns a copy of
/// it; and the next start, `initPreferences()` again, reads what was saved
/// and nothing that was removed.
///
/// The test knows only the role, and writes keys of its own. Its probe,
/// `probePreferences()` of `integration_test/preferences_role/probe.dart`,
/// runs the checks of one run on a device for the start check, where the
/// platform side of the provider is the real one, and the test runs the
/// probe too. The matrix of the fixtures runs the test only in its apps
/// with every module, which run other tests already.
Future<MatrixAppTest> preferencesRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/preferences_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(preferencesRole) &&
          (among?.call(app) ?? true),
      roles: {preferencesRole},
      startProbe: const MatrixStartProbe(
        'integration_test/preferences_role/probe.dart',
        'probePreferences',
      ),
    );

/// The test of the localization role that the CLI keeps in its
/// `app_tests/localization_role`, for the apps with the role, whichever
/// module provides it, that [among] accepts, or all of them: the root of
/// the app supports the languages of the app and no other, and has, for
/// each of them, a delegate of each kind of localizations that supports
/// it; once the user chose a language, the app is in it, and each text of
/// the app reads in it, or in English when it has no translation into it;
/// while the user chose none, the app and its texts are in the language
/// that the device prefers among those of the app; a choice is saved under
/// [LocalizationRole.localeKey], and removed when the app follows the
/// device again; and the next start, `initPreferences()` again, restores
/// the language that was saved.
///
/// The test knows only the role. The matrix writes the languages and the
/// texts of each app for it, from the data of its localization role, into
/// [languagesAndTextsFile], next to the probe of the test in
/// `integration_test/localization_role/probe.dart`, `probeLanguages()`. On
/// a device, for the start check, the probe checks the texts in the
/// language that it finds, goes through the first languages of the app, at
/// most [languagesProbeLimit], and puts back the choice that it found. The
/// matrix of the fixtures runs the test only in its apps with every module,
/// which run other tests already.
Future<MatrixAppTest> localizationRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/localization_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(localizationRole) &&
          (among?.call(app) ?? true),
      generatedFiles: _languagesAndTextsOf,
      roles: {localizationRole},
      startProbe: const MatrixStartProbe(
        'integration_test/localization_role/probe.dart',
        'probeLanguages',
      ),
    );

/// The path in an app of the languages and the texts of the app, which the
/// matrix writes for the test of the localization role: `appLanguages`, the
/// codes of the languages that the role chose, in their order;
/// `probedLanguages`, the first of them, at most [languagesProbeLimit],
/// which the probe of the role goes through on a device;
/// `savedLanguageKey`, the key of the role in the preferences of the app
/// ([LocalizationRole.localeKey]); and `appTextChecks`, the texts of the
/// app in the order of the role ([LocalizationRole.textsIn]), each with its
/// name, such as `text title of the module settings`, a function that reads
/// it through `context.l10n` of the role, and what it reads in each
/// language of the app: its translation, or its English text.
const languagesAndTextsFile = 'integration_test/localization_role/texts.dart';

/// The most languages that the probe of the test of the localization role
/// goes through on a device, the first of the app: for each, the screen
/// settles once, and the probes of an app share a minute.
const languagesProbeLimit = 10;

/// The file at [languagesAndTextsFile] of [app], an app of the matrix with
/// the localization role, whose package is [packageName].
///
/// It imports the file of the texts of the role only in an app with texts,
/// where it reads them.
Map<String, String> _languagesAndTextsOf(MatrixApp app, String packageName) {
  final input = localizationRole.hookInput(app.hook!);
  final languages = localizationRole.localesIn(input);
  final checks = StringBuffer();
  for (final text in localizationRole.textsIn(input)) {
    checks
      ..writeln('  (')
      ..writeln('    name: ${SmfNames.dartString('$text')},')
      ..writeln('    read: (context) => context.l10n.${text.getter},')
      ..writeln('    expected: {');
    for (final language in languages) {
      final expected = text.text.textIn(language) ?? text.text.en;
      checks.writeln(
        "      '$language': ${SmfNames.dartString(expected)},",
      );
    }
    checks
      ..writeln('    },')
      ..writeln('  ),');
  }
  final texts = LocalizationRole.appTexts.importRef.resolveUri(packageName);
  final imports = [
    "import 'package:flutter/widgets.dart';",
    if (checks.isNotEmpty) "import '$texts';",
  ];
  String codesOf(Iterable<String> languages) =>
      [for (final language in languages) "'$language'"].join(', ');
  final key = SmfNames.dartString(LocalizationRole.localeKey);
  final list = checks.isEmpty
      ? 'const List<AppTextCheck> appTextChecks = [];'
      : 'final List<AppTextCheck> appTextChecks = [\n$checks];';
  return {
    languagesAndTextsFile: '''
// The languages and the texts of the app, and the key of the language that
// the user chose, which the matrix of SMF writes from the data of the
// localization role of the app for the tests of the role, in
// test/localization_role, and their probe.
${imports.join('\n')}

/// The codes of the languages of the app, in their order.
const List<String> appLanguages = [${codesOf(languages)}];

/// The codes of the languages that the probe of the role goes through on a
/// device: the first of the app, at most $languagesProbeLimit.
const List<String> probedLanguages = [${codesOf(languages.take(languagesProbeLimit))}];

/// The key of the preferences of the app under which the app saves the
/// language that the user chose, as the localization role has it.
const String savedLanguageKey = $key;

/// A text of the app: its name, a function that reads it at a context below
/// the root of the app, and what it reads in each language of the app, by
/// the code of the language.
typedef AppTextCheck = ({
  String name,
  String Function(BuildContext context) read,
  Map<String, String> expected,
});

/// The texts of the app, in the order of the localization role.
$list
''',
  };
}

/// The test of the setting of the language, the entry that the template of
/// the localization role gives the settings screen, which the CLI keeps in
/// its `app_tests/language_setting`, for the apps with the localization
/// role and the settings screen role, whichever modules provide them. On
/// the settings screen, the setting shows its title and, as the value of
/// its row, the choice of the user, the languages of the device while the
/// user chose none. A tap opens a sheet over the main navigation of the
/// app, with an option for the languages of the device and one for each
/// language of the app, by its name in that language, or its code, with
/// the chosen one selected and checked. A tap on an option closes the
/// sheet: the app and the texts of the setting are in the language of the
/// option, which is saved under [LocalizationRole.localeKey], and the
/// option of the device removes what was saved. On a small phone with a
/// large text size, the choice is below the title of the setting, and the
/// sheet scrolls. A second file of the test starts the app on a device
/// that prefers the last language of the app: the app and the setting
/// follow the device, the setting names a choice of that same language
/// that code makes, the next start restores the language that was saved,
/// and the sheet has no option but those of the app and of the device.
///
/// The test knows only the two roles. The matrix writes the widget of the
/// entry for it into [languageSettingFile], from the entries of the
/// settings screen role of the app, with the labels of the languages of the
/// app and the texts of the setting in each of them, from the localization
/// role. It opens the settings screen with the helper of the tests of the
/// settings screen role that the CLI keeps, which every app with the
/// settings screen role has too.
Future<MatrixAppTest> languageSettingAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/language_setting',
      appliesTo: (app) => app.hook!.presentRoles
          .containsAll({localizationRole, settingsScreenRole}),
      generatedFiles: _languageSettingOf,
      roles: {localizationRole},
    );

/// The path in an app of what the matrix writes for the test of the setting
/// of the language: `languageSetting`, the type of the widget of the entry
/// that the template of the localization role gives the settings screen
/// role; `savedLanguageKey`, the key of the role in the preferences of the
/// app ([LocalizationRole.localeKey]); `languageLabels`, what the setting
/// shows for each language of the app, by the code of the language, its
/// name in that language ([LocalizationRole.languageNames]) or its code;
/// and `settingTitles` and `deviceOptions`, the title of the setting and
/// its option of the languages of the device in each language of the app.
const languageSettingFile = 'test/language_setting/setting.dart';

/// The file at [languageSettingFile] of [app], an app of the matrix with
/// the localization role and the settings screen role, whose package is
/// [packageName].
///
/// It imports the file of the entry with the prefix `entry`. The entry is
/// the one of the settings screen role whose widget is in
/// [LocalizationRole.languageSettingFile]. Throws a [StateError] if the
/// role has no such entry, which the template of the localization role
/// gives it in every app with both roles.
Map<String, String> _languageSettingOf(MatrixApp app, String packageName) {
  final languages =
      localizationRole.localesIn(localizationRole.hookInput(app.hook!));
  final entries = [
    for (final entry in settingsScreenRole
        .entriesIn(settingsScreenRole.hookInput(app.hook!)))
      if (entry.file == LocalizationRole.languageSettingFile) entry,
  ];
  if (entries.length != 1) {
    throw StateError(
      'The settings screen of ${app.name} has ${entries.length} entries in '
      '${LocalizationRole.languageSettingFile}, the file of the setting of '
      'the language, rather than one.',
    );
  }
  final widget = entries.single.widget;
  String byLanguage(String Function(String language) text) => [
        for (final language in languages)
          "  '$language': ${SmfNames.dartString(text(language))},\n",
      ].join();
  String Function(String language) textOf(LocalizedText text) =>
      (language) => text.textIn(language) ?? text.en;
  final key = SmfNames.dartString(LocalizationRole.localeKey);
  final labels = byLanguage(
    (language) => LocalizationRole.languageNames[language] ?? language,
  );
  final titles = byLanguage(textOf(LocalizationRole.languageSettingTitle));
  final ofDevice = byLanguage(textOf(LocalizationRole.languageOfDevice));
  return {
    languageSettingFile: '''
// The setting of the language of the app, which the matrix of SMF writes
// from the data of the settings screen role and of the localization role
// of the app for the test of the setting, language_setting_test.dart.
import '${widget.import!.resolveUri(packageName)}' as entry;

/// The type of the widget of the setting, an entry of the settings screen.
const Type languageSetting = ${widget.codeWith('entry')};

/// The key of the preferences of the app under which the app saves the
/// language that the user chose, as the localization role has it.
const String savedLanguageKey = $key;

/// What the setting shows for each language of the app, by the code of the
/// language: its name in that language, or its code.
const Map<String, String> languageLabels = {
$labels};

/// The title of the setting in each language of the app, by the code of
/// the language.
const Map<String, String> settingTitles = {
$titles};

/// The option of the setting with which the app follows the languages of
/// the device, in each language of the app, by the code of the language.
const Map<String, String> deviceOptions = {
$ofDevice};
''',
  };
}

/// The test of the auth role that the CLI keeps in its
/// `app_tests/auth_role`, for the apps with the role, whichever module
/// provides it, in each mode of the role. Each of its five files runs the
/// start-up of the app once, with `bootstrap()`:
/// - the service of the provider keeps the contract of `AuthService`, the
///   same in every mode. When a call completes, the user of the service is
///   its result; signing up creates an account, whose user has the same id
///   each time; a wrong password and an address without an account fail
///   alike; a call that fails leaves whoever is signed in; the user of a
///   call replaces the user who was signed in; each anonymous user has an
///   id of its own, and keeps it with an account; deleting removes the
///   account; a call for the user who is signed in fails when nobody is;
///   and the stream of the changes tells every listener of each change,
///   once the user has changed;
/// - the session of the app does what the mode of the app says: the app is
///   in the mode that the role chose, and without an account nobody uses it
///   in the modes `required` and `guest`, and an anonymous user in the mode
///   `anonymous`, who keeps the id with an account. The session follows a
///   change that none of its calls made, and only an app in the mode
///   `anonymous` signs a user in when the user comes back to it;
/// - the next start, `initAuth()` again, has the user of the device as soon
///   as it is over, after a sign-up, a sign-in and a link, and so has a
///   session of the test that never had a user; a start that finds nobody
///   has nobody, and in the mode `anonymous` a new anonymous user, also
///   after a deletion; and the account of a user whom a start found can be
///   deleted, at the latest once the user has signed in again;
/// - an account that is signed up before the app starts is signed in when
///   the start-up is over, as the mocks of a module with a guard that asks
///   for an account rely on;
/// - the token of the user: nobody has none, the user of an account and an
///   anonymous user each have one, a forced refresh gives another one with
///   the same user, and a read tells nobody of a change. The session gives
///   the token of its user, refreshes a token that a server refused once for
///   all the reads at the same time and for those that come later, and the
///   next start has a token for the user of the device.
///
/// The test knows only the role. The matrix fills in the mode of each app,
/// which the test expects the app to be in: the choice of the role
/// ([AuthRole.modeIn]), which an app that got no value of
/// [AuthRole.modeOption] has too. So the same files hold in an app of every
/// mode, and the test applies to every app with the role. No file expects
/// anything of who is signed in right after the start-up, since the mocks
/// of a module of the app may have signed a user up before it: each test
/// signs out first and uses email addresses of its own. It has no probe for
/// the start check: nobody can sign in on a device.
Future<MatrixAppTest> authRoleAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/auth_role',
      appliesTo: (app) => app.hook!.presentRoles.contains(authRole),
      values: (app) => {
        'auth_mode': authRole.modeIn(authRole.hookInput(app.hook!)).name,
      },
      roles: {authRole},
    );

/// The test of the ways to sign in of the auth role that the CLI keeps in
/// its `app_tests/auth_methods`, for the apps whose modules give the role a
/// way to sign in with an identity provider ([AuthRole.methodsIn]),
/// whichever modules provide the role and the ways to sign in, in each mode
/// of the role. Each of its two files runs the start-up of the app once,
/// with `bootstrap()`:
/// - the service of the provider keeps the contract of `AuthService` for
///   credentials, with each issuer of the ways to sign in of the app:
///   signing in with the credential of a new identity creates its user,
///   whom signing in with it again finds, in place of whoever is signed in;
///   `linkWith` gives the anonymous user who is signed in the identity with
///   the same id; `linkWith` of an identity that another user has fails
///   with `credentialInUse`, and `signInWith` takes the identical credential
///   then; for an identity whose email address has an account that signs
///   in with a password, `linkWith` fails with
///   `accountExistsWithOtherMethod`, and `signInWith` fails so too or signs
///   in to that account; a call for the user who is signed in fails when
///   nobody is; and `deleteAccount` with a fresh credential deletes the user
///   whom a start found on the device, and one of another user fails with
///   `invalidCredentials`;
/// - the session of the app signs in with the credential that the function
///   of each way to sign in returns, on a platform that the way to sign in
///   works on: an anonymous user gets the identity and keeps the id, a
///   later anonymous user and a sign-in without a user sign in to the
///   account of that identity, and once the next start found that account
///   on the device, `appSession.deleteAccount()` deletes it, for a way to
///   sign in with `revokesOnDeletion` with a credential that it asks the
///   way to sign in for again, after which the identity has another user.
///
/// The test knows only the role, and reads the ways to sign in of the app
/// from `appSignInMethods`, which the template of the role generates, so the
/// matrix writes no file for it. It builds test tokens of identities of its
/// own for each issuer: JSON Web Tokens without a signature, whose payload
/// has `iss`, `sub`, maybe `email`, and a `nonce` of its own, which is the
/// `rawNonce` of the credential. A credential of the issuer of a way to sign
/// in with `revokesOnDeletion` has an `authorizationCode` of its own too. A
/// token with a nonce may be taken once, so each call gets a credential of
/// its own, but for the sign-in with the identical object that `linkWith`
/// refused just before. The mocks of the module of a way to sign in issue
/// test tokens too, of one identity of their own and the same each time,
/// each with the nonce of its request: the raw nonce, or the SHA-256 hash
/// of that raw nonce for a way to sign in whose request has the hash, as
/// Sign in with Apple, and none for a request without a nonce, as that of
/// Google sign-in. A provider takes each form in the tests of an app,
/// whatever the issuer. It uses the helpers of the test of the auth role
/// ([authRoleAppTest]), which every app with the role has. It has no probe
/// for the start check: nobody can sign in on a device.
Future<MatrixAppTest> authMethodsAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/auth_methods',
      appliesTo: (app) {
        final hook = app.hook!;
        return hook.presentRoles.contains(authRole) &&
            authRole.methodsIn(authRole.hookInput(hook)).isNotEmpty;
      },
      roles: {authRole},
    );

/// The test of the notifications role that the CLI keeps in its
/// `app_tests/notifications_role`, for the apps with the role, whichever
/// module provides it, that [among] accepts, or all of them:
/// - `appNotifications`, over a service of the test that scripts what a
///   provider answers: the permission follows what the service says, and
///   is denied once the app asked, which the preferences remember under
///   [NotificationsRole.askedKey]; a request asks the user only while the
///   app may not show notifications, once for two requests at once, and the
///   app saves that it asked only once the user answered; on a system
///   without a question, the request opens its settings, and the
///   app sees what the user did there once the user comes back; each tap
///   on a notification of the app reaches every listener of the taps, and
///   a tap on a notification of an owner reaches only that owner; and an
///   id that the app does not take, or a time that passed, never reaches
///   the service;
/// - `appNotifications` over the service of the provider: the app starts
///   as on a first launch, as the role asks of the mocks of a provider, and
///   `show()` and `schedule()` complete without the permission; one request
///   turns the notifications on, and `openSettings()` completes; a
///   scheduled notification is listed with what it has until it is
///   cancelled or a notification of its id is shown, and one scheduled with
///   its id takes its place; a notification of an owner, with a negative
///   id, keeps its data
///   and takes the place of no notification of the app; and the service
///   tells of the taps on a broadcast stream;
/// - the next start, `initNotifications()` again, keeps the notifications
///   that the app scheduled and the permission that the user gave, and
///   `initPreferences()` again the permission denied once the app asked.
///
/// The test knows only the role. The matrix fills in the key, which the
/// role publishes. Its probe, `probeNotifications()` of
/// `integration_test/notifications_role/probe.dart`, only reads, for the
/// start check on a device: the permission of the app agrees with the
/// service, the service lists the scheduled notifications, and the app has
/// no tap that launched it. The test runs the probe too.
Future<MatrixAppTest> notificationsRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/notifications_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(notificationsRole) &&
          (among?.call(app) ?? true),
      values: _notificationsValuesOf,
      roles: {notificationsRole},
      startProbe: const MatrixStartProbe(
        'integration_test/notifications_role/probe.dart',
        'probeNotifications',
      ),
    );

/// The values of the files of the test of the notifications role, the same
/// in every app: `asked_key`, the key under which the app remembers that it
/// asked for the permission, as the role publishes it.
Map<String, String> _notificationsValuesOf(MatrixApp app) =>
    const {'asked_key': NotificationsRole.askedKey};

/// The test of the entry of the notifications on the settings screen, which
/// the template of the notifications role contributes, that the CLI keeps in
/// its `app_tests/notifications_setting`, for the apps with the
/// notifications role and the settings screen role, whichever modules
/// provide them:
/// - the settings screen shows the entry once, with its title and whether
///   the app may show notifications, Off or On, in each language of the
///   app; a tap on a first launch asks for the permission through the
///   provider, whose mocks grant it, and the entry shows On; and on a small
///   phone with a large text size, once the list of the screen scrolled to
///   the entry, the state is below the title, and the texts stay in the row
///   of the entry;
/// - over a service of the test that scripts what a provider answers: a tap
///   asks the user while the app has not asked, once, and the entry shows
///   what the user answered; once the app asked, or while it may show
///   notifications, a tap opens the settings of the system and asks
///   nothing; and the entry follows what the user changed there once the
///   user comes back to the app.
///
/// The test knows only the two roles. The matrix writes the type of the
/// widget of the entry for it into [notificationsSettingFile], from the
/// entries of the settings screen role of the app, with the texts of the
/// entry in each language of the app, from the localization role. It opens
/// the settings screen with the helper of the tests of the settings screen
/// role, and takes the service of the test from the files of the test of the
/// notifications role, which runs in every app that this test runs in. It
/// has no probe for the start check: a tap would show the question of the
/// system on a device, and the walk of the routes goes to the settings
/// screen there.
Future<MatrixAppTest> notificationsSettingAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/notifications_setting',
      appliesTo: (app) => app.hook!.presentRoles
          .containsAll({notificationsRole, settingsScreenRole}),
      generatedFiles: _notificationsSettingOf,
      roles: {notificationsRole},
    );

/// The path in an app of what the matrix writes for the test of the entry
/// of the notifications on the settings screen: `notificationsSetting`, the
/// type of the widget of the entry that the template of the notifications
/// role gives the settings screen role, and `settingTexts`, the texts of the
/// entry in each language of the app, by the code of the language: its
/// title ([NotificationsRole.settingTitle]) and what it shows while the app
/// may show notifications and while it may not
/// ([NotificationsRole.settingOn] and [NotificationsRole.settingOff]). The
/// languages are those of the localization role of the app
/// ([LocalizationRole.localesIn]), in its order, and English alone in an
/// app without the role, whose entry has the English texts.
const notificationsSettingFile = 'test/notifications_setting/setting.dart';

/// The file at [notificationsSettingFile] of [app], an app of the matrix
/// with the notifications role and the settings screen role, whose package
/// is [packageName].
///
/// It imports the file of the entry with the prefix `entry`. A text without
/// a translation into a language of the app is the English one there, as
/// the localization role says of the texts of an app. Throws a
/// [StateError] if the template of the notifications role gives the
/// settings screen no entry or more than one: the test taps one entry.
Map<String, String> _notificationsSettingOf(
  MatrixApp app,
  String packageName,
) {
  final hook = app.hook!;
  final entries = [
    for (final RoleData(:value, :origin)
        in settingsScreenRole.hookInput(hook).data)
      if (value is SettingsEntry &&
          origin == const RoleTemplateOrigin(notificationsRole))
        value,
  ];
  if (entries.length != 1) {
    throw StateError(
      'The template of the $notificationsRole gives the settings screen of '
      '${app.name} ${entries.length} entries, rather than the entry of the '
      'notifications alone.',
    );
  }
  final widget = entries.single.widget;
  final languages = hook.presentRoles.contains(localizationRole)
      ? localizationRole.localesIn(localizationRole.hookInput(hook))
      : const ['en'];
  String textOf(LocalizedText text, String language) =>
      SmfNames.dartString(text.textIn(language) ?? text.en);
  final texts = StringBuffer();
  for (final language in languages) {
    final fields = [
      'title: ${textOf(NotificationsRole.settingTitle, language)}',
      'on: ${textOf(NotificationsRole.settingOn, language)}',
      'off: ${textOf(NotificationsRole.settingOff, language)}',
    ];
    texts.writeln(
      '  ${SmfNames.dartString(language)}: (${fields.join(', ')}),',
    );
  }
  return {
    notificationsSettingFile: '''
// The entry of the notifications on the settings screen and its texts,
// which the matrix of SMF writes from the data of the settings screen role
// and of the localization role of the app for the tests of the entry, in
// test/notifications_setting.
import '${widget.import!.resolveUri(packageName)}' as entry;

/// The type of the widget of the entry of the notifications, an entry of the
/// settings screen.
const Type notificationsSetting = ${widget.codeWith('entry')};

/// The texts of the entry in one language: its title, and what it shows
/// while the app may show notifications and while it may not.
typedef SettingTexts = ({String title, String on, String off});

/// The texts of the entry by the code of each language of the app, the first
/// of which the app uses when the device asks for none of them. An app
/// without the localization role has the English texts alone.
const Map<String, SettingTexts> settingTexts = {
$texts};
''',
  };
}

/// The test of the step of the onboarding that asks for the permission to
/// show notifications, which the template of the notifications role gives
/// the onboarding screen role, that the CLI keeps in its
/// `app_tests/notifications_step`, for the apps with the notifications role
/// and the onboarding screen role, whichever modules provide them, that
/// [among] accepts, or all of them. Its file runs the start-up of the app
/// once, with `bootstrap()`:
/// - on a first launch, the condition of the step holds, so the onboarding
///   shows it, and its action asks for the permission through the provider,
///   whose mocks grant it; then the condition holds no more;
/// - over a service of the test that scripts what a provider answers: the
///   condition holds only while the app may not show notifications and has
///   not asked, and reads the permission without a call of the service; the
///   action makes one request and no other call, after a no and on a system
///   without a question, whose request opens its settings, and while the app
///   may show notifications it asks the user nothing; once the app asked,
///   whatever the user answered, the condition holds no more, also at the
///   next start;
/// - the list of the steps of the onboarding of the app has the step once,
///   with those two functions.
///
/// The page of the step is for the test of the onboarding screen role, which
/// checks how a provider of the onboarding shows any step. The test knows
/// only the two roles. The matrix writes the two functions of the step for
/// it into [notificationsStepFile], from the data of the onboarding screen
/// role of the app, and the test takes the service of the test from the
/// files of the test of the notifications role, which runs in every app
/// that this test runs in. It has no probe for the start check: the action
/// would show the question of the system on a device. The matrix of the
/// fixtures runs it only in its apps with every module, which run other
/// tests already.
Future<MatrixAppTest> notificationsStepAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/notifications_step',
      appliesTo: (app) =>
          app.hook!.presentRoles
              .containsAll({notificationsRole, onboardingScreenRole}) &&
          (among?.call(app) ?? true),
      generatedFiles: _notificationsStepOf,
      roles: {notificationsRole},
    );

/// The path in an app of what the matrix writes for the test of the step of
/// the onboarding that asks for the permission to show notifications:
/// `stepShows`, the function that says whether the onboarding shows the step
/// ([OnboardingStep.showIf]), and `stepAction`, the function that its button
/// calls ([OnboardingStep.run]), both of the step [NotificationsRole.stepName]
/// that the template of the notifications role gives the onboarding screen
/// role ([OnboardingScreenRole.stepsIn]).
const notificationsStepFile = 'test/notifications_step/step.dart';

/// The file at [notificationsStepFile] of [app], an app of the matrix with
/// the notifications role and the onboarding screen role, whose package is
/// [packageName].
///
/// It imports the file of each function of the step once, with a prefix of
/// its own, `step0`, `step1`, .... Throws a [StateError] unless the template
/// of the notifications role gives the onboarding one step
/// [NotificationsRole.stepName] with a condition, as it does in every app
/// with both roles.
Map<String, String> _notificationsStepOf(MatrixApp app, String packageName) {
  final steps = [
    for (final placed in onboardingScreenRole
        .stepsIn(onboardingScreenRole.hookInput(app.hook!)))
      if (placed.owner == const RoleTemplateOrigin(notificationsRole) &&
          placed.step.name == NotificationsRole.stepName)
        placed.step,
  ];
  if (steps.length != 1) {
    throw StateError(
      'The template of the $notificationsRole gives the onboarding of '
      '${app.name} ${steps.length} steps "${NotificationsRole.stepName}", '
      'rather than one.',
    );
  }
  final showIf = steps.single.showIf;
  if (showIf == null) {
    throw StateError(
      'The step "${NotificationsRole.stepName}" that the template of the '
      '$notificationsRole gives the onboarding of ${app.name} has no '
      'condition.',
    );
  }
  final prefixes = <String, String>{};
  String codeOf(FunctionRef function) => function.codeWith(
        prefixes.putIfAbsent(
          function.import.resolveUri(packageName),
          () => 'step${prefixes.length}',
        ),
      );
  final shows = codeOf(showIf);
  final action = codeOf(steps.single.run);
  final imports = [
    "import 'package:flutter/widgets.dart';",
    for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    notificationsStepFile: '''
// The functions of the step of the onboarding that asks for the permission
// to show notifications, which the matrix of SMF writes from the data of the
// onboarding screen role of the app for the test of the step,
// notifications_step_test.dart.
${imports.join('\n')}

/// Whether the onboarding shows the step: its condition, which the
/// onboarding asks each time it shows.
const bool Function() stepShows = $shows;

/// What the button of the step does: its action, which asks for the
/// permission, for the context of the onboarding screen.
const Future<void> Function(BuildContext context) stepAction = $action;
''',
  };
}

/// The test of the push role that the CLI keeps in its `app_tests/push_role`,
/// for the apps with the role, whichever module provides it, that [among]
/// accepts, or all of them:
/// - `appPush`, over a service of push messages of the test that scripts
///   what a provider answers: the address is `null` until the service gives
///   one, follows each address that the service tells of, the first one
///   after none too, and is asked for again when the user comes back while
///   the app has none; each message in the foreground reaches every
///   listener of the messages once; where the platform does not show a
///   message, the app shows each one with a title or a body as one
///   notification whose owner is the role, through a service of
///   notifications of the test, and a tap on it reaches `appPush.taps` and
///   not `appNotifications.taps`; where the platform shows it, the app
///   shows none, and the taps of the service reach `appPush.taps`; and the
///   message whose tap launched the app is the launch message, whether the
///   platform or the app showed it, and not among the taps;
/// - `appPush` over the service of the provider: the app gets the address
///   that the provider gives, which the mocks of a provider give the device
///   as the role asks, an app that the test launched has no launch message,
///   the service tells of the messages, the taps and the addresses on
///   broadcast streams, and the provider never asks for the permission to
///   show notifications through the notifications of the app, while a
///   request through its own SDK is for the tests of its module; the probe
///   reports an app with a launch message and an address that the service
///   does not give, and never the address;
/// - the next start, `initPush()` again, creates a service that has the
///   address that the device kept.
///
/// The test knows only the role, and the notifications role that it
/// requires. The matrix fills in the owner of the notifications that show
/// messages, the id of the role. Its probe, `probePush()` of
/// `integration_test/push_role/probe.dart`, only reads, for the start check
/// on a device: the app has no launch message, and once it has an address,
/// the service gives the same one. The test runs the probe too.
Future<MatrixAppTest> pushRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/push_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(pushRole) &&
          (among?.call(app) ?? true),
      values: _pushValuesOf,
      roles: {pushRole},
      startProbe: const MatrixStartProbe(
        'integration_test/push_role/probe.dart',
        'probePush',
      ),
    );

/// The values that the test of the revenuecat module gives the keys of the
/// module in .env, the same in every app: keys of the tests for the stores
/// of the platforms, which only the mocks take, and none for the Test
/// Store, which a debug build would take in their place.
Map<String, String?> _revenueCatKeysOf(MatrixApp app) => {
      RevenueCatModule.appleKey.name: 'appl_tests',
      RevenueCatModule.googleKey.name: 'goog_tests',
      RevenueCatModule.testKey.name: '',
    };

/// The values of the files of the test of the push role, the same in every
/// app: `push_owner`, the owner of the notifications through which the app
/// shows a message, which is the id of the role.
Map<String, String> _pushValuesOf(MatrixApp app) => {'push_owner': pushRole.id};

/// The test of the purchases role that the CLI keeps in its
/// `app_tests/purchases_role`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them:
/// - `appPurchases`, over a service of purchases of the test that scripts
///   what a provider answers, and with a controller of its own: a call made
///   before the first start waits for it, and the start completes after it
///   and after the purchase that its completion makes; the start waits for
///   the access at most `startWait`, and a later access still becomes the
///   value; the controller asks again when the user comes back to the app,
///   and takes each change that the service tells of; a change of the user
///   waits for the purchase on its way, which belongs to the user who made
///   it; a provider without what it needs leaves the app without purchases,
///   prints its hint once and stops nothing; and a call fails only with a
///   `PurchasesFailure`, a cancel completes with `false`, and an answer that
///   gives no premium access fails with `notConfigured`;
/// - `appPurchases` over the service of the provider, with users of the
///   test: the offer has at least one plan, each with an id of its own, a
///   title, a price in a currency and periods of one unit or more; a fresh
///   user who buys a plan has premium access as the plan gives it, which the
///   listeners hear of once, with no other change right after it, and a
///   restore gives; a fresh user who restores gets what the device bought;
///   and the purchases of each user stay apart;
/// - the next start, `initPurchases()` again, gives a user the premium
///   access that the user bought.
///
/// The test knows only the role. It relies on the convention that the mocks
/// of every provider keep to, as the role says, and identifies a throwaway
/// user before its fresh users, so that none of them takes over what the
/// user of the device bought. Its probe, `probePurchases()` of
/// `integration_test/purchases_role/probe.dart`, only reads, for the start
/// check on a device: the access of the app is the one that the service of
/// the provider gives, and a provider that is not set up, or a store that
/// does not answer, is no problem while the app shows no premium access.
/// The test runs the probe too.
Future<MatrixAppTest> purchasesRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/purchases_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(purchasesRole) &&
          (among?.call(app) ?? true),
      roles: {purchasesRole},
      startProbe: const MatrixStartProbe(
        'integration_test/purchases_role/probe.dart',
        'probePurchases',
      ),
    );

/// The test of the purchases of the users of the session that the CLI keeps
/// in its `app_tests/purchases_session`, for the apps with the purchases
/// role and the auth role, whichever modules provide them, that [among]
/// accepts, or all of them, in each mode of the auth role: a user without
/// an account who buys a plan keeps the premium access after a sign-up;
/// after a sign-out the next user of the device has none of the purchases
/// of the user who signed out, whose account has them again after a
/// sign-in; the user without an account keeps what it bought at the next
/// start; and a sign-in to an account that exists already leaves the
/// purchases with the user of the device, while the next user of the device
/// after that account signs out has none of them.
///
/// It is a test of the purchases role, whose template makes `appPurchases`
/// follow the session of the app, and whose contract says whose purchases
/// they are. It reads the mode of the app from `authMode` of the app, so
/// the matrix fills in nothing. It uses the helpers of the test of the
/// purchases role ([purchasesRoleAppTest]), which every such app among
/// those that [among] accepts has. It has no probe for the start check:
/// nobody can sign in on a device.
Future<MatrixAppTest> purchasesSessionAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/purchases_session',
      appliesTo: (app) =>
          app.hook!.presentRoles.containsAll(const [purchasesRole, authRole]) &&
          (among?.call(app) ?? true),
      roles: {purchasesRole},
    );

/// The test of the purchases of the user of the device that the CLI keeps in
/// its `app_tests/purchases_device`, for the apps with the purchases role and
/// without the auth role, whichever module provides the purchases: the next
/// start of the app, `initPurchases()` again, gives the user of the device
/// the premium access that it bought, which the device keeps with its user
/// from one launch to the next.
///
/// It is a test of the purchases role, for the apps whose purchases belong
/// to the user of the device alone; the test of the purchases of the users
/// of the session ([purchasesSessionAppTest]) checks the user of the device
/// in the apps with sign-in. It has helpers of its own, since the test of
/// the role need not run in its apps, and no probe for the start check: a
/// purchase would show the sheet of the store on a device.
Future<MatrixAppTest> purchasesDeviceAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/purchases_device',
      appliesTo: (app) {
        final roles = app.hook!.presentRoles;
        return roles.contains(purchasesRole) && !roles.contains(authRole);
      },
      roles: {purchasesRole},
    );

/// The test of the env role that the CLI keeps in its `app_tests/env_role`,
/// for the apps with the role that have keys, whichever module provides the
/// role, that [among] accepts, or all of them: for each key of
/// the app, the getter of `AppEnv` returns the value that `.env` gives the
/// key, and `null` when `.env` leaves the value empty or lacks the key.
///
/// The test only reads: it parses the file of the values of the app
/// ([EnvRole.dotEnvFile]), in the forms of a value that the role names, as
/// the matrix wrote it with the values that the tests of the modules of the
/// app give their keys (`MatrixAppTest.envValues`), and it gives no value
/// itself. The matrix writes the keys of the app for it into [envKeysFile],
/// from the data of the role. It has no probe for the start check: the
/// values of an app on a device are those of its developer.
///
/// Only the apps of the fixtures have a key that `.env` lacks, whose line
/// the test of a fixture module removes. In an app of the CLI, the template
/// of the role writes a line for every key and no test of a module removes
/// one, so the test of the missing keys is skipped there, and only the
/// fixture provider of the role is checked for them.
Future<MatrixAppTest> envRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/env_role',
      appliesTo: (app) =>
          _envKeysOf(app).isNotEmpty && (among?.call(app) ?? true),
      generatedFiles: _envKeysFileOf,
      roles: {envRole},
    );

/// The keys of the env role of [app], an app of the matrix, in the order of
/// the role ([EnvRole.keysIn]), or none in an app without the role.
List<AppEnvKey> _envKeysOf(MatrixApp app) {
  final hook = app.hook!;
  return hook.presentRoles.contains(envRole)
      ? envRole.keysIn(envRole.hookInput(hook))
      : const [];
}

/// The path in an app of what the matrix writes for the test of the env
/// role: `dotEnvFile`, the path of the file of the values of the app from
/// its root ([EnvRole.dotEnvFile]), and `appKeys`, the keys of the app in
/// the order of the role ([EnvRole.keysIn]), each an `AppKey` with its
/// name, the name of its getter of `AppEnv` and a function that reads the
/// getter.
const envKeysFile = 'test/env_role/keys.dart';

/// The file at [envKeysFile] of [app], an app of the matrix with the env
/// role, whose package is [packageName].
Map<String, String> _envKeysFileOf(MatrixApp app, String packageName) {
  final keys = StringBuffer();
  for (final key in _envKeysOf(app)) {
    keys
      ..writeln('  (')
      ..writeln('    name: ${SmfNames.dartString(key.name)},')
      ..writeln('    getter: ${SmfNames.dartString(key.getter)},')
      ..writeln('    read: () => AppEnv.${key.getter},')
      ..writeln('  ),');
  }
  return {
    envKeysFile: '''
// The keys of the values of the app, which the matrix of SMF writes from the
// data of the env role of the app for the test of the env role.
import '${EnvRole.appEnv.importRef.resolveUri(packageName)}';

/// The path of the file of the values of the app, from its root.
const String dotEnvFile = ${SmfNames.dartString(EnvRole.dotEnvFile)};

/// A key of the app: its name, the name of its getter of `AppEnv`, and a
/// function that reads the getter.
typedef AppKey = ({String name, String getter, String? Function() read});

/// The keys of the app, in the order of the env role.
final List<AppKey> appKeys = [
$keys];
''',
  };
}

/// The test of the entry that restores purchases on the settings screen,
/// which the template of the purchases role contributes, that the CLI keeps
/// in its `app_tests/purchases_setting`, for the apps with the purchases
/// role and the settings screen role, whichever modules provide them. Over
/// a service of purchases of the test that scripts what a provider answers:
/// - the settings screen shows the entry once, with its title and no result
///   before a restore, in each language of the app;
/// - a tap restores once, and the entry shows what the restore found: that
///   the premium access is back, that there was nothing to restore, or that
///   the restore failed, for every reason of a failure and for an error of
///   another kind, with the words of the provider below it in debug mode;
///   a screen reader reads the result as it comes;
/// - while a restore is on its way, the entry shows a spinner and no result
///   of an earlier restore, and a second tap restores nothing more;
/// - on a small phone with a large text size, the title and a long failure
///   stay in the row of the entry, in full.
///
/// The test knows only the two roles. The matrix writes the type of the
/// widget of the entry for it into [purchasesSettingFile], from the entries
/// of the settings screen role of the app, with the texts of the entry in
/// each language of the app, from the localization role. It opens the
/// settings screen with the helper of the tests of the settings screen
/// role, and takes the service of the test from the files of the test of
/// the purchases role ([purchasesRoleAppTest]), which runs in every app that
/// this test runs in. It has no probe for the start check: a restore could
/// ask for the store account on a device, and the walk of the routes goes
/// to the settings screen there.
Future<MatrixAppTest> purchasesSettingAppTest() async => MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/purchases_setting',
      appliesTo: (app) => app.hook!.presentRoles
          .containsAll(const [purchasesRole, settingsScreenRole]),
      generatedFiles: _purchasesSettingOf,
      roles: {purchasesRole},
    );

/// The path in an app of what the matrix writes for the test of the entry
/// that restores purchases on the settings screen:
/// `restorePurchasesSetting`, the type of the widget of the entry that the
/// template of the purchases role gives the settings screen role, and
/// `restoreTexts`, the texts of the entry in each language of the app, by
/// the code of the language: its title ([PurchasesRole.restoreTitle]) and
/// what it shows when a restore found premium access, when it found
/// nothing and when it failed ([PurchasesRole.restoreActive],
/// [PurchasesRole.restoreNone] and [PurchasesRole.restoreFailed]). The
/// languages are those of the localization role of the app
/// ([LocalizationRole.localesIn]), in its order, and English alone in an
/// app without the role, whose entry has the English texts.
const purchasesSettingFile = 'test/purchases_setting/setting.dart';

/// The file at [purchasesSettingFile] of [app], an app of the matrix with
/// the purchases role and the settings screen role, whose package is
/// [packageName].
///
/// It imports the file of the entry with the prefix `entry`. A text without
/// a translation into a language of the app is the English one there, as
/// the localization role says of the texts of an app. Throws a
/// [StateError] if the template of the purchases role gives the settings
/// screen no entry or more than one: the test taps one entry.
Map<String, String> _purchasesSettingOf(MatrixApp app, String packageName) {
  final hook = app.hook!;
  final entries = [
    for (final RoleData(:value, :origin)
        in settingsScreenRole.hookInput(hook).data)
      if (value is SettingsEntry &&
          origin == const RoleTemplateOrigin(purchasesRole))
        value,
  ];
  if (entries.length != 1) {
    throw StateError(
      'The template of the $purchasesRole gives the settings screen of '
      '${app.name} ${entries.length} entries, rather than the entry that '
      'restores purchases alone.',
    );
  }
  final widget = entries.single.widget;
  final languages = hook.presentRoles.contains(localizationRole)
      ? localizationRole.localesIn(localizationRole.hookInput(hook))
      : const ['en'];
  final texts = StringBuffer();
  for (final language in languages) {
    texts.writeln('  ${SmfNames.dartString(language)}: (');
    for (final (field, text) in const [
      ('title', PurchasesRole.restoreTitle),
      ('active', PurchasesRole.restoreActive),
      ('none', PurchasesRole.restoreNone),
      ('failed', PurchasesRole.restoreFailed),
    ]) {
      final value = SmfNames.dartString(text.textIn(language) ?? text.en);
      texts.writeln('    $field: $value,');
    }
    texts.writeln('  ),');
  }
  return {
    purchasesSettingFile: '''
// The entry that restores purchases on the settings screen and its texts,
// which the matrix of SMF writes from the data of the settings screen role
// and of the localization role of the app for the test of the entry, in
// test/purchases_setting.
import '${widget.import!.resolveUri(packageName)}' as entry;

/// The type of the widget of the entry that restores purchases, an entry of
/// the settings screen.
const Type restorePurchasesSetting = ${widget.codeWith('entry')};

/// The texts of the entry in one language: its title, and what it shows
/// when a restore found premium access, when it found nothing and when it
/// failed.
typedef RestoreTexts = ({
  String title,
  String active,
  String none,
  String failed,
});

/// The texts of the entry by the code of each language of the app, the first
/// of which the app uses when the device asks for none of them. An app
/// without the localization role has the English texts alone.
const Map<String, RestoreTexts> restoreTexts = {
$texts};
''',
  };
}

/// The name of the value of the build with which the start of an app on a
/// device tells the probe of `app_tests/flavors` that it asked for a flavor. A
/// build without it asks for none.
const startFlavorDefine = 'SMF_START_FLAVOR';

/// The arguments of the `flutter` tool that a build of an app as a release
/// takes too when CI starts it on a device, which the script of CI reads
/// ([startReleaseArgumentsFile]): the flavor that the app entry role names
/// for a release, since a command without `--flavor` builds its default
/// flavor in release mode too, and the same flavor for the probe of the
/// flavor, which sees whether it reached the app. So the script names no
/// flavor, and the release app that it starts is the one that a user gets.
final List<String> startReleaseBuildArguments = [
  '--flavor',
  AppEntryRole.releaseFlavor.name,
  '--dart-define=$startFlavorDefine=${AppEntryRole.releaseFlavor.name}',
];

/// The test of the flavor of a running app that the CLI keeps in its
/// `app_tests/flavors`, for the apps that [among] accepts, or all of them,
/// whichever module provides the app entry: `appFlavor` of Flutter is the
/// default flavor that the role names ([AppEntryRole.defaultFlavor]), since
/// `flutter test` is a command without `--flavor`.
///
/// Only a run of the `flutter` tool shows what such a command builds, so the
/// rules of the role leave that value to this test, and a provider that names
/// another flavor of the role fails it.
///
/// Its probe, which the start check runs on a device, compares `appFlavor`
/// with the flavor that the build asked for, which a build tells it with a
/// value of the build ([startFlavorDefine]) and is the default flavor without
/// one. So the debug start of CI shows the default flavor on a device, on each
/// version of Flutter of the nightly run, and its release start the one in
/// [startReleaseBuildArguments]. The id and the name of the app on a device
/// are native, so no running app shows them.
///
/// The test knows only the role, and has no mocks. The matrix fills in the
/// flavor and the name of the value.
Future<MatrixAppTest> flavorsAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/flavors',
      appliesTo: among ?? (_) => true,
      values: (_) => {
        'default_flavor': AppEntryRole.defaultFlavor.name,
        'flavor_define': startFlavorDefine,
      },
      roles: {appEntryRole},
      startProbe: const MatrixStartProbe(
        'integration_test/flavors/probe.dart',
        'probeFlavor',
      ),
    );

/// The test of the theme role that the CLI keeps in its
/// `app_tests/theme_role`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them. Once the app started
/// with `main()`, it follows the device; a choice of a mode with
/// `appThemeMode.choose()` reaches the root `MaterialApp`, which takes the
/// mode, and the screen below it gets the light theme of the provider in
/// the light mode and its dark theme in the dark mode, the same colour
/// schemes that `createLightTheme()` and `createDarkTheme()` return for the
/// context of the root. A choice is saved under the key of the role, as
/// the name of the mode, and the next start, `initPreferences()` again,
/// has the mode whose name the test wrote under that key.
///
/// It is a test of the app entry role too. The root gets the mode from an
/// inherited widget around it, which its arguments read from its context,
/// so the test fails on a provider of the app entry whose root does not
/// rebuild when that widget notifies.
///
/// The test knows only the roles. The matrix fills in the key, which the
/// role publishes ([ThemeRole.modeKey]). It has no probe for the start
/// check: on a device the mode is the same Dart state as in a test, and the
/// platform side of the preferences, which does differ there, has the
/// probes of the preferences role and of its provider. The matrix of the
/// fixtures runs the test only in its apps with every module, which run
/// other tests already.
Future<MatrixAppTest> themeRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/theme_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(themeRole) &&
          (among?.call(app) ?? true),
      values: _themeValuesOf,
      roles: {themeRole, appEntryRole},
    );

/// The values of the files of the tests of the theme role, the same in
/// every app: `mode_key`, the key of the theme mode in the preferences, as
/// the role publishes it.
Map<String, String> _themeValuesOf(MatrixApp app) =>
    const {'mode_key': ThemeRole.modeKey};

/// The path in an app of what the matrix writes for the test of the entry
/// of the theme mode that the CLI keeps in its `app_tests/theme_setting`:
/// `settingsLocation`, the location of the route that the provider of the
/// settings screen role names as the settings screen
/// ([SettingsScreenRole.screenIn]), created as `const` from its class of
/// the navigation of the router role, and `themeModeEntry`, the type of the
/// widget of the entry that the template of the theme role gives the
/// settings screen.
const themeSettingFile = 'test/theme_setting/theme_setting.dart';

/// The file at [themeSettingFile] of [app], an app of the matrix with the
/// theme role and the settings screen role, whose package is [packageName].
///
/// It imports the navigation of the router role without a prefix, and the
/// file of the entry with the prefix `entry`. Throws a [StateError] if the
/// provider of the settings screen role names no route of its own, or if
/// the template of the theme role gives the settings screen no entry or
/// more than one: the test taps the modes of one entry.
Map<String, String> _themeSettingOf(MatrixApp app, String packageName) {
  final input = settingsScreenRole.hookInput(app.hook!);
  final route = _settingsRouteOf(app, input);
  final entries = [
    for (final RoleData(:value, :origin) in input.data)
      if (value is SettingsEntry &&
          origin == const RoleTemplateOrigin(themeRole))
        value,
  ];
  if (entries.length != 1) {
    throw StateError(
      'The template of the $themeRole gives the settings screen of '
      '${app.name} ${entries.length} entries, rather than the entry of the '
      'theme mode alone.',
    );
  }
  final widget = entries.single.widget;
  // The template of the settings screen role rejects an entry whose widget
  // is not in a file of the app, so it has an import.
  final entry = widget.import!.resolveUri(packageName);
  return {
    themeSettingFile: '''
// The settings screen of the app and the entry of the theme mode, which the
// matrix of SMF writes from the data of the settings screen role of the app
// for the test of the entry, theme_setting_test.dart.
import '${_navigationOf(packageName)}';
import '$entry' as entry;

/// The location of the route that shows the settings screen.
const AppLocation settingsLocation = ${route.locationClass}();

/// The type of the widget of the entry of the theme mode on the settings
/// screen.
const Type themeModeEntry = ${widget.codeWith('entry')};
''',
  };
}

/// The test of the router role that the CLI keeps in its
/// `app_tests/router_walk`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them: it starts the app
/// with `main()` and goes to each location of the app that needs no
/// values, at most [routerWalkLimit], with `go()` of the navigator of the
/// role. Each must show the page named after its route on top of the
/// innermost navigator on the screen, and the screen of the route, without
/// an `ErrorWidget` on the screen or an error that Flutter reports.
///
/// In an app with guards of the routes, the walk expects what the role
/// says. For a location that a guard keeps the user from, that is the page
/// and the screen of the target of that guard (`redirectOf()` of the
/// role): every location outside the flow of a gate, and for a guard that
/// stands for a condition, only the locations of the routes that ask for
/// the condition. The target of a gate takes the place of the stack, and
/// that of a guard of a condition opens over the page that the walk is on:
/// either way it is the page on top, which the walk looks at. For any other
/// location in a flow that is over, it is the screen that the app starts on
/// (`flowIsOver()` of the role). So its probe, `probeRoutes()`, which the
/// start check runs on a device, holds whichever guards allow there, where
/// no test can open one, such as a guard that asks for a signed-in user.
/// The test itself first fails on each guard that does not allow, by its
/// name, a guard of a condition too: under `flutter test`, the module of a
/// guard opens it for the tests of the app, in the mocks of its app test
/// ([MatrixAppTest.mocks]), so that the walk reaches every route outside
/// the flows and the tests of the other modules see the screens that they
/// expect. The screens of a flow are then for the tests of its module,
/// since the router shows them only while the guard does not allow.
///
/// The test knows only the role. The matrix writes the locations of each
/// app for it, from the routes and the guards of its router role, into
/// [routerWalkFile], next to the walk in
/// `integration_test/router_walk/walk.dart`. The matrix of the fixtures
/// runs it too, only in the apps with every module, which run other tests
/// already.
Future<MatrixAppTest> routerWalkAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/router_walk',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(routerRole) &&
          (among?.call(app) ?? true),
      generatedFiles: _walkedLocationsOf,
      roles: {routerRole},
      startProbe: const MatrixStartProbe(
        'integration_test/router_walk/walk.dart',
        'probeRoutes',
      ),
    );

/// The path in an app of the locations that the walk of the test of the
/// router role goes to, which the matrix writes: `walkedLocations`, the
/// locations of the routes that need no values, each with the full name of
/// its route ([FacadeRoute.fullName]), the location, created as `const`
/// from its class of the navigation of the role, and the type of the screen
/// that the route shows. They are in the order of the routes of the app
/// ([RouterFacade.routes]).
///
/// The file also says what the router shows for each of them, with two
/// functions that every app gets, so that the walk is the same in an app
/// with guards of the routes ([RouterFacade.guards]) and in one without,
/// which has nothing of what the role generates for them:
/// - `shownFor(walked)`, the full name of the route and the type of the
///   screen that the router shows when it is asked to show `walked`, a
///   `ShownScreen`. In an app without guards, those are the ones of
///   `walked`. In an app with guards, they are the ones of the target of
///   the guard that keeps the user from `walked`, as `redirectOf()` of the
///   role says; else `startOfApp` for a location in a flow that is over,
///   as `flowIsOver()` of the role says; else the ones of `walked`. The
///   targets are in `guardTargets`, in the order of the guards, those of
///   the gates first and then those of the guards that stand for a
///   condition, each once, also those that are not among the first
///   [routerWalkLimit] locations.
///   `startOfApp` is the screen that the app starts on: that of the route
///   that the role chose ([RouterRole.startIn]), with the name of that
///   route, or the fallback start screen of the app entry role
///   ([AppEntryRole.fallbackStartScreen]) without the name of a route, in
///   an app that no route can start;
/// - `closedGuards()`, the full names of the guards that do not allow, in
///   the order of `routeGuards` of the role, a guard whose condition does
///   not hold among them; none in an app without guards.
const routerWalkFile = 'integration_test/router_walk/locations.dart';

/// The most locations that the walk of the test of the router role goes
/// to, the first of [routerWalkFile].
const routerWalkLimit = 20;

/// The file at [routerWalkFile] of [app], an app of the matrix with the
/// router role, whose package is [packageName].
///
/// It imports the navigation of the role without a prefix, since the names
/// of its classes differ from those of the file, and the file of every
/// screen once, with a prefix of its own, `screen0`, `screen1`, ..., so
/// that no name clashes. In an app with guards it imports the file of the
/// role that has them too, without a prefix either.
Map<String, String> _walkedLocationsOf(MatrixApp app, String packageName) {
  final input = routerRole.hookInput(app.hook!);
  final facade = routerRole.facadeOf(input);
  final routes = [
    for (final route in facade.routes)
      if (!route.hasRequiredParams) route,
  ].take(routerWalkLimit);
  final screens = <String, String>{};
  String prefixOf(ImportRef import) => screens.putIfAbsent(
        import.resolveUri(packageName),
        () => 'screen${screens.length}',
      );
  String walked(FacadeRoute route) {
    final screen = route.route.screen;
    return '  (\n'
        '    route: ${SmfNames.dartString(route.fullName)},\n'
        '    location: ${route.locationClass}(),\n'
        '    screen: ${prefixOf(screen.import)}.${screen.className},\n'
        '  ),\n';
  }

  final locations = routes.map(walked).join();
  // Each target once: two guards may show the same one, such as a gate and
  // a guard that stands for a condition.
  final targets = {for (final guard in facade.guards) guard.target};
  const fallback = AppEntryRole.fallbackStartScreen;
  final guards = targets.isEmpty
      ? _withoutGuards
      : _withGuards(
          targets: targets.map(walked).join(),
          start: switch (routerRole.startIn(input)) {
            final start? => (
                route: SmfNames.dartString(start.fullName),
                screen: '${prefixOf(start.route.screen.import)}.'
                    '${start.route.screen.className}',
              ),
            null => (
                route: 'null',
                screen: '${prefixOf(fallback.importRef)}.${fallback.name}',
              ),
          },
        );
  String ofRole(String file) =>
      ImportRef.app(file.substring('lib/'.length)).resolveUri(packageName);
  final imports = [
    "import '${ofRole(RouterRole.navigationFile)}';",
    if (targets.isNotEmpty) "import '${ofRole(RouterRole.appRouterFile)}';",
    for (final MapEntry(key: uri, value: prefix) in screens.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    routerWalkFile: '''
// The locations of the app that need no values, at most $routerWalkLimit,
// and what the router shows for each, which the matrix of SMF writes from
// the data of the router role of the app for the walk of its routes,
// walk.dart.
${imports.join('\n')}

/// A location of the app that needs no values: the full name of its route,
/// the location, and the type of the screen that the route shows.
typedef WalkedLocation = ({String route, AppLocation location, Type screen});

/// What the router shows for a location: the full name of the route of the
/// page on top, or `null` for a screen that is no route of a module, and
/// the type of the screen.
typedef ShownScreen = ({String? route, Type screen});

/// The locations of the app that need no values, in the order of the
/// routes of the app.
const List<WalkedLocation> walkedLocations = [
$locations];
$guards''',
  };
}

/// What [routerWalkFile] says of the guards in an app without guards, which
/// has none of `redirectOf()`, `flowIsOver()` and `routeGuards` of the
/// router role.
const _withoutGuards = '''

/// What the router shows when it is asked to show [walked]: the page and
/// the screen of [walked] itself, since no module of the app has a guard of
/// the routes.
ShownScreen shownFor(WalkedLocation walked) =>
    (route: walked.route, screen: walked.screen);

/// The full names of the guards of the routes that do not allow: none,
/// since no module of the app has a guard.
List<String> closedGuards() => const [];
''';

/// What [routerWalkFile] says of the guards in an app with guards, whose
/// targets are [targets], each as a location of the walk, and which starts
/// on the screen [start]: the code of the full name of its route, or of
/// `null` for the fallback start screen, and the code of the type of the
/// screen.
String _withGuards({
  required String targets,
  required ({String route, String screen}) start,
}) =>
    '''

/// The targets of the guards of the routes of the app, in the order of the
/// guards: the location that the router shows while a guard does not
/// allow.
const List<WalkedLocation> guardTargets = [
$targets];

/// The screen that the app starts on, which the router shows in place of a
/// location in a flow that is over: that of the route that starts the app,
/// or the fallback start screen of the app entry, which is no route, in an
/// app that no route can start.
const ShownScreen startOfApp = (
  route: ${start.route},
  screen: ${start.screen},
);

/// What the router shows on top when it is asked to show [walked], as the
/// router role says: the target of the guard that keeps the user from it
/// (redirectOf()), in place of the stack for a gate, and over the page that
/// the user is on for a guard of a condition that [walked] asks for; or
/// else the screen that the app starts on if the flow of [walked] is over
/// (flowIsOver()), or else the page and the screen of [walked] itself.
ShownScreen shownFor(WalkedLocation walked) {
  final target = ${RouterRole.redirectOf}(walked.route);
  if (target != null) {
    final shown = guardTargets.firstWhere(
      (shown) => shown.route == target.routeName,
    );
    return (route: shown.route, screen: shown.screen);
  }
  if (${RouterRole.flowIsOver}(walked.route)) return startOfApp;
  return (route: walked.route, screen: walked.screen);
}

/// The full names of the guards of the routes that do not allow, in the
/// order of the guards.
List<String> closedGuards() => [
  for (final guard in ${RouterRole.routeGuards})
    if (!guard.allows.value) guard.name,
];
''';

/// The path in an app of what the matrix writes for the tests of the
/// settings screen role that the CLI keeps in its
/// `app_tests/settings_screen_role`: `settingsLocation`, the location of the
/// route that the provider of the role names as the settings screen
/// ([SettingsScreenRole.screenIn]), created as `const` from its class of
/// the navigation of the router role, `settingsScreen`, the type of the
/// screen that the route shows, and `settingsEntries`, the types of the
/// widgets of the entries of the screen, in the order of the role
/// ([SettingsScreenRole.entriesIn]).
const settingsScreenFile = 'test/settings_screen_role/settings.dart';

/// The file at [settingsScreenFile] of [app], an app of the matrix with
/// the settings screen role, whose package is [packageName].
///
/// It imports the navigation of the router role without a prefix, since the
/// names of its classes differ from those of the file, the file of the
/// screen with the prefix `screen`, and the file of every entry once, with a
/// prefix of its own, `entry0`, `entry1`, ..., so that no name clashes.
/// Throws a [StateError] if the provider of the role names no route of its
/// own, which the rules of the role report in an app of the matrix.
Map<String, String> _settingsOf(MatrixApp app, String packageName) {
  final input = settingsScreenRole.hookInput(app.hook!);
  final route = _settingsRouteOf(app, input);
  final screen = route.route.screen;
  final prefixes = {screen.import.resolveUri(packageName): 'screen'};
  final entries = StringBuffer();
  for (final entry in settingsScreenRole.entriesIn(input)) {
    final widget = entry.widget;
    // The template of the role rejects an entry whose widget is not in a
    // file of the app, so each has an import.
    final prefix = prefixes.putIfAbsent(
      widget.import!.resolveUri(packageName),
      () => 'entry${prefixes.length - 1}',
    );
    entries.writeln('  ${widget.codeWith(prefix)},');
  }
  final imports = [
    "import '${_navigationOf(packageName)}';",
    for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    settingsScreenFile: '''
// The settings screen of the app and its entries, which the matrix of SMF
// writes from the data of the settings screen role of the app for the
// tests of the role, settings_screen_test.dart and
// settings_entries_test.dart.
${imports.join('\n')}

/// The location of the route that shows the settings screen.
const AppLocation settingsLocation = ${route.locationClass}();

/// The type of the settings screen.
const Type settingsScreen = screen.${screen.className};

/// The types of the widgets of the entries of the settings screen, in the
/// order in which the screen shows them.
const List<Type> settingsEntries = [
$entries];
''',
  };
}

/// The route that the provider of the settings screen role names as the
/// settings screen in [input], the input of the role in [app]. Throws a
/// [StateError] if it names no route of its own, which the rules of the
/// role report in an app of the matrix.
FacadeRoute _settingsRouteOf(
  MatrixApp app,
  RoleHookInput<SettingsData> input,
) {
  final route = settingsScreenRole.screenIn(input);
  if (route == null) {
    throw StateError(
      'No module of ${app.name} names a route of its own as the settings '
      'screen.',
    );
  }
  return route;
}

/// The URI of the navigation of the router role in the app whose package
/// is [packageName], which has the classes of the locations of the app.
String _navigationOf(String packageName) => ImportRef.app(
      RouterRole.navigationFile.substring('lib/'.length),
    ).resolveUri(packageName);

/// The path in an app of what the matrix writes for the test of the
/// language of the settings screen that the settings module keeps in its
/// `app_tests/settings`: `appLanguages`, the codes of the languages of the
/// app ([LocalizationRole.localesIn]), and `chooseLanguage()`, which
/// chooses one of them for the app as its user does and completes once the
/// app saved the choice.
const settingsLanguagesFile = 'test/settings_languages.dart';

/// The file at [settingsLanguagesFile] of [app], an app of the matrix whose
/// package is [packageName].
///
/// In an app with the localization role, the languages are those of the
/// role, and choosing one goes through `appLocale` of the file of the role,
/// which the root of the app follows and which saves the choice in the
/// preferences of the app. An app without the role is in English, and has
/// no language to choose.
Map<String, String> _settingsLanguagesOf(MatrixApp app, String packageName) {
  const about = '''
// The languages of the app, which the matrix of SMF writes from the
// localization role of the app for the test of the language of the
// settings screen, settings_language_test.dart.''';
  final hook = app.hook!;
  if (!hook.presentRoles.contains(localizationRole)) {
    return {
      settingsLanguagesFile: '''
$about

/// The codes of the languages of the app: it has no texts in other
/// languages, so it is in English.
const List<String> appLanguages = ['en'];

/// The app has one language, so there is none to choose.
Future<void> chooseLanguage(String language) async {}
''',
    };
  }
  final languages = [
    for (final language
        in localizationRole.localesIn(localizationRole.hookInput(hook)))
      SmfNames.dartString(language),
  ];
  final appLocale = ImportRef.app(
    LocalizationRole.appLocaleFile.substring('lib/'.length),
  ).resolveUri(packageName);
  return {
    settingsLanguagesFile: '''
$about
import 'dart:ui';

import '$appLocale';

/// The codes of the languages of the app, the first of which the app is in
/// when the device asks for none of them.
const List<String> appLanguages = [${languages.join(', ')}];

/// Chooses [language], one of [appLanguages], as the language of the app,
/// as its user does. The app saves the choice in its preferences, and the
/// future completes once it did.
Future<void> chooseLanguage(String language) =>
    appLocale.choose(Locale(language));
''',
  };
}

/// The path in an app of what the matrix writes for the tests of the home
/// module: `homeTexts`, the texts of the screen of the module
/// ([HomeModule.texts]), each by its name, in each language of the app, by
/// the code of the language. The languages are those of the localization
/// role of the app ([LocalizationRole.localesIn]), in its order, and English
/// alone in an app without the role, whose screen has the English texts.
const homeTextsFile = 'test/home/texts.dart';

/// The file at [homeTextsFile] of [app], an app of the matrix.
///
/// A text of the module without a translation into a language of the app
/// is the English one there, as the localization role says of the texts of
/// an app.
Map<String, String> _homeTextsFileOf(MatrixApp app) {
  final texts = _textsByLanguageOf(app, HomeModule.texts);
  return {
    homeTextsFile: '''
// The texts of the start screen of the home module in each language of the
// app, which the matrix of SMF writes from the texts of the module and the
// languages of the localization role of the app for the tests of the
// module, in test/home.

/// The texts of the screen by the code of each language of the app, the
/// first of which the app uses when the device asks for none of them: each
/// text by its name in the module. An app without the localization role
/// has the English texts alone.
const Map<String, Map<String, String>> homeTexts = {
$texts};
''',
  };
}

/// The path in an app of what the matrix writes for the tests of the group
/// and of the back button of the settings screen that the settings module
/// keeps in its `app_tests/settings`: `settingsEntryCount`, how many
/// entries the screen has, and `settingsInMainNavigation`, whether the
/// screen is a destination of the main navigation of the app.
const settingsOfAppFile = 'test/settings_of_app.dart';

/// The file at [settingsOfAppFile] of [app], an app of the matrix with the
/// settings screen role.
///
/// The entries are those of the role ([SettingsScreenRole.entriesIn]). An
/// app without any has the note of the module for its developer on the
/// screen. The screen is a destination when the app has the layout role and
/// the route of the settings screen ([SettingsScreenRole.screenIn]) is one
/// of the destinations of that role ([LayoutRole.destinationsIn]). The
/// router role refuses to push a location of the main navigation over it,
/// so the test of the back button pushes the screen only where it is no
/// destination.
Map<String, String> _settingsOfAppOf(MatrixApp app) {
  final input = settingsScreenRole.hookInput(app.hook!);
  final destination = _settingsInMainNavigationOf(app);
  return {
    settingsOfAppFile: '''
// What the settings screen has in the app and where it is, which the matrix
// of SMF writes from the settings screen role and the layout role of the
// app for the tests of the settings module, settings_group_test.dart and
// settings_back_test.dart.

/// How many entries the settings screen has: the settings of the modules
/// of the app. Without any, the screen has a note for the developer of the
/// app.
const int settingsEntryCount = ${settingsScreenRole.entriesIn(input).length};

/// Whether the settings screen is a destination of the main navigation of
/// the app. Code cannot push such a screen on top of another one.
const bool settingsInMainNavigation = $destination;
''',
  };
}

/// Whether the settings screen of [app], an app of the matrix with the
/// settings screen role, is a destination of its main navigation: the app
/// has the layout role, and the route of the screen
/// ([SettingsScreenRole.screenIn]) is one of the destinations of that role
/// ([LayoutRole.destinationsIn]).
bool _settingsInMainNavigationOf(MatrixApp app) {
  final hook = app.hook!;
  final screen =
      settingsScreenRole.screenIn(settingsScreenRole.hookInput(hook));
  return hook.presentRoles.contains(layoutRole) &&
      layoutRole
          .destinationsIn(layoutRole.hookInput(hook))
          .any((route) => route.fullName == screen?.fullName);
}

/// The test of the DI role that the CLI keeps in its `app_tests/di_role`,
/// for the apps with the role, whichever module provides it, whose modules
/// register services, at least one of each of [lifetimes]: once the
/// start-up of the app ran, every service resolves, a singleton and a lazy
/// singleton to one instance; `resetDependencies()` removes them all, and
/// `registerDependencies()` registers them again.
///
/// The test knows only the role. The matrix writes the services of each
/// app for it, from the registrations of its DI role, into
/// [registeredServicesFile]. The matrix of the fixtures runs it too, in the
/// apps whose services have every lifetime. Its probe, `probeServices()` of
/// `integration_test/di_role/probe.dart`, resolves each service on a device
/// for the start check, a singleton and a lazy singleton twice, without
/// calling it or resetting the container.
Future<MatrixAppTest> diRoleAppTest({
  Set<DiLifetime> lifetimes = const {},
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/di_role',
      appliesTo: (app) {
        if (!app.hook!.presentRoles.contains(diRole)) return false;
        final registered = {
          for (final registration in _servicesOf(app)) registration.lifetime,
        };
        return registered.isNotEmpty && registered.containsAll(lifetimes);
      },
      generatedFiles: _registeredServicesOf,
      roles: {diRole},
      startProbe: const MatrixStartProbe(
        'integration_test/di_role/probe.dart',
        'probeServices',
      ),
    );

/// The path in an app of the services that its modules register, which the
/// matrix writes for the test of the DI role: `registeredServices`, the
/// services in the order of their registration ([DiGraph.ordered]), each
/// with its name, such as `FixtureZone "utc"`, its lifetime, such as
/// `lazySingleton`, and a function that resolves it with `resolve()` of the
/// service locator of the role, by its type and its instance name.
const registeredServicesFile =
    'integration_test/di_role/registered_services.dart';

/// The file at [registeredServicesFile] of [app], an app of the matrix with
/// the DI role, whose package is [packageName].
///
/// It imports the service locator with the prefix `locator`, and the file
/// of every type of a service once, with a prefix of its own, `di0`, `di1`,
/// ..., so that no name clashes.
Map<String, String> _registeredServicesOf(
  MatrixApp app,
  String packageName,
) {
  final locator = ImportRef.app(
    DiRole.serviceLocatorFile.substring('lib/'.length),
  ).resolveUri(packageName);
  final prefixes = <String, String>{locator: 'locator'};
  String typeOf(TypeRef type) => switch (type.import) {
        null => type.name,
        final import => type.codeWith(
            prefixes.putIfAbsent(
              import.resolveUri(packageName),
              () => 'di${prefixes.length - 1}',
            ),
          ),
      };
  final services = StringBuffer();
  for (final registration in _servicesOf(app)) {
    final name = switch (registration.instanceName) {
      null => '',
      final name => 'instanceName: ${SmfNames.dartString(name)}',
    };
    services
      ..writeln('  (')
      ..writeln('    name: ${SmfNames.dartString('${registration.key}')},')
      ..writeln("    lifetime: '${registration.lifetime.name}',")
      ..writeln(
        '    resolve: () => '
        'locator.resolve<${typeOf(registration.type)}>($name),',
      )
      ..writeln('  ),');
  }
  final imports = [
    for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    registeredServicesFile: '''
// The services that the modules of the app register in its DI container,
// which the matrix of SMF writes from the data of the DI role of the app
// for the test of the role, di_role_test.dart.
${imports.join('\n')}

/// A service that the modules of the app register: its name, its lifetime,
/// and a function that resolves it with resolve() of the service locator.
typedef RegisteredService = ({
  String name,
  String lifetime,
  Object Function() resolve,
});

/// The services that the modules of the app register, in the order of
/// their registration.
final List<RegisteredService> registeredServices = [
$services];
''',
  };
}

/// The registrations of the DI role of [app], in the order of their
/// registration.
List<DiRegistration> _servicesOf(MatrixApp app) =>
    diRole.graphOf(diRole.hookInput(app.hook!)).ordered;

/// The path in an app of what the matrix writes for the tests of the
/// onboarding module: `startScreen`, the type of the screen that the app
/// starts on, which the app shows once the onboarding is finished.
const onboardingStartScreenFile = 'test/onboarding/start_screen.dart';

/// The file at [onboardingStartScreenFile] of [app], an app of the matrix
/// with the router role, whose package is [packageName]: the screen of the
/// route that the router role chose to start the app on, or the fallback
/// start screen of the app entry role when no route of its modules can
/// start it.
///
/// It imports the file of the screen with the prefix `screen`.
Map<String, String> _startScreenFileOf(MatrixApp app, String packageName) {
  final (import, screen) = _startScreenClassOf(app);
  return {
    onboardingStartScreenFile: '''
// The screen that the app starts on, which the matrix of SMF writes from
// the data of the router role of the app for the tests of the onboarding
// module, first_launch_test.dart and later_launch_test.dart.
import '${import.resolveUri(packageName)}' as screen;

/// The type of the screen that the app starts on: that of the route that
/// the router role chose, or the fallback start screen of the app entry
/// role in an app that no route can start.
const Type startScreen = screen.$screen;
''',
  };
}

/// The path in an app of what the matrix writes for the test of the first
/// launch of the onboarding module: `onboardingTexts`, the texts of the
/// module ([OnboardingModule.texts]), each by its name, in each language of
/// the app, by the code of the language. The languages are those of the
/// localization role of the app ([LocalizationRole.localesIn]), in its
/// order, and English alone in an app without the role, whose onboarding
/// has the English texts.
const onboardingTextsFile = 'test/onboarding/texts.dart';

/// The file at [onboardingTextsFile] of [app], an app of the matrix.
///
/// A text of the module without a translation into a language of the app
/// is the English one there, as the localization role says of the texts of
/// an app.
Map<String, String> _onboardingTextsFileOf(MatrixApp app) {
  final texts = _textsByLanguageOf(app, OnboardingModule.texts);
  return {
    onboardingTextsFile: '''
// The texts of the onboarding in each language of the app, which the
// matrix of SMF writes from the texts of the onboarding module and the
// languages of the localization role of the app for the test of the
// module, first_launch_test.dart.

/// The texts of the onboarding by the code of each language of the app,
/// the first of which the app uses when the device asks for none of them:
/// each text by its name in the module. An app without the localization
/// role has the English texts alone.
const Map<String, Map<String, String>> onboardingTexts = {
$texts};
''',
  };
}

/// The path in an app of what the matrix writes for the test of the
/// language of the messages of Firebase Authentication that the
/// firebase_auth module keeps in its `app_tests/firebase_auth`:
/// `messageLanguages`, the codes of the languages in which the app asks
/// Firebase for its messages, those of the app
/// ([LocalizationRole.localesIn]), and `chooseLanguage()`, which chooses
/// one of them for the app as its user does, or lets the app follow the
/// device again.
const messageLanguagesFile = 'test/firebase_auth/languages.dart';

/// The file at [messageLanguagesFile] of [app], an app of the matrix whose
/// package is [packageName].
///
/// In an app with the localization role, the languages are those of the
/// role, and choosing one goes through `appLocale` of the file of the role.
/// An app without the role asks Firebase for no language, so the file has
/// none, and nothing to choose.
Map<String, String> _messageLanguagesOf(MatrixApp app, String packageName) {
  const about = '''
// The languages in which the app asks Firebase Authentication for its
// messages, which the matrix of SMF writes from the localization role of
// the app for the test of the calls of the firebase_auth module,
// calls_test.dart.''';
  final hook = app.hook!;
  if (!hook.presentRoles.contains(localizationRole)) {
    return {
      messageLanguagesFile: '''
$about

/// The codes of the languages in which the app asks for the messages: the
/// app has no languages of its own, so it asks for none, and Firebase sends
/// each message in the language of its template.
const List<String> messageLanguages = [];

/// The app has no language to choose.
Future<void> chooseLanguage(String? language) async {}
''',
    };
  }
  final languages = [
    for (final language
        in localizationRole.localesIn(localizationRole.hookInput(hook)))
      SmfNames.dartString(language),
  ];
  final appLocale = ImportRef.app(
    LocalizationRole.appLocaleFile.substring('lib/'.length),
  ).resolveUri(packageName);
  return {
    messageLanguagesFile: '''
$about
import 'dart:ui';

import '$appLocale';

/// The codes of the languages in which the app asks for the messages:
/// those of the app, the first of which the app is in when the device asks
/// for none of them.
const List<String> messageLanguages = [${languages.join(', ')}];

/// Chooses [language], one of [messageLanguages], as the language of the
/// app, as its user does, or with `null` lets the app follow the languages
/// of the device again.
Future<void> chooseLanguage(String? language) =>
    appLocale.choose(language == null ? null : Locale(language));
''',
  };
}

/// The path in an app of what the matrix writes for the tests of the
/// sign-in module: `startScreen`, the type of the screen that the app
/// starts on, which the app shows once its user may see it; `otherPages`,
/// a location of the app that is neither the one that the app starts on nor
/// in the flow of a guard, with the type of its screen, or nothing in an
/// app without such a route; `settingsLocation` and `settingsScreen`, the
/// location of the route that the provider of the settings screen role
/// names as the settings screen and the type of that screen,
/// `settingsInMainNavigation`, whether that screen is a destination of the
/// main navigation of the app, and `accountEntry`, the type of the widget
/// of the entry that the module gives that screen; and `signInTexts`, the
/// texts of the module
/// ([SignInModule.texts]), each by its name, in each language of the app,
/// by the code of the language. The languages are those of the
/// localization role of the app
/// ([LocalizationRole.localesIn]), in its order, and English alone in an
/// app without the role, whose screens have the English texts.
const signInOfAppFile = 'test/sign_in/of_app.dart';

/// The file at [signInOfAppFile] of [app], an app of the matrix with the
/// router role and the settings screen role, whose package is
/// [packageName].
///
/// The screen that the app starts on is that of the route that the router
/// role chose, or the fallback start screen of the app entry role when no
/// route of its modules can start it; the file imports its file with the
/// prefix `screen`. The settings screen and the entry come from the data of
/// the settings screen role, whichever module provides it: the entry is
/// the one that the module gave the role. The screen is a destination by
/// the layout role of the app. The router role refuses to push a location
/// of the main navigation over it, so the tests push the settings screen
/// over another page only where it is no destination. A text of the module
/// without a translation into a language of the app is the English one
/// there, as the localization role says of the texts of an app.
Map<String, String> _signInOfAppOf(MatrixApp app, String packageName) {
  final (import, screen) = _startScreenClassOf(app);
  final texts = _textsByLanguageOf(app, SignInModule.texts);
  // A page that a user may be on other than the one that the app starts
  // on: a route that needs no values, in no flow of a guard, that asks for
  // no condition.
  final input = routerRole.hookInput(app.hook!);
  final facade = routerRole.facadeOf(input);
  final start = routerRole.startIn(input);
  final inFlows = {
    for (final guard in facade.guards)
      for (final route in guard.flow) route.fullName,
  };
  final other = [
    for (final route in facade.routes)
      if (!route.hasRequiredParams &&
          route.fullName != start?.fullName &&
          !inFlows.contains(route.fullName) &&
          route.route.conditions.isEmpty)
        route,
  ].firstOrNull;
  final otherScreen = other?.route.screen;
  final otherPage = other == null
      ? ''
      : '  (location: ${other.locationClass}(), '
          'screen: other.${otherScreen!.className}),\n';
  final otherImport = otherScreen == null
      ? ''
      : "import '${otherScreen.import.resolveUri(packageName)}' "
          'as other;\n';
  final settingsInput = settingsScreenRole.hookInput(app.hook!);
  final settings = _settingsRouteOf(app, settingsInput);
  final entries = [
    for (final RoleData(:value, :origin) in settingsInput.data)
      if (value is SettingsEntry &&
          origin == const ModuleOrigin(SignInModule.id))
        value,
  ];
  if (entries.length != 1) {
    throw StateError(
      'The module ${SignInModule.id} gives the settings screen of '
      '${app.name} ${entries.length} entries, rather than the entry of the '
      'account alone.',
    );
  }
  final entry = entries.single.widget;
  final settingsScreen = settings.route.screen;
  return {
    signInOfAppFile: '''
// What the tests of the sign-in module, in test/sign_in, need to know of
// the app, which the matrix of SMF writes from the data of the router role
// of the app and of the settings screen role of the app, from the texts of
// the module and from the languages of the localization role of the app.
import '${_navigationOf(packageName)}';
import '${entry.import!.resolveUri(packageName)}' as entry;
import '${settingsScreen.import.resolveUri(packageName)}' as settings;
${otherImport}import '${import.resolveUri(packageName)}' as screen;

/// The type of the screen that the app starts on: that of the route that
/// the router role chose, or the fallback start screen of the app entry
/// role in an app that no route can start.
const Type startScreen = screen.$screen;

/// A location of the app that is neither the one that the app starts on
/// nor in the flow of a guard, with the type of its screen, for a user who
/// is somewhere else in the app; empty in an app without such a route.
const List<({AppLocation location, Type screen})> otherPages = [
$otherPage];

/// The location of the route that shows the settings screen.
const AppLocation settingsLocation = ${settings.locationClass}();

/// The type of the settings screen.
const Type settingsScreen = settings.${settingsScreen.className};

/// Whether the settings screen is a destination of the main navigation of
/// the app. Code cannot push such a screen on top of another one.
const bool settingsInMainNavigation = ${_settingsInMainNavigationOf(app)};

/// The type of the widget of the entry of the account on the settings
/// screen.
const Type accountEntry = ${entry.codeWith('entry')};

/// The texts of the screens of sign-in by the code of each language of the
/// app, the first of which the app uses when the device asks for none of
/// them: each text by its name in the module. An app without the
/// localization role has the English texts alone.
const Map<String, Map<String, String>> signInTexts = {
$texts};
''',
  };
}

/// The values that the test of the paywall module gives the keys of the
/// module in .env, the same in every app: an address of the terms of use,
/// which its link opens, and none of the privacy policy, whose link the
/// paywall then leaves out and whose key its note for the developer names.
Map<String, String?> _paywallLinksOf(MatrixApp app) => {
      PaywallModule.termsKey.name: 'https://example.com/terms',
      PaywallModule.privacyKey.name: '',
    };

/// The path in an app of what the matrix writes for the tests of the
/// paywall module: `startScreen`, the type of the screen that the app
/// starts on; `settingsLocation` and `settingsScreen`, the location of the
/// route that the provider of the settings screen role names as the
/// settings screen and the type of that screen, `settingsInMainNavigation`,
/// whether that screen is a destination of the main navigation of the app,
/// and `subscriptionEntry`, the type of the widget of the entry that the
/// module gives that screen, each `null` or `false` in an app without a
/// settings screen; and `paywallTexts`, the texts of the module
/// ([PaywallModule.texts], with [PaywallModule.settingTexts] in an app with
/// a settings screen and [PaywallModule.stepTexts] in an app with an
/// onboarding), each by its name, in each language of the app, by the code
/// of the language. The languages are those of the localization
/// role of the app ([LocalizationRole.localesIn]), in its order, and
/// English alone in an app without the role.
const paywallOfAppFile = 'test/paywall/of_app.dart';

/// The file at [paywallOfAppFile] of [app], an app of the matrix with the
/// router role, whose package is [packageName].
///
/// The screen that the app starts on is that of the route that the router
/// role chose, or the fallback start screen of the app entry role; the file
/// imports its file with the prefix `screen`. The settings screen and the
/// entry come from the data of the settings screen role, whichever module
/// provides it: the entry is the one that the module gave the role.
Map<String, String> _paywallOfAppOf(MatrixApp app, String packageName) {
  final (import, screen) = _startScreenClassOf(app);
  final hasSettings = app.hook!.presentRoles.contains(settingsScreenRole);
  final hasOnboarding = app.hook!.presentRoles.contains(onboardingScreenRole);
  final texts = _textsByLanguageOf(
    app,
    TextsData([
      ...PaywallModule.texts.texts,
      if (hasSettings) ...PaywallModule.settingTexts.texts,
      if (hasOnboarding) ...PaywallModule.stepTexts.texts,
    ]),
  );
  var settingsImports = '';
  var settings = '''
/// The location of the route that shows the settings screen, or `null` in
/// an app without one.
const AppLocation? settingsLocation = null;

/// The type of the settings screen, or `null` in an app without one.
const Type? settingsScreen = null;

/// Whether the settings screen is a destination of the main navigation of
/// the app. Code cannot push such a screen on top of another one.
const bool settingsInMainNavigation = false;

/// The type of the widget of the entry of the subscription on the settings
/// screen, or `null` in an app without one.
const Type? subscriptionEntry = null;
''';
  if (hasSettings) {
    final input = settingsScreenRole.hookInput(app.hook!);
    final route = _settingsRouteOf(app, input);
    final entries = [
      for (final RoleData(:value, :origin) in input.data)
        if (value is SettingsEntry &&
            origin == const ModuleOrigin(PaywallModule.id))
          value,
    ];
    if (entries.length != 1) {
      throw StateError(
        'The module ${PaywallModule.id} gives the settings screen of '
        '${app.name} ${entries.length} entries, rather than the entry of the '
        'subscription alone.',
      );
    }
    final entry = entries.single.widget;
    final settingsScreen = route.route.screen;
    settingsImports =
        "import '${entry.import!.resolveUri(packageName)}' as entry;\n"
        "import '${settingsScreen.import.resolveUri(packageName)}' "
        'as settings;\n';
    settings = '''
// The constants have the types of an app without a settings screen, where
// they are `null`, so that the tests read them alike in every app.
// ignore_for_file: unnecessary_nullable_for_final_variable_declarations

/// The location of the route that shows the settings screen, or `null` in
/// an app without one.
const AppLocation? settingsLocation = ${route.locationClass}();

/// The type of the settings screen, or `null` in an app without one.
const Type? settingsScreen = settings.${settingsScreen.className};

/// Whether the settings screen is a destination of the main navigation of
/// the app. Code cannot push such a screen on top of another one.
const bool settingsInMainNavigation = ${_settingsInMainNavigationOf(app)};

/// The type of the widget of the entry of the subscription on the settings
/// screen, or `null` in an app without one.
const Type? subscriptionEntry = ${entry.codeWith('entry')};
''';
  }
  return {
    paywallOfAppFile: '''
// What the tests of the paywall module, in test/paywall, need to know of
// the app, which the matrix of SMF writes from the data of the router role
// of the app and of the settings screen role of the app, from the texts of
// the module and from the languages of the localization role of the app.
import '${_navigationOf(packageName)}';
${settingsImports}import '${import.resolveUri(packageName)}' as screen;

/// The type of the screen that the app starts on: that of the route that
/// the router role chose, or the fallback start screen of the app entry
/// role in an app that no route can start.
const Type startScreen = screen.$screen;

$settings
/// The texts of the paywall by the code of each language of the app, the
/// first of which the app uses when the device asks for none of them: each
/// text by its name in the module. An app without the localization role has
/// the English texts alone.
const Map<String, Map<String, String>> paywallTexts = {
$texts};
''',
  };
}

/// The path in an app of what the matrix writes for the test of the step of
/// the paywall module in the onboarding: `onboardingScreen`, the type of the
/// screen of the route that the provider of the onboarding screen role
/// names ([OnboardingScreenRole.screenIn]), and `newOnboardingScreen()`,
/// which creates one as that route does.
const paywallStepOnboardingFile = 'test/paywall_step/onboarding.dart';

/// The file at [paywallStepOnboardingFile] of [app], an app of the matrix
/// with the paywall module and the onboarding screen role, whose package is
/// [packageName].
///
/// Throws a [StateError] if no module names a route of its own as the
/// onboarding screen, which the rules of the role report in an app of the
/// matrix.
Map<String, String> _paywallStepOf(MatrixApp app, String packageName) {
  final route = onboardingScreenRole.screenIn(
    onboardingScreenRole.hookInput(app.hook!),
  );
  if (route == null) {
    throw StateError(
      'No module of ${app.name} names a route of its own as the onboarding '
      'screen.',
    );
  }
  final screen = route.route.screen;
  return {
    paywallStepOnboardingFile: '''
// The onboarding screen of the app, which the matrix of SMF writes from the
// data of the onboarding screen role of the app for the test of the step of
// the paywall module in the onboarding.
import 'package:flutter/widgets.dart';
import '${screen.import.resolveUri(packageName)}' as screen;

/// The type of the onboarding screen: that of the route that the provider
/// of the onboarding screen role names.
const Type onboardingScreen = screen.${screen.className};

/// Creates an onboarding screen, as the route of the screen does.
Widget newOnboardingScreen() => screen.${screen.className}();
''',
  };
}

/// The file and the name of the class of the screen that [app], an app of
/// the matrix with the router role, starts on: the screen of the route
/// that the role chose to start the app on, or the fallback start screen of
/// the app entry role when no route of its modules can start it.
(ImportRef, String) _startScreenClassOf(MatrixApp app) {
  final start = routerRole.startIn(routerRole.hookInput(app.hook!))?.route;
  return switch (start?.screen) {
    final screen? => (screen.import, screen.className),
    null => (
        AppEntryRole.fallbackStartScreen.importRef,
        AppEntryRole.fallbackStartScreen.name,
      ),
  };
}

/// The entries of a Dart map of the [texts] of a module in each language
/// of [app], an app of the matrix: for the code of each language, each
/// text by its name. The languages are those of the localization role of
/// the app, in its order, or English alone in an app without the role. A
/// text without a translation into a language is the English one there.
String _textsByLanguageOf(MatrixApp app, TextsData texts) {
  final hook = app.hook!;
  final languages = hook.presentRoles.contains(localizationRole)
      ? localizationRole.localesIn(localizationRole.hookInput(hook))
      : const ['en'];
  final entries = StringBuffer();
  for (final language in languages) {
    entries.writeln('  ${SmfNames.dartString(language)}: {');
    for (final text in texts.texts) {
      final name = SmfNames.dartString(text.name);
      final shown = SmfNames.dartString(text.textIn(language) ?? text.en);
      entries.writeln('    $name: $shown,');
    }
    entries.writeln('  },');
  }
  return '$entries';
}

/// The name under which the listener of Firebase Analytics logs the
/// screen that [app] starts on: the full name of the route that the router
/// role chose for it, such as `home.home`, or `/` for the fallback start
/// screen of its app entry, when no route of its modules can start it.
String _startScreenOf(MatrixApp app) =>
    routerRole.startIn(routerRole.hookInput(app.hook!))?.fullName ?? '/';

/// Whether an app of the matrix has the module [id].
bool Function(MatrixApp app) _has(ModuleId id) =>
    (app) => app.modules.contains(id);
