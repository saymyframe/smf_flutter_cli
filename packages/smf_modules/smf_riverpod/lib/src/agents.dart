import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the state management: where the state of a screen lives with
/// Riverpod, what a widget may reach, and the scope of the providers.
const agentNote = '''
With `flutter_riverpod`:

- The state of a screen is a provider in the directory of its feature, such as a `NotifierProvider` with its `Notifier`. Write it by hand: the app has no code generation for providers.
- A widget talks only to providers, never to a service. A provider gets a service through another provider.
- `ProviderScope` is around the root widget in `runApp()`, in `${AppEntryRole.mainFile}`: keep it above every widget that reads a provider.
''';
