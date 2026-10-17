@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_local_notifications/bundles/local_notifications_bundle.dart';
import 'package:smf_local_notifications/smf_local_notifications.dart';
import 'package:smf_local_notifications/src/agents.dart';
import 'package:smf_local_notifications/src/readme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, shared_preferences, a provider of the preferences role, which
/// the notifications role requires, and settings and gen_l10n, providers of
/// the settings screen role and of the localization role, which the
/// notifications role uses, with go_router, which the settings screen
/// requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  SettingsModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
  LocalNotificationsModule(),
];

/// The package of the Android code of flutter_local_notifications, which
/// has its receivers.
const _package = 'com.dexterous.flutterlocalnotifications';

/// The namespace of the attributes of Android in a manifest.
const _androidNamespace = 'http://schemas.android.com/apk/res/android';

/// The library of flutter_local_notifications that the service imports.
const _plugin = 'flutter_local_notifications.dart';

/// What the stand-in of the plugin notes of the question of iOS for the
/// permission that the service asks.
const _iOSQuestion =
    'requestPermissions sound true, alert true, badge true, provisional false';

/// The owners of the code of the notifications: this module and the
/// template of its role.
final Set<ContributionOrigin> _notifications = {
  const ModuleOrigin(LocalNotificationsModule.id),
  const RoleTemplateOrigin(notificationsRole),
};

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _resultOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The pubspec [text] as plain maps and lists.
Map<String, Object?> _yamlOf(String text) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(text))! as Map<String, Object?>;
}

/// The parsed file at [path] of [app].
CompilationUnit _unitOf(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The methods of the class [name] in [unit], by name.
Map<String, MethodDeclaration> _methodsOf(CompilationUnit unit, String name) {
  final declaration =
      unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          );
  return {
    for (final member in declaration.body.members)
      if (member is MethodDeclaration) member.name.lexeme: member,
  };
}

/// The inline code of [markdown]: what stands between two backticks,
/// outside its blocks of code.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(
        markdown.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
      ))
        match[1]!,
    };

/// The code that the modules and the templates of the roles put into the
/// phases of start-up in the app of [result], phase after phase, each as
/// its contributor and its code: what `bootstrap()` runs, whichever module
/// provides the app entry.
List<String> _startUpOf(ContractResult result) => [
      for (final phase in const [
        AppEntryRole.bootstrapEarly,
        AppEntryRole.bootstrapPlatform,
        AppEntryRole.bootstrapDi,
        AppEntryRole.bootstrapLate,
      ])
        for (final collected
            in result.app!.socketOrders[phase]?.contributions ??
                const <Collected>[])
          [
            '${collected.origin}:',
            (collected.contribution as SocketContribution).fragment!.code,
          ].join(' '),
    ];

