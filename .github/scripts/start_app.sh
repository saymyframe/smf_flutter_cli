#!/usr/bin/env bash
# Checks that the app in the current directory starts: on the Android
# emulator or device $2 with $1 android, or on the booted iOS simulator
# with the UDID $2 with $1 ios, in at most $3 seconds once the app is
# built. The build has no limit here: on a busy runner, the build of the
# Firebase SDK for iOS takes minutes longer than on another, which would
# leave the start no time. The step of CI that runs the script limits it.
#
# The app has the start check that the CLI keeps in app_tests/start,
# integration_test/start_check.dart, which its matrix tool adds with
# --add-app-tests. The script builds a debug app with the check as its
# entry, installs it anew and launches it with adb or simctl, and waits for
# the line that the check writes to the file smf_start_check in the
# temporary directory of the app: `passed`, or `failed: ` and the problems.
# Nothing connects to the app, unlike flutter test, which must reach the VM
# service of the app and sometimes never does on the emulators and
# simulators of CI (on an iOS simulator, a race of flutter_tools:
# https://github.com/flutter/flutter/issues/181771). So a run that fails
# is not tried again. The script fails when the check fails, when the app
# stops before the check writes its result, as when it crashes at start-up,
# and when the result does not come in time, and then prints the log of
# the app.
set -euo pipefail

if [ $# -ne 3 ] || [[ ! "$1" =~ ^(android|ios)$ ]] || [[ ! "$3" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <android|ios> <device> <seconds>" >&2
  exit 64
fi
platform="$1"
device="$2"
seconds="$3"
deadline=
check=integration_test/start_check.dart
result=smf_start_check

if [ ! -f "$check" ]; then
  echo "::error::$PWD has no $check: add it with the --add-app-tests of packages/smf_flutter_cli/tool/matrix.dart."
  exit 1
fi

# Runs the command after $1 for at most $1 seconds, with perl rather than
# timeout, which the macOS runners lack; a command that runs out of time
# ends with 142, killed by SIGALRM.
within() {
  local limit="$1"
  shift
  perl -e 'alarm shift; exec @ARGV' "$limit" "$@"
}

# Builds the app with the command after $1, which names it, and fails when
# it fails. Once the app is built, the start has the seconds it is given.
build() {
  local name="$1" code=0
  shift
  "$@" || code=$?
  if [ "$code" -ne 0 ]; then
    echo "::error::$name failed with the exit code $code."
    exit 1
  fi
  deadline=$((SECONDS + seconds))
}

# Runs the command after $1, which names it, in the time that is left of
# the start, and fails when it fails.
step() {
  local name="$1" left=$((deadline - SECONDS)) code=0
  shift
  if [ "$left" -gt 0 ]; then
    within "$left" "$@" || code=$?
  else
    code=142
  fi
  if [ "$code" -eq 142 ]; then
    echo "::error::$name did not finish in the $seconds s of the start of the app."
    exit 1
  elif [ "$code" -ne 0 ]; then
    echo "::error::$name failed with the exit code $code."
    exit 1
  fi
}

# Waits for the result of the check, which the command in the arguments
# prints once the app wrote it, as long as `alive` finds the app running.
# Fails when the result is not `passed`, when the app stops before it, and
# when it does not come in the time that is left, and then prints the log
# of the app with `show_log`.
wait_for_result() {
  local launched=$SECONDS line
  while :; do
    if line="$(within 30 "$@" 2> /dev/null)" && [ -n "$line" ]; then
      break
    fi
    if ! alive; then
      # The result may have come just before the app stopped.
      if line="$(within 30 "$@" 2> /dev/null)" && [ -n "$line" ]; then
        break
      fi
      show_log
      echo "::error::The app stopped $((SECONDS - launched)) s after it was launched, before its start check wrote a result."
      exit 1
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      show_log
      echo "::error::The start check of the app wrote no result in the $seconds s of the start of the app, $((SECONDS - launched)) s of them after the app was launched."
      exit 1
    fi
    sleep 1
  done
  line="$(tr -d '\r' <<< "$line")"
  if [ "$line" != passed ]; then
    show_log
    echo "::error::The start check of the app $line"
    exit 1
  fi
  echo "The start check of the app passed $((SECONDS - launched)) s after the app was launched, $SECONDS s after the script started."
}

android() {
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [ -z "$sdk" ]; then
    if [ "$(uname)" = Darwin ]; then
      sdk="$HOME/Library/Android/sdk"
    else
      sdk="$HOME/Android/Sdk"
    fi
  fi
  adb=("$sdk/platform-tools/adb" -s "$device")
  build 'flutter build apk' flutter build apk --debug -t "$check"
  # The application id and the activity that starts the app, from the APK,
  # with aapt2 of the newest build tools of the Android SDK.
  local apk=build/app/outputs/flutter-apk/app-debug.apk build_tools badging activity
  build_tools="$(ls "$sdk/build-tools" | sort -t . -k1,1n -k2,2n -k3,3n | tail -n 1)"
  badging="$("$sdk/build-tools/$build_tools/aapt2" dump badging "$apk")"
  id="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<< "$badging")"
  activity="$(sed -n "s/^launchable-activity: name='\([^']*\)'.*/\1/p" <<< "$badging")"
  if [ -z "$id" ] || [ -z "$activity" ]; then
    echo "$badging"
    echo "::error::aapt2 finds no application id or activity to start in $apk."
    exit 1
  fi
  echo "Starting $id/$activity on $device."
  step 'adb install' "${adb[@]}" install -r "$apk"
  trap 'within 30 "${adb[@]}" shell am force-stop "$id" || true' EXIT
  # pm clear stops the app and deletes its data, with the result of an
  # earlier run.
  step 'adb shell pm clear' "${adb[@]}" shell pm clear "$id"
  within 30 "${adb[@]}" logcat -c || true
  step 'adb shell am start' "${adb[@]}" shell am start -W -n "$id/$activity"
  # The files of a debug app can be read with run-as, which starts in the
  # directory of its data. The temporary directory of Dart is code_cache/
  # there: Flutter gives the engine the code cache of the app as its cache
  # directory (--cache-dir-path), which the Dart VM takes as systemTemp.
  wait_for_result "${adb[@]}" shell run-as "$id" cat "code_cache/$result"
  android_printed
}

