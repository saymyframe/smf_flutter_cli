import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_posthog/src/posthog_module.dart';
import 'package:smf_posthog/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the analytics: where PostHog starts, the property of the
/// flavor, when to start a new anonymous user, and what the code of the app
/// must not call of PostHog.
final String agentNote = '''
With `posthog_flutter`:

- `initPostHogAnalytics()` in `$serviceFile` starts PostHog with `${PostHogModule.projectTokenKey.name}` and `${PostHogModule.hostKey.name}` of `${EnvRole.dotEnvFile}`, and `${AppEntryRole.bootstrap.name}()` awaits it. Without a token, the app starts without PostHog.
- Every event has `${PostHogModule.flavorProperty}`, the flavor of the build.
- `setUserId(null)` starts a new anonymous user in PostHog: call it when the user signs out, not at each start.
- Record through `AnalyticsService`, and never call `Posthog().optIn()`, `Posthog().optOut()` or `Posthog().reset()`: `reset()` erases the setting of collection that PostHog keeps on the device, which the service keeps.
''';

/// The note of the module in an app with a router, after [agentNote]: the
/// function of its file that records the screens, and why the app has no
/// observer of PostHog.
const String screensAgentNote = '''
- Screens need no code: the router calls `logPostHogScreen()` with each screen that the user sees, and it records the screen under the name of its route. Add no `PosthogObserver` with its defaults, which would record each screen a second time.
''';
