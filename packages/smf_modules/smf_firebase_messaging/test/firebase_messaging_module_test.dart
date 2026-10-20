@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_messaging/bundles/firebase_messaging_bundle.dart';
import 'package:smf_firebase_messaging/smf_firebase_messaging.dart';
import 'package:smf_firebase_messaging/src/agents.dart';
import 'package:smf_firebase_messaging/src/readme.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_local_notifications/smf_local_notifications.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module and firebase_core, which it depends on, local_notifications, a
/// provider of the notifications role, which the push role requires, and
/// shared_preferences, a provider of the preferences role, which the
/// notifications role requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  FirebaseCoreModule(),
  SharedPreferencesModule(),
  LocalNotificationsModule(),
  FirebaseMessagingModule(),
];

/// The owners of the code of the push messages: this module and the
/// template of its role.
final Set<ContributionOrigin> _push = {
  const ModuleOrigin(FirebaseMessagingModule.id),
  const RoleTemplateOrigin(pushRole),
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

/// The members of the class [name] in [unit] that the class declares with
/// the signature of a member of an interface, each with that signature: a
/// method or a getter, and a field, which implements a getter.
Map<String, String> _membersOf(CompilationUnit unit, String name) {
  final declaration =
      unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          );
  return {
    for (final member in declaration.body.members)
      if (member is MethodDeclaration && !member.name.lexeme.startsWith('_'))
        member.name.lexeme: '${member.returnType} '
            '${member.propertyKeyword == null ? '' : 'get '}'
            '${member.parameters ?? ''}'
      else if (member is FieldDeclaration)
        for (final variable in member.fields.variables)
          if (!variable.name.lexeme.startsWith('_'))
            variable.name.lexeme: '${member.fields.type} get ',
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

/// Runs the service of the module on the stand-in for firebase_messaging,
/// on Android and on iOS, and sends back what reached the platform for each
/// call, what each call ended with, what the service printed, and the
/// messages, the taps and the addresses that the service told of.
///
/// It imports the file of the module and the file of the role with
/// `PushService`, which need nothing but the stand-ins.
const _script = r'''
import 'dart:isolate';

import 'package:contract_app/core/push/firebase_push_service.dart';
import 'package:contract_app/core/push/push_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

String describe(PushMessage? message) => message == null
    ? 'none'
    : '${message.id} | ${message.title} | ${message.body} | ${message.data}';

/// Lets the events of the streams reach their listeners.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Every call that reached the platform in the script.
final everyCall = <String>[];

/// What reached the platform while [action] ran, and what it ended with.
Future<List<Object?>> step(Future<Object?> Function() action) async {
  firebaseCalls.clear();
  Object? outcome;
  try {
    outcome = await action();
  } on Object catch (error) {
    outcome = 'threw $error';
  }
  everyCall.addAll(firebaseCalls);
  return [...firebaseCalls, if (outcome != null) '= $outcome'];
}

/// What the service printed while [action] ran.
Future<List<String>> printedBy(Future<void> Function() action) async {
  printed.clear();
  await action();
  return [...printed];
}

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};

  // Android, which a test of a Flutter app has by default.
  late PushService service;
  result['create on Android'] = await step(() async {
    service = createFirebasePushService();
    await settle();
    return null;
  });
  result['implementation'] = '${service.runtimeType}';
  result['shows on Android'] = service.platformShowsInForeground;
  result['broadcast'] = [
    service.messages.isBroadcast,
    service.taps.isBroadcast,
    service.addressChanges.isBroadcast,
  ];
  result['address'] = await step(service.address);
  failNext['getToken'] = FirebaseException(
    plugin: 'firebase_messaging',
    code: 'unknown',
    message: 'java.io.IOException: SERVICE_NOT_AVAILABLE',
  );
  result['printed without Google Play services'] = await printedBy(() async {
    result['address without Google Play services'] =
        await step(service.address);
  });
  token = null;
  result['address while Firebase has none'] = await step(service.address);
  token = 'token of the device';

  result['no launch message'] =
      await step(() async => describe(await service.launchMessage()));
  initialMessage = const RemoteMessage(
    messageId: 'launch-1',
    notification: RemoteNotification(title: 'Hello', body: 'World'),
    data: {'screen': 'inbox', 'count': 3},
  );
  result['launch message'] =
      await step(() async => describe(await service.launchMessage()));
  failNext['getInitialMessage'] = StateError('The platform broke.');
  result['printed without a launch message'] = await printedBy(() async {
    result['launch message that fails'] =
        await step(() async => describe(await service.launchMessage()));
  });

  final messages = <String>[];
  final taps = <String>[];
  final addresses = <String>[];
  service.messages.listen((message) => messages.add(describe(message)));
  service.taps.listen((message) => taps.add(describe(message)));
  service.addressChanges.listen(addresses.add);
  platformDelivers(
    const RemoteMessage(
      messageId: 'message-1',
      notification: RemoteNotification(title: 'Title', body: 'Body'),
      data: {
        'text': 'a text',
        'number': 1,
        'flag': true,
        'nested': {
          'list': [1, 'two'],
        },
        'none': null,
      },
    ),
  );
  platformDelivers(const RemoteMessage(data: {'only': 'data'}));
  platformOpens(
    const RemoteMessage(
      messageId: 'message-2',
      notification: RemoteNotification(title: 'Tapped'),
      data: {'screen': 'inbox'},
    ),
  );
  platformRefreshes('a new token');
  await settle();
  result['messages'] = messages;
  result['taps'] = taps;
  result['addresses'] = addresses;

  defaultTargetPlatform = TargetPlatform.iOS;
  result['create on iOS'] = await step(() async {
    service = createFirebasePushService();
    await settle();
    return null;
  });
  result['shows on iOS'] = service.platformShowsInForeground;
  result['address on iOS'] = await step(service.address);
  apnsToken = null;
  result['printed on iOS without an APNs token'] = await printedBy(() async {
    result['address on iOS without an APNs token'] =
        await step(service.address);
  });
  result['launch message on iOS'] =
      await step(() async => describe(await service.launchMessage()));

  // The token of the Apple Push Notification service comes after the app
  // asked for the address, and the plugin tells of no registration token.
  service = createFirebasePushService();
  final cameLate = <String>[];
  final watching = service.addressChanges.listen(cameLate.add);
  result['address before the APNs token'] = await step(service.address);
  firebaseCalls.clear();
  apnsToken = 'an APNs token that came late';
  final until = DateTime.now().add(const Duration(seconds: 5));
  while (cameLate.isEmpty && DateTime.now().isBefore(until)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  result['calls until the APNs token came'] = [...firebaseCalls];
  result['addresses once the APNs token came'] = cameLate;
  await watching.cancel();

  // No timer outlives the last listener.
  apnsToken = null;
  service = createFirebasePushService();
  final listening = service.addressChanges.listen((_) {});
  await service.address();
  await Future<void>.delayed(const Duration(milliseconds: 700));
  firebaseCalls.clear();
  await listening.cancel();
  await Future<void>.delayed(const Duration(milliseconds: 1200));
  result['calls once nothing listens'] = [...firebaseCalls];
  // Nor does a service whose address failed before anyone listened ask.
  service = createFirebasePushService();
  await service.address();
  firebaseCalls.clear();
  await Future<void>.delayed(const Duration(milliseconds: 700));
  result['calls without a listener'] = [...firebaseCalls];

  result['every call'] = everyCall;
  port.send(result);
}
''';

void main() {
  const module = FirebaseMessagingModule();

  group('FirebaseMessagingModule', () {
    test(
        'is infrastructure that provides the push role, and depends on '
        'firebase_core', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('firebase_messaging'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {pushRole});
      expect(descriptor.dependsOn, {FirebaseCoreModule.id});
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveUses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, firebase_messaging below 17, its '
        'implementation of the service, created without waiting, the channel '
        'and the icon of the notifications of the app for the messages that '
        'Android shows, its section of the README and its note for coding '
        'agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(7));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(firebaseMessagingBundle));
      expect(brick.bundle.name, 'firebase_messaging');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [serviceFile],
      );
      expect(brick.vars, isEmpty);
      final plugin = contributions[1] as PubspecDependency;
      // firebase_messaging 17 needs firebase_core 5, and the Firebase
      // modules share firebase_core 4.
      expect(
        (plugin.package, plugin.constraint, plugin.dev),
        ('firebase_messaging', '^16.7.0', false),
      );
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, pushRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'FirebasePushService');
      expect(implementation.create!.name, 'createFirebasePushService');
      expect(implementation.create!.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app('core/push/firebase_push_service.dart'),
      );
      expect(implementation.create!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      final channel = contributions[3] as SocketContribution;
      expect(channel.socket, AppEntryRole.androidManifestApplicationMeta);
      expect(
        (channel.entryKey, channel.entryValue),
        (
          'com.google.firebase.messaging.default_notification_channel_id',
          const AndroidMetaData.value(NotificationsRole.defaultChannel),
        ),
      );
      final icon = contributions[4] as SocketContribution;
      expect(icon.socket, AppEntryRole.androidManifestApplicationMeta);
      expect(
        (icon.entryKey, icon.entryValue),
        (
          'com.google.firebase.messaging.default_notification_icon',
          const AndroidMetaData.resource(
            '@drawable/${NotificationsRole.androidIcon}',
          ),
        ),
      );
      final readme = contributions[5] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      final note = contributions[6] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, pushRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds one app of the module, with the provider of the '
        'notifications role, which the push role requires', () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested
                .contains(FirebaseMessagingModule.id))
              result.contractCase.name,
        ],
        ['firebase_messaging'],
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

    test('renders the service, which type-checks with firebase_messaging',
        () async {
      final result = results.singleWhere(
        (result) =>
            result.contractCase.requested.contains(FirebaseMessagingModule.id),
      );
      expect(
        [
          for (final file in result.app!.files.values)
            if (file.owner == const ModuleOrigin(FirebaseMessagingModule.id))
              file.path,
        ],
        [serviceFile],
      );
      final app = DartApp.write(result.app!);
      try {
        expect(
          await app.analysisProblems(
            {const ModuleOrigin(FirebaseMessagingModule.id)},
          ),
          isEmpty,
        );
      } finally {
        app.delete();
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [FirebaseMessagingModule.id]);
      app = result.app!;
      without = (await _resultOf(
        const [FirebaseCoreModule.id, LocalNotificationsModule.id],
      ))
          .app!;
    });

    test(
        'is the app of Firebase and the notifications but for the files of '
        'the push role, the service, firebase_messaging, the start of the '
        'push messages, what iOS and Android need for them, and the sections '
        'of the push messages in the README and in the guide for coding '
        'agents', () {
      expect(app.files.keys.toSet(), {
        ...without.files.keys,
        ...pushRole.interface.files,
        serviceFile,
      });
      expect(
        app.files[serviceFile]!.owner,
        const ModuleOrigin(FirebaseMessagingModule.id),
      );
      final changed = <String>[];
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        expect(app.files[path]!.owner, file.owner, reason: path);
        if (app.files[path]!.text != file.text) changed.add(path);
      }
      // The provider of the app entry renders the start-up, which now starts
      // the push messages, into a file of its own, whichever module it is.
      final entries = {
        for (final module in result.resolution!.providersOf(appEntryRole))
          ModuleOrigin(module.id),
      };
      final startUp = [
        for (final path in changed)
          if (entries.contains(app.files[path]!.owner) &&
              app.files[path]!.addedImports.any(
                (added) =>
                    added.contributor == const RoleTemplateOrigin(pushRole),
              ))
            path,
      ];
      expect(startUp, hasLength(1));
      expect(
        changed.toSet().difference(startUp.toSet()),
        {
          'pubspec.yaml',
          AppEntryRole.readmeFile,
          AppEntryRole.agentsFile,
          AppEntryRole.androidManifestFile,
          // The entitlement and the background mode of the push role.
          AppEntryRole.infoPlistFile,
          AppEntryRole.iosEntitlementsFile,
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['dependencies'],
        {
          ...(_yamlOf(without.files['pubspec.yaml']!.text)['dependencies']!
              as Map<String, Object?>),
          'firebase_messaging': '^16.7.0',
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['environment'],
        _yamlOf(without.files['pubspec.yaml']!.text)['environment'],
      );
    });

    test(
        'starts the push messages in bootstrap() once Firebase and the '
        'notifications started, with the service created without waiting', () {
      expect(_startUpOf(result), [
        equals(
          'firebase_core: await Firebase.initializeApp(options: '
          'DefaultFirebaseOptions.currentPlatform);',
        ),
        'role:preferences: await initPreferences();',
        'role:notifications: await initNotifications();',
        'role:push: await initPush();',
      ]);
      final init = _unitOf(app, PushRole.controllerFile)
          .declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == 'initPush');
      final body = init.functionExpression.body as BlockFunctionBody;
      expect(
        [for (final statement in body.block.statements) '$statement'],
        [
          '_pushService = impl0.createFirebasePushService();',
          'await appPush.start(_pushService);',
        ],
      );
    });

    test(
        'names the channel and the small icon of the notifications of the '
        'app in the manifest of Android, as the defaults of Firebase Cloud '
        'Messaging', () {
      final application = XmlDocument.parse(
        app.files[AppEntryRole.androidManifestFile]!.text,
      ).rootElement.getElement('application')!;
      final metaData = {
        for (final element in application.findElements('meta-data'))
          element.getAttribute('android:name'): (
            element.getAttribute('android:value'),
            element.getAttribute('android:resource'),
          ),
      };

      expect(
        metaData[channelMetaData],
        (NotificationsRole.defaultChannel, null),
      );
      expect(
        metaData[iconMetaData],
        (null, '@drawable/${NotificationsRole.androidIcon}'),
      );
      // The icon is the drawable of the notifications role.
      expect(
        app.files.keys,
        contains(
          'android/app/src/main/res/drawable/'
          '${NotificationsRole.androidIcon}.xml',
        ),
      );
      expect(NotificationsRole.androidIconFile, endsWith('.xml'));
      expect(
        NotificationsRole.androidIconFile,
        'android/app/src/main/res/drawable/'
        '${NotificationsRole.androidIcon}.xml',
      );
    });

    test(
        'has the entitlement and the background mode of the push role on '
        'iOS, and no code of its own in the app delegate', () {
      expect(
        app.files[AppEntryRole.iosEntitlementsFile]!.text,
        contains('<key>${PushRole.apsEnvironment}</key>'),
      );
      expect(
        app.files[AppEntryRole.infoPlistFile]!.text,
        contains('<string>${PushRole.remoteNotificationMode}</string>'),
      );
      // firebase_messaging finds the token of the Apple Push Notification
      // service and the notifications through the app delegate itself, and
      // the delegate of the notification center is the one of the
      // notifications.
      expect(
        app.files[AppEntryRole.appDelegateFile]!.text,
        without.files[AppEntryRole.appDelegateFile]!.text,
      );
    });

    test(
        'lists the step by hand in which the developer signs the iOS app with '
        'a paid team, which the entitlement of the push role needs, first in '
        'the README', () {
      final planned = result.manualSteps.single;
      expect(planned.step.id, AppEntryRole.iosAppIdStep.id);
      expect(planned.step.title, AppEntryRole.iosAppIdStep.title);
      // The template of the push role lists it, whichever module provides
      // the role.
      expect(planned.contributors, [const RoleTemplateOrigin(pushRole)]);
      final readme = app.files[AppEntryRole.readmeFile]!.text;
      expect(
        RegExp(r'^## (.+)$', multiLine: true).firstMatch(readme)?[1],
        AppEntryRole.setupHeading,
      );
      expect(readme, contains('\n1. ${AppEntryRole.iosAppIdStep.title}\n'));
      // The app of Firebase and the notifications has no such step.
      expect(without.manualSteps, isEmpty);
    });

    group('the implementation', () {
      late CompilationUnit unit;

      setUpAll(() => unit = _unitOf(app, serviceFile));

      test(
          'is the service of the role on FirebaseMessaging, which '
          'createFirebasePushService() creates', () {
        final declaration = unit.declarations
            .whereType<ClassDeclaration>()
            .singleWhere(
              (declaration) =>
                  declaration.namePart.typeName.lexeme == 'FirebasePushService',
            );
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'PushService',
        );
        final create =
            unit.declarations.whereType<FunctionDeclaration>().singleWhere(
                  (function) =>
                      function.name.lexeme == 'createFirebasePushService',
                );
        expect('${create.returnType}', 'PushService');
        expect(create.functionExpression.parameters!.parameters, isEmpty);
        expect(
          [
            for (final directive
                in unit.directives.whereType<ImportDirective>())
              '$directive',
          ],
          [
            "import 'dart:async';",
            "import 'dart:convert';",
            equals(
              "import 'package:firebase_core/firebase_core.dart' "
              'show FirebaseException;',
            ),
            "import 'package:firebase_messaging/firebase_messaging.dart';",
            "import 'package:flutter/foundation.dart';",
            "import 'push_service.dart';",
          ],
        );
      });

      test(
          'implements every member of the service with the signature of the '
          'interface', () {
        final interface = _membersOf(
          _unitOf(app, PushRole.serviceFile),
          'PushService',
        );

        expect(interface, hasLength(6));
        expect(_membersOf(unit, 'FirebasePushService'), interface);
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

      test(
          'is created on Android without a call of the platform, and the app '
          'shows a message in the foreground there', () {
        expect(sent['implementation'], 'FirebasePushService');
        expect(sent['create on Android'], isEmpty);
        expect(sent['shows on Android'], isFalse);
      });

      test(
          'sets the presentation options of iOS to an alert, a badge and a '
          'sound when it is created, and the platform shows a message in the '
          'foreground there', () {
        expect(sent['create on iOS'], [
          equals(
            'setForegroundNotificationPresentationOptions(alert true, badge '
            'true, sound true)',
          ),
        ]);
        expect(sent['shows on iOS'], isTrue);
      });

      test('never asks for the permission to show notifications', () {
        expect(sent['every call'], isNotEmpty);
        expect(
          [
            for (final call in sent['every call']! as List<Object?>)
              if ('$call'.startsWith('requestPermission')) call,
          ],
          isEmpty,
        );
      });

      test(
          'gives the registration token as the address, and none where '
          'Firebase has none or fails, which it prints in debug mode', () {
        expect(sent['address'], ['getToken()', '= token of the device']);
        expect(sent['address without Google Play services'], ['getToken()']);
        expect(sent['printed without Google Play services'], [
          equals(
            'Firebase Cloud Messaging has no address yet: '
            '[firebase_messaging/unknown] java.io.IOException: '
            'SERVICE_NOT_AVAILABLE',
          ),
        ]);
        expect(sent['address while Firebase has none'], ['getToken()']);
        // The platform gave the device a new token before.
        expect(sent['address on iOS'], [
          'getAPNSToken()',
          'getToken()',
          '= a new token',
        ]);
        expect(
          sent['address on iOS without an APNs token'],
          ['getAPNSToken()'],
        );
        expect(sent['printed on iOS without an APNs token'], [
          equals(
            'Firebase Cloud Messaging has no address yet: '
            '[firebase_messaging/apns-token-not-set] APNS token has not '
            'been received on the device yet.',
          ),
        ]);
      });

      test(
          'on iOS tells of the first registration token once iOS has the '
          'token of the Apple Push Notification service, which the plugin '
          'tells of no token for, and asks iOS for it only while something '
          'listens to the address changes', () {
        expect(sent['address before the APNs token'], ['getAPNSToken()']);
        expect(
          sent['calls until the APNs token came'],
          [
            // The look half a second later finds the token, and the plugin
            // reads it again before it asks for the registration token.
            'getAPNSToken()',
            'getAPNSToken()',
            'getToken()',
          ],
        );
        expect(
          sent['addresses once the APNs token came'],
          ['a new token'],
        );
        expect(sent['calls once nothing listens'], isEmpty);
        expect(sent['calls without a listener'], isEmpty);
      });

      test(
          'gives the message whose tap launched the app, with the title and '
          'the body of its notification and its data as texts, and none '
          'where Firebase has none or fails', () {
        expect(sent['no launch message'], ['getInitialMessage()', '= none']);
        expect(sent['launch message'], [
          'getInitialMessage()',
          '= launch-1 | Hello | World | {screen: inbox, count: 3}',
        ]);
        expect(sent['launch message that fails'], [
          'getInitialMessage()',
          '= none',
        ]);
        expect(sent['printed without a launch message'], [
          equals(
            'Firebase Cloud Messaging has no launch message: Bad state: The '
            'platform broke.',
          ),
        ]);
        expect(sent['launch message on iOS'], [
          'getInitialMessage()',
          '= launch-1 | Hello | World | {screen: inbox, count: 3}',
        ]);
      });

      test(
          'tells of the messages, the taps and the new tokens of the '
          'platform on broadcast streams, with a value of the data that is no '
          'text as its JSON', () {
        expect(sent['broadcast'], [true, true, true]);
        expect(sent['messages'], [
          equals(
            'message-1 | Title | Body | {text: a text, number: 1, flag: true, '
            'nested: {"list":[1,"two"]}, none: null}',
          ),
          'null | null | null | {only: data}',
        ]);
        expect(sent['taps'], [
          'message-2 | Tapped | null | {screen: inbox}',
        ]);
        expect(sent['addresses'], ['a new token']);
      });
    });

    group('the section of the module in the README of the app', () {
      test('refers to the section of the push role', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(readme, contains('\n## ${PushRole.readmeHeading}\n'));
        expect(
          readmeSection,
          contains('(see the section ${PushRole.readmeHeading})'),
        );
      });

      test(
          'tells how to upload the key of the Apple Push Notification '
          'service, and that the App ID is in the team of the key', () {
        expect(
          readmeSection,
          allOf(
            contains('Certificates, Identifiers & Profiles'),
            contains('Apple Push Notifications service (APNs)'),
            contains('`.p8`'),
            contains('Key ID'),
            contains('Team ID'),
            contains('Cloud Messaging'),
            contains('App ID in that team'),
          ),
        );
      });

      test(
          'tells how to send a test message, from the Firebase console and '
          'with the HTTP v1 API', () {
        expect(
          readmeSection,
          allOf(
            contains('Send test message'),
            contains('copy the address that it prints'),
          ),
        );
        expect(
          _codeOf(readmeSection),
          containsAll([
            'POST https://fcm.googleapis.com/v1/projects/<project-id>/messages:send',
            'token',
          ]),
        );
      });

      test(
          'names the meta-data of the channel and of the icon, the '
          'presentation options, and the handler of a message in the '
          'background', () {
        expect(
          _codeOf(readmeSection),
          containsAll([
            serviceFile,
            AppEntryRole.androidManifestFile,
            NotificationsRole.defaultChannel,
            channelMetaData,
            iconResource,
            iconMetaData,
            'setForegroundNotificationPresentationOptions()',
            'FirebaseMessaging.onBackgroundMessage()',
            'main()',
            'bootstrap()',
          ]),
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the push messages of the guide, after what '
          'the role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          {
            for (final (origin, heading, note) in notes)
              if (_push.contains(origin)) (origin, heading, note.isOfRole),
          },
          {
            (
              const ModuleOrigin(FirebaseMessagingModule.id),
              pushRole.description,
              false,
            ),
            (const RoleTemplateOrigin(pushRole), pushRole.description, true),
          },
        );
        expect(agentNote, startsWith('With `firebase_messaging`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(guide.indexOf('\n## ${pushRole.description}\n')),
        );
      });

      test(
          'names the file of the module, the only one of the app that '
          'imports the package, and what that file declares and calls', () {
        final service = DartFileIndexer.index(
          serviceFile,
          app.files[serviceFile]!.text,
        );

        expect(
          _codeOf(agentNote),
          containsAll([
            serviceFile,
            'FirebasePushService',
            'PushService',
            'FirebaseMessaging',
            'appPush',
            'getToken()',
            'onTokenRefresh',
            'getAPNSToken()',
            'addressChanges',
            'createFirebasePushService()',
            'setForegroundNotificationPresentationOptions()',
            'requestPermission()',
            'appNotifications',
            'appNotifications.request()',
            AppEntryRole.androidManifestFile,
            'bootstrap()',
            'plugins.flutter.io/firebase_messaging',
            'setMockMethodCallHandler',
          ]),
        );
        expect(
          [
            for (final file in app.files.values)
              if (file.path.endsWith('.dart') &&
                  file.text.contains('package:firebase_messaging/'))
                file.path,
          ],
          [serviceFile],
        );
        for (final name in [
          'FirebasePushService',
          'createFirebasePushService',
        ]) {
          expect(service.declaration(name), isNotNull, reason: name);
        }
        for (final call in [
          'getToken(',
          'onTokenRefresh',
          'getAPNSToken(',
          'addressChanges',
          'setForegroundNotificationPresentationOptions(',
        ]) {
          expect(app.files[serviceFile]!.text, contains(call), reason: call);
        }
        expect(
          app.files[serviceFile]!.text,
          isNot(contains('requestPermission')),
        );
      });
    });

    test('has a README that leads to the page of the module', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains('(https://doc.saymyframe.com/modules/firebase-messaging)'),
      );
    });
  });
}
