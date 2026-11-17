import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_posthog/bundles/posthog_bundle.dart';
import 'package:smf_posthog/src/agents.dart';
import 'package:smf_posthog/src/readme.dart';

/// The module that records what users do in the app with
/// [PostHog](https://posthog.com) and the posthog_flutter package, and so
/// provides the analytics role.
///
/// The template of the role generates the `AnalyticsService` interface and
/// `createAnalyticsService()`, which returns the one analytics service of
/// the app that forwards every call to the services of all its providers.
/// This module adds `posthog_flutter` to the dependencies of the app and
/// implements the service in [serviceFile] on `Posthog`. PostHog starts
/// asynchronously, so the role awaits `initPostHogAnalytics()` in
/// `bootstrap()`, and leaves PostHog out when the start fails.
///
/// The module requires the env role for its two keys, which the developer of
/// the app fills in in `.env`: [projectTokenKey], the project token of the
/// PostHog project, and [hostKey], its host, empty for US Cloud. Without a
/// token, or with a host that is no http or https address, the start throws,
/// and the role leaves PostHog out, with the reason in a debug build. Every
/// event has the flavor of the build in its property [flavorProperty].
///
/// PostHog starts from Dart, as `analyticsCollectedFromFirstStart` of the
/// role says, and keeps on the device what the code chose with
/// `setAnalyticsCollectionEnabled()`, as the analytics role asks of every
/// provider. Its SDKs for Android and iOS would start on their own before
/// any Dart code runs, so the manifest of Android and `Info.plist` turn that
/// off with [autoInitKey]. `Info.plist` also turns off with
/// [pushOpenedKey] the hook with which the plugin records the push messages
/// that the user opens, and the start turns off the rest of what PostHog
/// does with push messages, which belong to the push role. It makes a
/// person profile only for a user with an id, and has no session replay, no
/// survey and no request for feature flags at the start.
///
/// `reset()` of PostHog, with which `setUserId(null)` starts a new anonymous
/// user, forgets the setting of collection that PostHog kept on the device.
/// So the service never resets while collection is off, and gives PostHog
/// the user that the code set or cleared then once collection is on again.
/// After a reset, in an app that collects nothing before its code chose, it
/// has PostHog keep that collection is on again.
///
/// When the app has a router, the module gives it `logPostHogScreen` of its
/// file, a listener of the screen the user sees, which records a screen each
/// time the router tells it that the screen changed, as the listener of
/// Firebase Analytics does, once PostHog started. It adds no
/// `PosthogObserver`, which would record the screens a second time.
///
/// The module adds the section [readmeHeading] to the README of the app, a
/// note to the section of the analytics in the guide for coding agents, one
/// more in an app with a router, and its step by hand, [projectTokenStep].
final class PostHogModule extends SmfModule {
  /// Creates the module.
  const PostHogModule();

  /// The id of the module.
  static const id = ModuleId('posthog');

  /// The key of the project token of the PostHog project in `.env`.
  static const projectTokenKey = EnvKey(
    'POSTHOG_PROJECT_TOKEN',
    description: 'The project token of your PostHog project, which starts '
        'with phc_',
  );

  /// The key of the host of the PostHog project in `.env`.
  static const hostKey = EnvKey(
    'POSTHOG_HOST',
    description: 'The host of your PostHog project: empty for US Cloud, '
        'https://eu.i.posthog.com for EU',
  );

  /// The step by hand in which the developer creates a PostHog project and
  /// copies its project token and its host into `.env`.
  static const projectTokenStep = ManualStep(
    ManualStepId(id, 'project_token'),
    'Create a PostHog project and copy its token and host into .env',
  );

  /// The property of every event that names the flavor of the build, such
  /// as `dev` or `prod`.
  static const flavorProperty = 'app_flavor';

  /// The meta-data of the application in the manifest of Android, and the
  /// key of `Info.plist`, whose value false keeps the SDK of PostHog from
  /// starting on its own before any Dart code runs.
  static const autoInitKey = 'com.posthog.posthog.AUTO_INIT';

  /// The key of `Info.plist` whose value false keeps the plugin of PostHog
  /// from recording the push messages that the user opens on iOS, with a hook
  /// that it installs before any Dart code runs.
  static const pushOpenedKey =
      'com.posthog.posthog.CAPTURE_PUSH_NOTIFICATION_OPENED';

  static const _file = ImportRef.app('core/analytics/$serviceFileName');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'PostHog with posthog_flutter',
        kind: ModuleKinds.infrastructure,
        requires: {envRole},
        providers: [RoleProvider.plain(analyticsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          posthogBundle,
          vars: {
            ...envRole.varsOf(id, const [projectTokenKey, hostKey]),
            'default_flavor': AppEntryRole.defaultFlavor.name,
            'values_heading': EnvRole.readmeHeading,
            'readme_heading': readmeHeading,
          },
        ),
        // The service of the brick sets PostHog up as its README section
        // tells: check the defaults of the config when moving to a newer
        // version.
        const PubspecContribution.hosted('posthog_flutter', '^5.61.0'),
        analyticsRole.data(
          const RoleImplementation.async(
            type: TypeRef('PostHogAnalyticsService', import: _file),
            init: FactoryRef('initPostHogAnalytics', import: _file),
          ),
        ),
        envRole.data(projectTokenKey),
        envRole.data(hostKey),
        projectTokenStep,
        // The router tells the listener, a function of the file of the
        // module, which the file has only in an app with a router, about
        // each screen the user sees.
        const SocketContribution.item(
          RouterRole.screenListeners,
          Fragment(
            'logPostHogScreen',
            imports: [
              ImportRef.app(
                'core/analytics/$serviceFileName',
                show: ['logPostHogScreen'],
              ),
            ],
          ),
          when: {routerRole},
        ),
        // PostHog starts from Dart, with the setting of collection of the
        // app, and not on its own before.
        AppEntryRole.androidManifestApplicationMeta.entry(
          autoInitKey,
          const AndroidMetaData.value('false'),
        ),
        AppEntryRole.infoPlist.entry(autoInitKey, const PlistBoolean(false)),
        AppEntryRole.infoPlist.entry(
          pushOpenedKey,
          const PlistBoolean(false),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          analyticsRole.description,
          AgentNote(agentNote),
        ),
        // Of the listener, which only an app with a router has.
        AppEntryRole.agentSections.entry(
          analyticsRole.description,
          AgentNote(screensAgentNote),
          when: {routerRole},
        ),
      ];
}
