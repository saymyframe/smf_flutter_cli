/// The note of the module in the guide for coding agents of the app, in the
/// section of the state management: where the state of a screen lives with
/// BLoC, and what a widget may reach.
const agentNote = '''
With `flutter_bloc`:

- The state of a screen is a `Cubit` or a `Bloc` in the directory of its feature. The screen provides it with a `BlocProvider` around its content.
- A widget talks only to its `Cubit` or `Bloc`, never to a service. A `Cubit` takes what it needs through its constructor.
''';
