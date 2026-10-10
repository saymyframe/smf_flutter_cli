import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the state management: how a screen with state is written
/// with BLoC, where the state that several screens read is provided, what
/// a cubit minds after a call that it awaited, and what a widget may
/// reach.
///
/// The app of the module alone has no code with `flutter_bloc`: a module
/// with screens writes such code in its variant for this one. The note
/// names nothing of such a module, which this one knows nothing of.
const agentNote = '''
With `flutter_bloc`:

- The state of a screen is a `Cubit` in the directory of its feature. The screen provides it with a `BlocProvider` around its content. In a `BlocBuilder` there, it passes the state on to its view as plain values, and the methods of the `Cubit` as callbacks.
- The view is a widget in a file of its own that imports no `flutter_bloc`, so the look of a screen does not depend on what manages its state.
- When a screen is gone, its `BlocProvider` closes the `Cubit` that it created. For state that several screens read, put a `BlocProvider` around the root widget in `runApp()`, in `${AppEntryRole.mainFile}`. A widget reads that `Cubit` with `context.watch`.
- After an `await`, a `Cubit` checks `isClosed` before it calls `emit()`. The user may have left the screen while the call was on its way, and `emit()` throws in a `Cubit` that is closed.
- A widget talks only to a `Cubit`, never to a service or a DI container. A `Cubit` takes what it needs through its constructor.
''';
