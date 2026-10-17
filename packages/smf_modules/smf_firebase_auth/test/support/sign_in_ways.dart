import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// A module of the tests that gives the auth role a way to sign in with the
/// identity provider [issuer], which needs [needs] of the backend, as a
/// module of a way to sign in does, and knows no provider of the role.
final class WayOfTest extends SmfModule {
  const WayOfTest(this.id, this.issuer, this.appStore, {this.needs = const {}});

  /// The way to sign in of Google, which the module takes, with what it
  /// needs of the backend: the certificate of the Android app, the client
  /// of the iOS app and the client of the server.
  static const google = WayOfTest(
    ModuleId('google_of_test'),
    'https://accounts.google.com',
    AppStoreLogin.thirdParty,
    needs: {
      SignInNeed.androidCertificate,
      SignInNeed.iosClient,
      SignInNeed.serverClient,
    },
  );

  /// A way to sign in of Google that needs nothing of the backend.
  static const googleAlone = WayOfTest(
    ModuleId('google_alone_of_test'),
    'https://accounts.google.com',
    AppStoreLogin.thirdParty,
  );

  /// The way to sign in of Apple, which the module takes, and which needs
  /// nothing of the backend.
  static const apple = WayOfTest(
    ModuleId('apple_of_test'),
    'https://appleid.apple.com',
    AppStoreLogin.privacyFocused,
  );

  /// A way to sign in of Apple that needs the client of the server and the
  /// certificate of the Android app, which the module does not set up for
  /// Apple.
  static const appleWithServer = WayOfTest(
    ModuleId('apple_server_of_test'),
    'https://appleid.apple.com',
    AppStoreLogin.privacyFocused,
    needs: {SignInNeed.serverClient, SignInNeed.androidCertificate},
  );

  /// A way to sign in of another identity provider, which the module does
  /// not take.
  static const other = WayOfTest(
    ModuleId('way_of_test'),
    'https://accounts.example.com',
    AppStoreLogin.privacyFocused,
  );

  /// The modules of these ways to sign in.
  static const List<WayOfTest> all = [
    google,
    googleAlone,
    apple,
    appleWithServer,
    other,
  ];

  /// The id of the module.
  final ModuleId id;

  /// The identity provider of the way to sign in.
  final String issuer;

  /// What the way to sign in is for the App Store.
  final AppStoreLogin appStore;

  /// What the way to sign in needs of the backend.
  final Set<SignInNeed> needs;

  String get _path => 'core/${id.value}/way_of_test.dart';

  /// The way to sign in that it gives the role.
  SignInMethod get method => SignInMethod(
        label: const LocalizedText('label', en: 'Continue with the test'),
        icon: TypeRef('WayOfTestIcon', import: ImportRef.app(_path)),
        platforms: const {AppPlatform.android, AppPlatform.ios},
        credential: FunctionRef(
          'wayOfTestCredential',
          import: ImportRef.app(_path),
        ),
        issuer: issuer,
        appStore: appStore,
        needs: needs,
      );

  static const _source = '''
import 'package:flutter/widgets.dart';

import '../auth/app_session.dart';

Future<SignInCredential?> wayOfTestCredential() async => null;

class WayOfTestIcon extends StatelessWidget {
  const WayOfTestIcon({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'A way to sign in of the tests',
        kind: ModuleKinds.infrastructure,
        requires: const {authRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          MasonBundle(
            name: id.value,
            description: 'The function and the icon of the way to sign in',
            version: '0.1.0',
            files: [
              MasonBundledFile(
                'lib/$_path',
                base64.encode(utf8.encode(_source)),
                'text',
              ),
            ],
          ),
        ),
        authRole.data(method),
      ];
}