/// Runs the service of the module on the stand-in for
/// flutter_local_notifications, on Android and on iOS, and sends back what
/// reached the plugin for each call, what each call ended with, the tap
/// that launched the app and the taps that the service told of.
///
/// It imports the file of the module and the file of the role with
/// `NotificationsService`, which need nothing but the stand-ins.
const _script = r'''
import 'dart:convert';
import 'dart:isolate';

import 'package:contract_app/core/notifications/local_notifications_service.dart';
import 'package:contract_app/core/notifications/notifications_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart';

String tapOf(NotificationTap? tap) =>
    tap == null ? 'none' : '${tap.id} ${tap.data}';

/// Lets the events of the streams reach their listeners.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// What reached the plugin while [action] ran, and what it ended with.
Future<List<Object?>> step(Future<Object?> Function() action) async {
  pluginCalls.clear();
  Object? outcome;
  try {
    outcome = await action();
  } on Object catch (error) {
    outcome = 'threw $error';
  }
  return [...pluginCalls, if (outcome != null) '= $outcome'];
}

NotificationAppLaunchDetails launchedBy(int? id, String? payload) =>
    NotificationAppLaunchDetails(
      true,
      notificationResponse: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: id,
        payload: payload,
      ),
    );

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};

  // Android, which a test of a Flutter app has by default.
  platformLaunch = launchedBy(4, jsonEncode({'screen': 'inbox'}));
  late NotificationsService service;
  result['open on Android'] = await step(() async {
    service = await openLocalNotifications();
    return null;
  });
  result['implementation'] = '${service.runtimeType}';
  result['launch tap'] = tapOf(service.launchTap);
  result['broadcast taps'] = service.taps.isBroadcast;
  final launches = <String>[];
  for (final launch in [
    launchedBy(5, 'not JSON'),
    launchedBy(null, '{}'),
    const NotificationAppLaunchDetails(
      false,
      notificationResponse: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 6,
      ),
    ),
    const NotificationAppLaunchDetails(true),
    null,
  ]) {
    platformLaunch = launch;
    launches.add(tapOf((await openLocalNotifications()).launchTap));
  }
  result['other launches'] = launches;
  platformLaunch = null;
  service = await openLocalNotifications();

  final heard = <String>[];
  final subscription = service.taps.listen((tap) => heard.add(tapOf(tap)));
  platformTaps(3, jsonEncode({'screen': 'inbox', 'id': '7'}));
  for (final payload in [
    'not JSON',
    '["a list"]',
    '{"count": 1}',
    '',
    null,
  ]) {
    platformTaps(8, payload);
  }
  platformTaps(null, '{}');
  await settle();
  result['taps'] = [...heard];
  final again = await openLocalNotifications();
  final heardAgain = <String>[];
  again.taps.listen((tap) => heardAgain.add(tapOf(tap)));
  heard.clear();
  platformTaps(9, null);
  await settle();
  result['taps after an open again'] = [[...heard], heardAgain];
  await subscription.cancel();
  service = again;

  final at = DateTime.utc(2100, 1, 2, 3, 4, 5);
  result['show'] = await step(
    () => service.show(
      const AppNotification(
        id: 5,
        title: 'Title',
        body: 'Body',
        data: {'screen': 'inbox'},
      ),
    ),
  );
  result['schedule'] = await step(
    () => service.schedule(
      const AppNotification(
        id: -4,
        title: 'Later',
        data: {'notifications.owner': 'tests'},
      ),
      at.toLocal(),
    ),
  );
  result['show of a scheduled id'] = await step(
    () => service.show(const AppNotification(id: -4, title: 'Now')),
  );
  await FlutterLocalNotificationsPlugin().zonedSchedule(
    id: 10,
    scheduledDate: TZDateTime.from(at, UTC),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails('other', 'Other'),
    ),
    androidScheduleMode: AndroidScheduleMode.exact,
    payload: 'not JSON',
  );
  await service.schedule(
    const AppNotification(id: 11, title: 'Eleven', data: {'a': 'b'}),
    at,
  );
  result['scheduled'] = [
    for (final notification in await service.scheduled())
      '${notification.id} "${notification.title}" ${notification.body} '
          '${notification.data}',
  ];
  result['cancel'] = await step(() => service.cancel(11));
  result['cancelAll'] = await step(service.cancelAll);
  result['openSettings'] = await step(service.openSettings);

  final requests = <String, Object?>{};
  for (final answer in ['allows', 'refuses', 'none', 'fails']) {
    platformEnabled = false;
    systemAnswer = answer;
    requests[answer] = await step(service.request);
  }
  platformEnabled = true;
  systemAnswer = 'none';
  requests['enabled'] = await step(service.request);
  // A request that starts while the app is out of the foreground, as
  // under the control center.
  platformEnabled = false;
  systemAnswer = 'refuses';
  WidgetsBinding.instance
      .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  requests['out of the foreground'] = await step(service.request);
  WidgetsBinding.instance
      .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  platformEnabled = true;
  result['requests on Android'] = requests;
  result['enabled on Android'] = await step(service.areEnabled);

  // iOS.
  defaultTargetPlatform = TargetPlatform.iOS;
  platformEnabled = false;
  platformLaunch = launchedBy(12, jsonEncode({'screen': 'inbox'}));
  result['open on iOS'] = await step(() async {
    service = await openLocalNotifications();
    return null;
  });
  result['launch tap on iOS'] = tapOf(service.launchTap);
  final requestsOnIOS = <String, Object?>{};
  for (final answer in ['refuses', 'none']) {
    systemAnswer = answer;
    requestsOnIOS[answer] = await step(service.request);
  }
  result['requests on iOS'] = requestsOnIOS;
  result['enabled on iOS'] = await step(service.areEnabled);
  platformEnabled = true;
  platformAlertsOff = true;
  result['enabled on iOS without alerts'] = await step(service.areEnabled);
  port.send(result);
}
''';

