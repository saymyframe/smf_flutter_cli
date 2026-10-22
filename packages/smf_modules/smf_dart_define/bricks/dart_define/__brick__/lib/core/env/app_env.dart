/// The values of `.env`, each through a static getter that returns the
/// value, or `null` while it is empty or missing.
///
/// A command of the `flutter` tool that builds, runs or tests the app reads
/// `.env` when it starts, given `--dart-define-from-file=.env`, and compiles
/// each value into the app, where `String.fromEnvironment` reads it as a
/// constant. Without that argument every value is empty, and so every
/// getter is `null`.
abstract final class AppEnv {
{{{app_env_getters}}}
}
