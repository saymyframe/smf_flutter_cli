#!/usr/bin/env bash
# Runs the start test of the app in the current directory, the test of
# smf_flutter_core in integration_test/, on the emulator or simulator $1,
# giving each try $2 seconds, the build of the app included.
#
# On the emulators and simulators of CI, flutter test sometimes never
# reaches the app it installed: it waits for its VM service until the step
# times out, or fails to start the Dart Development Service. Such a try is
# made once more. A test that fails, as when the app does not start, fails
# at once, since a second try would fail the same way.
set -u

device="$1"
seconds="$2"

for try in 1 2; do
  log="$(mktemp)"
  # perl rather than timeout, which the macOS runners lack; a try that runs
  # out of time ends with 142, killed by SIGALRM.
  perl -e 'alarm shift; exec @ARGV' "$seconds" \
    flutter test integration_test -d "$device" 2>&1 | tee "$log"
  code=${PIPESTATUS[0]}
  if [ "$code" -eq 0 ]; then
    exit 0
  fi
  if [ "$code" -ne 142 ] && ! grep -q 'Failed to start Dart Development Service' "$log"; then
    exit "$code"
  fi
  echo "::warning::flutter test did not reach the app on $device in try $try of 2."
  # On Android, the end of the log of the device shows whether the app
  # crashed or never started.
  if [[ "$device" == emulator-* ]]; then
    "$ANDROID_HOME/platform-tools/adb" -s "$device" logcat -d | tail -n 80
  fi
done
exit 1
