import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

/// The registry of the tests: flutter_core, a router, and a module that
/// fills every socket of the app entry.
ModuleRegistry testRegistry() => ModuleRegistry(const [
      FlutterCoreModule(),
      TestRouterModule(),
      EverySocketModule(),
    ]);

/// Renders the app of [modules] with the contract harness and returns the
/// result, which has no errors.
Future<ContractResult> renderedApp(List<ModuleId> modules) async {
  final result = await ContractHarness(testRegistry()).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  final errors = result.errors;
  if (errors.isNotEmpty || result.app == null) {
    throw StateError('The app of $modules has errors: ${errors.join('\n')}');
  }
  return result;
}

/// A router for the tests: `createAppRouter()` returns a router that shows
/// the fallback start screen, and calls the observer factories of its
/// navigator.
final class TestRouterModule extends SmfModule {
  /// Creates the module.
  const TestRouterModule();

  /// The id of the module.
  static const id = ModuleId('test_router');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A router for the tests',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(routerRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('test_router', {
            RouterRole.appRouterFactoryFile: '''
import 'package:flutter/material.dart';

import '../app/fallback_start_screen.dart';
import 'app_router.dart';
import 'navigation.dart';

/// Creates the router of the app, which shows the fallback start screen.
AppRouter createAppRouter() => _TestRouter();

final class _TestRouter implements AppRouter {
  @override
  late final RouterConfig<Object> config =
      RouterConfig(routerDelegate: _TestDelegate());

  @override
  AppNavigator navigatorOf(BuildContext context) =>
      throw UnsupportedError('The test router does not navigate.');
}

final class _TestDelegate extends RouterDelegate<Object> with ChangeNotifier {
  final List<NavigatorObserver> _observers = [
    for (final create in <NavigatorObserver Function()>[
{{{${RouterRole.observers.tag}}}}
    ])
      create(),
  ];

  @override
  Widget build(BuildContext context) => Navigator(
        observers: _observers,
        pages: const [MaterialPage<Object?>(child: FallbackStartScreen())],
        onDidRemovePage: (page) {},
      );

  @override
  Future<bool> popRoute() async => false;

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
''',
          }),
        ),
      ];
}

/// A module that puts something into every socket of the app entry, as
/// other modules would.
final class EverySocketModule extends SmfModule {
  /// Creates the module.
  const EverySocketModule();

  /// The id of the module.
  static const id = ModuleId('every_socket');

  static const _foundation = ImportRef('package:flutter/foundation.dart');
  static const _widgets = ImportRef('package:flutter/widgets.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Something in every socket of the app entry',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        // The phases of start-up, in the reverse of their order.
        for (final (socket, phase) in [
          (AppEntryRole.bootstrapLate, 'late'),
          (AppEntryRole.bootstrapDi, 'di'),
          (AppEntryRole.bootstrapPlatform, 'platform'),
          (AppEntryRole.bootstrapEarly, 'early'),
        ])
          SocketContribution.code(
            socket,
            Fragment("debugPrint('$phase');", imports: const [_foundation]),
          ),
        const SocketContribution.code(
          AppEntryRole.topLevel,
          Fragment(
            "@pragma('vm:entry-point')\n"
            'Future<void> onBackgroundMessage() async {}',
          ),
        ),
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap('RepaintBoundary(child: ', ')', imports: [_widgets]),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'supportedLocales',
          Fragment("Locale('en')", imports: [_widgets]),
        ),
        const SocketContribution.wrap(
          AppEntryRole.appBuilder,
          Fragment.wrap(
            'MediaQuery.withNoTextScaling(child: ',
            ')',
            imports: [_widgets],
          ),
        ),
        AppEntryRole.iosDeploymentTarget.value('16.0'),
        AppEntryRole.androidManifestPermissions
            .key('android.permission.INTERNET'),
        AppEntryRole.androidManifestApplicationMeta.entry(
          'com.example.every_socket.KEY',
          const AndroidMetaData.value('every socket'),
        ),
        const SocketContribution.code(
          AppEntryRole.mainActivityIntentFilters,
          Fragment(
            '            <intent-filter>\n'
            '                <action android:name="android.intent.action.VIEW"/>\n'
            '                <category android:name="android.intent.category.DEFAULT"/>\n'
            '                <data android:scheme="everysocket"/>\n'
            '            </intent-filter>',
          ),
        ),
        AppEntryRole.infoPlist.entry(
          'UIBackgroundModes',
          const PlistStringArray(['fetch']),
        ),
        AppEntryRole.gradleSettingsPlugins.entry(
          'io.github.ben-manes.versions',
          '0.64.0',
        ),
        AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        AppEntryRole.gradleAppDependencies.entry(
          'androidx.annotation:annotation',
          '1.9.1',
        ),
        AppEntryRole.readmeSections.entry(
          'Every socket',
          'The app has something in every socket of its entry.',
        ),
      ];
}

/// A mason bundle named [name] with the text [files] by path.
MasonBundle bundleOf(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );
