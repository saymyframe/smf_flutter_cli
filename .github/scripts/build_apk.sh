#!/usr/bin/env bash
# Builds the app in the current directory with `flutter build apk` and the
# arguments, and builds it again when the build failed because a package
# of the Android SDK did not download, three times in all.
#
# The Gradle plugin of Android installs the packages that an app needs and
# the SDK of the runner lacks, such as the NDK of Flutter, in each build of
# CI. It downloads them with the SDK manager, which has no retries of its
# own: a download that breaks off leaves an archive that it cannot open
# ("An error occurred while preparing SDK package NDK (Side by side) ...:
# Error on ZipFile unknown archive"), and the build fails. Any other
# failure ends the script at once, with the exit code of the build.
#
# The workflows run the script for each app, and start_app.sh sources it
# for build_apk.

# Runs `flutter build apk` with the arguments, as said above, in the shell
# that calls it. The output of the build goes on to stdout as it comes,
# and through a pipe to a file that the function reads once the build is
# over.
build_apk() {
  local dir attempt code tee_pid
  dir="$(mktemp -d)"
  for attempt in 1 2 3; do
    mkfifo "$dir/output"
    tee "$dir/log" < "$dir/output" &
    tee_pid=$!
    code=0
    flutter build apk "$@" > "$dir/output" 2>&1 || code=$?
    wait "$tee_pid" || true
    rm -f "$dir/output"
    if [ "$code" -eq 0 ] || [ "$attempt" = 3 ] ||
      ! grep -q 'An error occurred while preparing SDK package' "$dir/log"; then
      rm -rf "$dir"
      return "$code"
    fi
    echo "::warning::A package of the Android SDK did not download in flutter build apk, attempt $attempt of 3; trying again."
    sleep 15
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  build_apk "$@"
fi
