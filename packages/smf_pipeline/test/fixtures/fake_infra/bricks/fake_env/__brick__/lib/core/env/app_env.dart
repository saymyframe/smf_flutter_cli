/// The values of `.env` (fixture): a command of the `flutter` tool that
/// builds, runs or tests the app reads `.env` when it starts, given
/// `--dart-define-from-file .env`, and the class keeps what it read in a
/// constant map, behind a static getter for each key, which returns the
/// value, or `null` while it is empty or missing.
abstract final class AppEnv {
{{{fixture_env_members}}}
}
