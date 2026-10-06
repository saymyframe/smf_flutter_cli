/// The note of the module in the guide for coding agents of the app, in the
/// section of the events: what a listener gets with the event_bus package,
/// which the events role leaves to its provider, and when.
const agentNote = '''
With `event_bus`:

- A listener gets an event once the code that fired it reaches its next `await` or returns, not inside `fire()`.
''';