void main() {
  const module = LocalNotificationsModule();

  group('LocalNotificationsModule', () {
    test('is infrastructure that provides the notifications role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('local_notifications'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {notificationsRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveUses, notificationsRole.uses);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, flutter_local_notifications and timezone, its '
        'implementation of the service, opened asynchronously, what the '
        'package needs in the native projects, its section of the README '
        'and its note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(10));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(localNotificationsBundle));
      expect(brick.bundle.name, 'local_notifications');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [serviceFile],
      );
      expect(brick.vars, isEmpty);
      expect(brick.when, isEmpty);
      final plugin = contributions[1] as PubspecDependency;
      expect(
        (plugin.package, plugin.constraint, plugin.dev),
        ('flutter_local_notifications', '^22.3.2', false),
      );
      final timezone = contributions[2] as PubspecDependency;
      expect(
        (timezone.package, timezone.constraint, timezone.dev),
        ('timezone', '^0.11.0', false),
      );
      final data = contributions[3] as RoleData<Object>;
      expect(data.role, notificationsRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isTrue);
      expect(implementation.type.name, 'LocalNotificationsService');
      expect(implementation.init!.name, 'openLocalNotifications');
      expect(
        implementation.type.import,
        const ImportRef.app(
          'core/notifications/local_notifications_service.dart',
        ),
      );
      expect(implementation.init!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      final desugaring = contributions[4] as SocketContribution;
      expect(desugaring.socket, AppEntryRole.androidCoreLibraryDesugaring);
      expect(desugaring.entryValue, '2.1.4');
      final permission = contributions[5] as SocketContribution;
      expect(permission.socket, AppEntryRole.androidManifestPermissions);
      expect(
        permission.entryKey,
        'android.permission.RECEIVE_BOOT_COMPLETED',
      );
      final components = contributions[6] as SocketContribution;
      expect(
        components.socket,
        AppEntryRole.androidManifestApplicationComponents,
      );
      expect(components.fragment, const Fragment(receivers));
      final launch = contributions[7] as SocketContribution;
      expect(launch.socket, AppEntryRole.iosAppDelegateLaunch);
      expect(
        launch.fragment,
        const Fragment(
          '    UNUserNotificationCenter.current().delegate = self',
        ),
      );
      final readme = contributions[8] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      final note = contributions[9] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, notificationsRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });

    test(
        'declares the two receivers of the package that show the scheduled '
        'notifications, also after a restart of the device or an update of '
        'the app, each indented as a child of the application', () {
      final application = XmlDocument.parse(
        '<application xmlns:android="$_androidNamespace">\n'
        '$receivers\n'
        '</application>',
      ).rootElement;
      String nameOf(XmlElement element) =>
          element.getAttribute('android:name')!;

      expect(
        [
          for (final receiver in application.childElements)
            (
              receiver.name.local,
              nameOf(receiver),
              receiver.getAttribute('android:exported'),
            ),
        ],
        [
          ('receiver', '$_package.ScheduledNotificationReceiver', 'false'),
          ('receiver', '$_package.ScheduledNotificationBootReceiver', 'false'),
        ],
      );
      expect(
        [
          for (final action
              in application.childElements.last.findAllElements('action'))
            nameOf(action),
        ],
        [
          'android.intent.action.BOOT_COMPLETED',
          'android.intent.action.MY_PACKAGE_REPLACED',
          'android.intent.action.QUICKBOOT_POWERON',
          'com.htc.intent.action.QUICKBOOT_POWERON',
        ],
      );
      expect(
        [
          for (final line in receivers.split('\n'))
            line.length - line.trimLeft().length,
        ].reduce((a, b) => a < b ? a : b),
        8,
      );
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the module with the settings screen role and the '
        'localization role, which the notifications role uses, and without '
        'each', () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested
                .contains(LocalNotificationsModule.id))
              result.contractCase.name,
        ],
        [
          'local_notifications with settings_screen, localization',
          'local_notifications with settings_screen',
          'local_notifications with localization',
          'local_notifications',
        ],
      );
      expect(
        await ContractHarness(ModuleRegistry(_modules)).uncheckedProviders(),
        isEmpty,
      );
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test(
        'renders the same service in every app, which type-checks with '
        'flutter_local_notifications and timezone', () async {
      final withService = [
        for (final result in results)
          if (result.app!.files.containsKey(serviceFile)) result,
      ];
      expect(withService, hasLength(4));
      expect(
        {
          for (final result in withService)
            result.app!.files[serviceFile]!.text,
        },
        hasLength(1),
      );
      for (final result in withService) {
        expect(
          [
            for (final file in result.app!.files.values)
              if (file.owner == const ModuleOrigin(LocalNotificationsModule.id))
                file.path,
          ],
          [serviceFile],
          reason: '${result.contractCase}',
        );
        final app = DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(
              {const ModuleOrigin(LocalNotificationsModule.id)},
            ),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [LocalNotificationsModule.id]);
      app = result.app!;
      without = (await _resultOf(const [SharedPreferencesModule.id])).app!;
    });

    test(
        'is the app of the preferences but for the files of the notifications '
        'role, the service, its packages, the start of the notifications, '
        'what the package needs in the native projects, and the sections of '
        'the notifications in the README and in the guide for coding agents',
        () {
      expect(app.files.keys.toSet(), {
        ...without.files.keys,
        ...notificationsRole.interface.files,
        serviceFile,
      });
      expect(
        app.files[serviceFile]!.owner,
        const ModuleOrigin(LocalNotificationsModule.id),
      );
      final changed = <String>[];
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        expect(app.files[path]!.owner, file.owner, reason: path);
        if (app.files[path]!.text != file.text) changed.add(path);
      }
      // The provider of the app entry renders the start-up, which now
      // opens the notifications, into a file of its own, whichever module
      // it is, and the template of the preferences role its restorers,
      // that of the notifications among them.
      final fromRole = [
        for (final path in changed)
          if (app.files[path]!.addedImports.any(
            (added) =>
                added.contributor ==
                const RoleTemplateOrigin(notificationsRole),
          ))
            path,
      ];
      final entries = {
        for (final module in result.resolution!.providersOf(appEntryRole))
          ModuleOrigin(module.id),
      };
      final startUp = [
        for (final path in fromRole)
          if (entries.contains(app.files[path]!.owner)) path,
      ];
      expect(startUp, hasLength(1));
      expect(fromRole.toSet().difference(startUp.toSet()), {
        PreferencesRole.file,
      });
      expect(
        changed.toSet().difference(fromRole.toSet()),
        {
          'pubspec.yaml',
          AppEntryRole.readmeFile,
          AppEntryRole.agentsFile,
          AppEntryRole.gradleAppFile,
          AppEntryRole.androidManifestFile,
          AppEntryRole.appDelegateFile,
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['dependencies'],
        {
          ...(_yamlOf(without.files['pubspec.yaml']!.text)['dependencies']!
              as Map<String, Object?>),
          'flutter_local_notifications': '^22.3.2',
          'timezone': '^0.11.0',
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['environment'],
        _yamlOf(without.files['pubspec.yaml']!.text)['environment'],
      );
    });

    test(
        'opens the notifications in bootstrap() once the preferences are '
        'open, and waits for the service, which opens asynchronously', () {
      expect(_startUpOf(result), [
        'role:preferences: await initPreferences();',
        'role:notifications: await initNotifications();',
      ]);
      final init = _unitOf(app, NotificationsRole.controllerFile)
          .declarations
          .whereType<FunctionDeclaration>()
          .singleWhere(
            (function) => function.name.lexeme == 'initNotifications',
          );
      final body = init.functionExpression.body as BlockFunctionBody;
      expect(
        [for (final statement in body.block.statements) '$statement'],
        [
          '_notificationsService = await impl0.openLocalNotifications();',
          'await appNotifications.start(_notificationsService);',
        ],
      );
    });

    test(
        'turns on core library desugaring, declares the receivers of the '
        'package with the permission for a restart of the device, and sets '
        'the delegate of the notification center before the launch '
        'finishes', () {
      final gradle = app.files[AppEntryRole.gradleAppFile]!.text;
      final manifest = XmlDocument.parse(
        app.files[AppEntryRole.androidManifestFile]!.text,
      ).rootElement;
      final delegate = app.files[AppEntryRole.appDelegateFile]!.text;

      expect(
        gradle,
        allOf(
          contains('isCoreLibraryDesugaringEnabled = true'),
          contains(
            'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
          ),
        ),
      );
      expect(
        [
          for (final permission in manifest.findElements('uses-permission'))
            permission.getAttribute('android:name'),
        ],
        contains('android.permission.RECEIVE_BOOT_COMPLETED'),
      );
      expect(
        [
          for (final receiver
              in manifest.getElement('application')!.findElements('receiver'))
            receiver.getAttribute('android:name'),
        ],
        [
          '$_package.ScheduledNotificationReceiver',
          '$_package.ScheduledNotificationBootReceiver',
        ],
      );
      expect(
        RegExp(
          r'didFinishLaunchingWithOptions[\s\S]*'
          r'UNUserNotificationCenter\.current\(\)\.delegate = self\n'
          r'[\s\S]*super\.application\(',
        ).hasMatch(delegate),
        isTrue,
        reason: delegate,
      );
      // Without the module, the app has none of them.
      expect(
        without.files[AppEntryRole.gradleAppFile]!.text,
        isNot(contains('desugar')),
      );
      expect(
        without.files[AppEntryRole.androidManifestFile]!.text,
        isNot(contains('receiver')),
      );
      expect(
        without.files[AppEntryRole.appDelegateFile]!.text,
        isNot(contains('UNUserNotificationCenter')),
      );
    });

    group('the implementation', () {
      late CompilationUnit unit;

      setUpAll(() => unit = _unitOf(app, serviceFile));

      test(
          'is the service of the role on FlutterLocalNotificationsPlugin, '
          'which openLocalNotifications() opens', () {
        final declaration =
            unit.declarations.whereType<ClassDeclaration>().singleWhere(
                  (declaration) =>
                      declaration.namePart.typeName.lexeme ==
                      'LocalNotificationsService',
                );
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'NotificationsService',
        );
        final open =
            unit.declarations.whereType<FunctionDeclaration>().singleWhere(
                  (function) =>
                      function.name.lexeme == 'openLocalNotifications',
                );
        expect('${open.returnType}', 'Future<NotificationsService>');
        expect(open.functionExpression.parameters!.parameters, isEmpty);
        expect(
          [
            for (final directive
                in unit.directives.whereType<ImportDirective>())
              '$directive',
          ],
          [
            "import 'dart:async';",
            "import 'dart:convert';",
            "import 'package:flutter/widgets.dart';",
            equals(
              "import 'package:flutter_local_notifications/$_plugin';",
            ),
            "import 'package:timezone/timezone.dart' as tz;",
            "import 'notifications_service.dart';",
          ],
        );
      });

      test(
          'implements every member of the service with the signature of the '
          'interface', () {
        String signatureOf(MethodDeclaration method) =>
            '${method.returnType} ${method.propertyKeyword ?? ''} '
            '${method.parameters ?? ''}';
        final interface = _methodsOf(
          _unitOf(app, NotificationsRole.serviceFile),
          'NotificationsService',
        );
        final members = _methodsOf(unit, 'LocalNotificationsService');

        expect(
          {
            for (final name in interface.keys)
              if (members[name] case final method?) name: signatureOf(method),
          },
          {
            for (final MapEntry(key: name, value: method) in interface.entries)
              if (name != 'launchTap') name: signatureOf(method),
          },
        );
        // The launch tap is a field, which a getter of the interface reads.
        expect(interface.keys, hasLength(10));
        expect(
          app.files[serviceFile]!.text,
          contains('  @override\n  final NotificationTap? launchTap;\n'),
        );
      });
    });

    group('the service', () {
      late Map<Object?, Object?> sent;

      setUpAll(() async {
        final dartApp = DartApp.write(app);
        try {
          sent = (await dartApp.run(_script))! as Map<Object?, Object?>;
        } finally {
          dartApp.delete();
        }
      });

      /// The title that the app has on the screens of the system, which
      /// the channel of the app has as its name.
      const appTitle = 'Contract App';

      test(
          'opens the plugin with the small icon of the role, creates the '
          'channel of the app with its name and a high importance, and reads '
          'the tap that launched the app, on Android', () {
        expect(sent['implementation'], 'LocalNotificationsService');
        expect(sent['open on Android'], [
          'initialize Android ${NotificationsRole.androidIcon}',
          equals(
            'createNotificationChannel ${NotificationsRole.defaultChannel} '
            '$appTitle high',
          ),
          'getNotificationAppLaunchDetails',
        ]);
        expect(sent['launch tap'], '4 {screen: inbox}');
      });

      test(
          'opens the plugin on iOS without the question for the permission, '
          'which it asks by default, and presents a notification while the '
          'app is in the foreground', () {
        expect(sent['open on iOS'], [
          equals(
            'initialize iOS asks alert false, sound false, badge false, '
            'provisional false; presents alert true, banner true, list '
            'true, sound true',
          ),
          'getNotificationAppLaunchDetails',
        ]);
        expect(sent['launch tap on iOS'], '12 {screen: inbox}');
      });

      test(
          'has a launch tap only for a tap with an id that launched the app, '
          'with no data for a payload that the app did not write', () {
        expect(
          sent['other launches'],
          ['5 {}', 'none', 'none', 'none', 'none'],
        );
      });

      test(
          'tells of each tap with an id on a broadcast stream, with the data '
          'that the app gave the notification, and with none for a payload '
          'that it did not write', () {
        expect(sent['broadcast taps'], isTrue);
        expect(sent['taps'], [
          '3 {screen: inbox, id: 7}',
          for (var i = 0; i < 5; i++) '8 {}',
        ]);
      });

      test('only the service of the last open of the plugin hears of a tap',
          () {
        expect(sent['taps after an open again'], [
          <String>[],
          ['9 {}'],
        ]);
      });

      test(
          'shows a notification in the channel of the app with a high '
          'importance and its data as JSON, and cancels the scheduled one of '
          'its id first', () {
        expect(sent['show'], [
          'pendingNotificationRequests',
          equals(
            'show 5 Title Body {"screen":"inbox"} in '
            '${NotificationsRole.defaultChannel} $appTitle, high, priority 1',
          ),
        ]);
        expect(sent['show of a scheduled id'], [
          'pendingNotificationRequests',
          'cancel -4',
          equals(
            'show -4 Now null {} in ${NotificationsRole.defaultChannel} '
            '$appTitle, high, priority 1',
          ),
        ]);
      });

      test(
          'schedules a notification with an inexact alarm at its time in '
          'UTC, and lists the scheduled ones with what they have', () {
        expect(sent['schedule'], [
          equals(
            'zonedSchedule -4 Later null {"notifications.owner":"tests"} at '
            '2100-01-02T03:04:05.000Z in Etc/UTC, inexactAllowWhileIdle, '
            'in ${NotificationsRole.defaultChannel}',
          ),
        ]);
        expect(sent['scheduled'], [
          '10 "" null {}',
          '11 "Eleven" null {a: b}',
        ]);
      });

      test('cancels and opens the settings through the plugin', () {
        expect(sent['cancel'], ['cancel 11']);
        expect(sent['cancelAll'], ['cancelAll']);
        expect(sent['openSettings'], ['openAppNotificationSettings']);
      });

      test(
          'asks the question of the system, and opens the settings of the '
          'system only where it showed none and the app may not show '
          'notifications', () {
        expect(sent['requests on Android'], {
          'allows': ['requestNotificationsPermission'],
          'refuses': ['requestNotificationsPermission'],
          'none': [
            'requestNotificationsPermission',
            'openAppNotificationSettings',
          ],
          'fails': [
            'requestNotificationsPermission',
            '= threw Bad state: The platform broke.',
          ],
          'enabled': ['requestNotificationsPermission'],
          // The question may have shown without a change that the app sees.
          'out of the foreground': ['requestNotificationsPermission'],
        });
        expect(sent['enabled on Android'], [
          'areNotificationsEnabled',
          '= true',
        ]);
        expect(sent['requests on iOS'], {
          'refuses': [
            _iOSQuestion,
          ],
          'none': [
            _iOSQuestion,
            'openAppNotificationSettings',
          ],
        });
        expect(sent['enabled on iOS'], ['checkPermissions', '= false']);
        // iOS keeps the notifications of an app with its alerts off in the
        // notification center.
        expect(
          sent['enabled on iOS without alerts'],
          ['checkPermissions', '= true'],
        );
      });
    });

    group('the section of the module in the README of the app', () {
      test('refers to the section of the notifications role', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(readme, contains('\n## ${NotificationsRole.readmeHeading}\n'));
        expect(
          readmeSection,
          contains('(see the section ${NotificationsRole.readmeHeading})'),
        );
      });

      test(
          'tells what the module set up in the native projects, by the files '
          'of the app entry role', () {
        expect(
          _codeOf(readmeSection),
          containsAll([
            serviceFile,
            AppEntryRole.gradleAppFile,
            AppEntryRole.androidManifestFile,
            AppEntryRole.appDelegateFile,
            bootPermission,
            NotificationsRole.defaultChannel,
          ]),
        );
        expect(readmeSection, contains('`desugar_jdk_libs` 2.1.4'));
      });

      test(
          'tells how to schedule to the minute and what that costs, and that '
          'the actions of a notification are not set up', () {
        expect(
          _codeOf(readmeSection),
          containsAll([
            'android.permission.SCHEDULE_EXACT_ALARM',
            'requestExactAlarmsPermission()',
            'AndroidFlutterLocalNotificationsPlugin',
            'AndroidScheduleMode.exactAllowWhileIdle',
            'ActionBroadcastReceiver',
          ]),
        );
        expect(
          readmeSection,
          contains(
            'Google Play allows exact alarms only for apps whose main '
            'feature needs them',
          ),
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the notifications of the guide, after what '
          'the role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          {
            for (final (origin, heading, note) in notes)
              if (_notifications.contains(origin))
                (origin, heading, note.isOfRole),
          },
          {
            (
              const ModuleOrigin(LocalNotificationsModule.id),
              notificationsRole.description,
              false,
            ),
            (
              const RoleTemplateOrigin(notificationsRole),
              notificationsRole.description,
              true,
            ),
          },
        );
        expect(agentNote, startsWith('With `flutter_local_notifications`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(guide.indexOf('\n## ${notificationsRole.description}\n')),
        );
      });

      test(
          'names the file of the module, the only one of the app that '
          'imports the package, and what that file declares', () {
        final service = DartFileIndexer.index(
          serviceFile,
          app.files[serviceFile]!.text,
        );

        expect(
          _codeOf(agentNote),
          containsAll([
            serviceFile,
            'LocalNotificationsService',
            'NotificationsService',
            'FlutterLocalNotificationsPlugin',
            'appNotifications',
            'notificationChannelId',
            '_details',
            'createNotificationChannel()',
            'AndroidFlutterLocalNotificationsPlugin',
            'openLocalNotifications()',
            'AndroidScheduleMode.inexactAllowWhileIdle',
            AppEntryRole.androidManifestFile,
            AppEntryRole.gradleAppFile,
            AppEntryRole.appDelegateFile,
            'bootstrap()',
            'dexterous.com/flutter/local_notifications',
            'AndroidFlutterLocalNotificationsPlugin.registerWith()',
          ]),
        );
        expect(
          [
            for (final file in app.files.values)
              if (file.path.endsWith('.dart') &&
                  file.text.contains('package:flutter_local_notifications/'))
                file.path,
          ],
          [serviceFile],
        );
        for (final name in [
          'LocalNotificationsService',
          'openLocalNotifications',
          '_details',
        ]) {
          expect(service.declaration(name), isNotNull, reason: name);
        }
        expect(
          app.files[NotificationsRole.serviceFile]!.text,
          contains('const String notificationChannelId = '),
        );
      });
    });

    test('has a README that leads to the page of the module', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains('(https://doc.saymyframe.com/modules/local-notifications)'),
      );
    });
  });
}