# What the app printed: the lines of Flutter in the log of the device.
android_printed() {
  within 60 "${adb[@]}" logcat -d -s flutter || true
}

android_alive() {
  [ -n "$(within 30 "${adb[@]}" shell pidof "$id" 2> /dev/null | tr -d '\r')" ]
}

# What the app printed, and the end of the log of the device, with the
# crash of the app if it crashed.
android_log() {
  echo "What the app printed:"
  android_printed
  echo "The end of the log of the device:"
  within 60 "${adb[@]}" logcat -d | tail -n 150 || true
}

ios() {
  # For the architecture of the Mac only, which the simulator runs, as
  # flutter run and flutter test build an app for a simulator: Flutter
  # passes FLUTTER_XCODE_ARCHS to Xcode as ARCHS. (With Xcode 27, Flutter
  # 3.44 fails to build for both: the lipo of Xcode 27 takes only one
  # architecture after -verify_arch.)
  build 'flutter build ios' env FLUTTER_XCODE_ARCHS="$(uname -m)" \
    flutter build ios --simulator --debug -t "$check"
  local app=build/ios/iphonesimulator/Runner.app data launched
  id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
  executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist")"
  echo "Starting $id on $device."
  # A new install, without the data of an earlier run and its result.
  within 60 xcrun simctl terminate "$device" "$id" 2> /dev/null || true
  within 60 xcrun simctl uninstall "$device" "$id" 2> /dev/null || true
  step 'xcrun simctl install' xcrun simctl install "$device" "$app"
  trap 'within 60 xcrun simctl terminate "$device" "$id" 2> /dev/null || true' EXIT
  # The container of the data of the app, whose tmp/ is the temporary
  # directory of the app.
  data="$(within 60 xcrun simctl get_app_container "$device" "$id" data)"
  since="$(date '+%Y-%m-%d %H:%M:%S')"
  launched="$(within 60 xcrun simctl launch "$device" "$id")" || {
    echo "::error::xcrun simctl launch failed: $launched"
    exit 1
  }
  # The app runs as a process of the Mac: simctl prints `<id>: <pid>`.
  pid="${launched##*: }"
  wait_for_result cat "$data/tmp/$result"
  ios_printed
}

# What the app printed: the lines of Flutter in the log of the simulator.
ios_printed() {
  within 60 xcrun simctl spawn "$device" log show --style compact --start "$since" \
    --predicate "process == \"$executable\" AND eventMessage BEGINSWITH \"flutter: \"" || true
}

ios_alive() {
  kill -0 "$pid" 2> /dev/null
}

# What the app printed, the end of its log, and its crash report if it
# crashed.
ios_log() {
  echo "What the app printed:"
  ios_printed
  echo "The end of the log of the app:"
  within 60 xcrun simctl spawn "$device" log show --style compact --start "$since" \
    --predicate "process == \"$executable\"" | tail -n 100 || true
  local report
  report="$(find "$HOME/Library/Logs/DiagnosticReports" -name "$executable-*.ips" -newermt "$since" 2> /dev/null | head -n 1)"
  if [ -n "$report" ]; then
    echo "The crash report $report:"
    head -n 120 "$report"
  fi
}

alive() { "${platform}_alive"; }
show_log() { "${platform}_log"; }

"$platform"
