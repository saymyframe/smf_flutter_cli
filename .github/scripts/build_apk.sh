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
# Error on ZipFile unknown archive"), and the build fails. It also leaves
# the directory of the package in the SDK without the package, and the next
# build takes that directory for the package and fails at once ("NDK at
# ... did not have a source.properties file"). So before it builds again,
# the script removes the directory of each package that the build failed to
# install. Any other failure ends the script at once, with the exit code of
# the build.
#
# The workflows run the script for each app, and start_app.sh sources it
# for build_apk.

# Removes the directory of each package of the Android SDK that the build
# whose output is in the file $1 failed to install, as the Gradle plugin of
# Android lists them by their ids, such as ndk;28.2.13676358. The SDK is
# the one of android/local.properties, which flutter writes for Gradle.
remove_failed_packages() {
  local sdk package dir
  [ -f android/local.properties ] || return 0
  sdk="$(sed -n 's/^sdk\.dir=//p' android/local.properties)"
  [ -n "$sdk" ] || return 0
  for package in $(awk '
      /Failed to install the following SDK components:/ { list = 1; next }
      /Install the missing components/ { list = 0 }
      list && NF { print $1 }' "$1"); do
    case "$package" in
      *..* | /*) continue ;;
    esac
    dir="$sdk/${package//;//}"
    if [ -e "$dir" ]; then
      echo "Removing $dir, which the SDK manager left without the package $package."
      rm -rf "$dir"
    fi
  done
}

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
    remove_failed_packages "$dir/log"
    sleep 15
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  build_apk "$@"
fi
