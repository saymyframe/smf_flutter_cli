/// The configuration of the tool in the app.
const configFile = 'flutter_native_splash.yaml';

/// The command that makes the screen, for the README of the app and the
/// guide for coding agents.
const splashCommand = 'dart run $_toolTarget';

/// The arguments of `dart` that make the screen.
const List<String> splashArguments = ['run', _toolTarget];

const _toolTarget = 'flutter_native_splash:create';
