# smf_posthog

The SMF module of [PostHog](https://posthog.com) with [posthog_flutter](https://pub.dev/packages/posthog_flutter). It provides the analytics role of SMF: the app records in PostHog what its users do through its `AnalyticsService` and, when the app has a router, a `$screen` event for each screen the user sees. It does so without a `PosthogObserver`, which would record each screen a second time.

The project token and the host of the PostHog project go into `.env` of the app, through the env role, which the module requires: `POSTHOG_PROJECT_TOKEN` and `POSTHOG_HOST`, which stays empty for US Cloud. While the token is empty, the app starts without PostHog and a debug build prints why. Every event has the flavor of the build in its property `app_flavor`, and debug builds record their events too.

PostHog makes a person profile only for a user that the app identifies, and records no session replay, no survey and nothing about push messages. It keeps what the app chose with `setAnalyticsCollectionEnabled` on the device, across starts, and it starts from Dart. So an app generated with `--analytics-collection=off` collects nothing until its code turns collection on, for example once the user has agreed. The README of the app tells what reaches PostHog, what to put in the privacy policy of the app, and how to pin the versions of the SDKs of PostHog for Android and iOS.

An app can have several modules that provide analytics, and the service of the app forwards each call to all of them.

## Use with the SMF CLI

`smf create` asks which modules provide the analytics of the app, and the answer may be none. With one, it then asks whether the app collects analytics before the user agrees. To choose this module without the questions, and an app that collects nothing until its code turns collection on:

```bash
smf create my_app -m posthog --analytics-collection=off
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The posthog module](https://doc.saymyframe.com/modules/posthog)
