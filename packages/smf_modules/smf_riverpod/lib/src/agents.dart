import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the state management: how a screen with state is written
/// with Riverpod, which provider holds the state that several screens
/// read, what a notifier minds around a call that it awaits, what a widget
/// may reach, and the scope of the providers.
///
/// Of the app of the module alone, only the file with the scope has code
/// with `flutter_riverpod`: a module with screens writes the rest of such
/// code in its variant for this one. The note names nothing of such a
/// module, which this one knows nothing of.
const agentNote = '''
With `flutter_riverpod`:

- The state of a screen is a provider in the directory of its feature: a `NotifierProvider.autoDispose` with its `Notifier`, so the state lasts as long as the screen. Write it by hand: the app has no code generation for providers.
- The screen is a `ConsumerWidget`. It reads the state with `ref.watch` and passes it on to its view as plain values, and the methods of the `Notifier` as callbacks. The view is a widget in a file of its own that imports no `flutter_riverpod`, so the look of a screen does not depend on what manages its state.
- State that several screens read is a provider without `autoDispose`, such as a `NotifierProvider`. It lasts as long as the `ProviderScope`.
- After an `await`, a `Notifier` checks `ref.mounted` before it sets `state`. The user may have left the screen while the call was on its way, and a provider that is disposed of throws when its `Notifier` reads from `ref` or sets `state`. So the `Notifier` reads what the call needs from `ref` before the `await`.
- A widget talks only to providers, never to a service or a DI container. A provider gets a service through another provider, which a test overrides.
- `ProviderScope` is around the root widget in `runApp()`, in `${AppEntryRole.mainFile}`: keep it above every widget that reads a provider.
''';

/// The note of the module in the guide for coding agents of an app whose
/// controllers keep values that the state manager follows: where the
/// providers of those values are, what each is, how a widget reads one, and
/// that code changes a value only through its controller.
///
/// Its inline code names the file, which every app with the note has, and
/// what the file of the providers and the code of a variant for this module
/// use. It names no provider of a value: a file only declares those, and no
/// code with the package uses them.
const bridgesAgentNote = '''
- The values that controllers of the app keep have providers in `lib/core/state/shared_state_providers.dart`, one for each value and named after it, each a `NotifierProvider` of a `ListenableNotifier`. A widget reads one with `ref.watch`, and code changes the value only through its controller, which the doc of the provider names.
''';
