/// The note of the module in the guide for coding agents of an app with a
/// router, in the section of the analytics: the function of its file that
/// logs the screen views.
const screenViewsAgentNote = '''
With `firebase_analytics`:

- Screen views need no code: the router calls `logFirebaseScreenView()` with each screen that the user sees, and it logs the screen under the name of its route.
''';
