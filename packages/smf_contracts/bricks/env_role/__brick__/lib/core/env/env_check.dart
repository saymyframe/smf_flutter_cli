// The check that a build of the app has the values of .env, which bootstrap()
// calls in its first phase. It is plain Dart, so that a test compiles it with
// the Dart SDK alone.
import 'app_env.dart';

/// Whether this is a release build, which the compiler of a release build
/// declares.
const _release = bool.fromEnvironment('dart.vm.product');

/// Whether the command that built the app gave it the values of `.env`, as
/// [AppEnv.supplied] says. A release build without them cannot evaluate
/// this constant, so it stops here, and the compiler quotes the text.
const bool _supplied = AppEnv.supplied || !_release
    ? AppEnv.supplied
    : ({{{env_release_error}}}
          as bool);

/// Tells a debug or profile build that has none of the values of `.env`,
/// through [report], that every getter of [AppEnv] is `null`, and how to
/// give the values; `bootstrap()` calls it in its first phase, with
/// `debugPrint`.
void checkEnvValues(void Function(String message) report) {
  if (_supplied) return;
  report(
    {{{env_no_values_message}}},
  );
}
