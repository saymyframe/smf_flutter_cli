#!/usr/bin/env bash
# Checks that the app in the current directory starts: on the Android
# emulator or device $2 with $1 android, or on the booted iOS simulator
# with the UDID $2 with $1 ios, in at most $3 seconds once the device has
# the app. Neither the build nor the install counts: on a busy runner, the
# build of the Firebase SDK for iOS takes minutes longer than on another,
# and a new iOS simulator takes minutes to install an app that it mostly
# installs in half a minute, which would leave the start no time. The step
# of CI that runs the script limits the build, and the script gives the
# device a time of its own to install the app.
#
# The app has the start check that the CLI keeps in app_tests/start,
# integration_test/start_check.dart, which its matrix tool adds with
# --add-app-tests. The script builds an app with the check as its entry,
# for Android with build_apk.sh, which builds it again when a package of
# the Android SDK did not download. It installs the app anew, launches it
# with adb or simctl, and waits for the line that the check writes to the
# file smf_start_check in the temporary directory of the app: `passed`, or
# `failed: ` and the problems.
#
# $4 is the build mode of the app: debug, as when it is left out, or
# release, on Android only, since Flutter builds no release app for an iOS
# simulator. A release app is what a user installs: R8 shrinks its Java
# and Kotlin code and renames the classes that no rule keeps, so a plugin
# that looks a class up by its name, as through JNI, may work in a debug
# app and fail in a release one. It is built for the ABI of the device
# only, since the machine code of each ABI takes a build of its own. A
# release app is not debuggable, so run-as cannot read its files: the
# script reads the line that the check prints after `SMF_START_CHECK: ` to
# the log of the device instead, from the process that it launched, so
# that a line of an earlier run, which the log may still have, does not
# count.
# Nothing connects to the app, unlike flutter test, which must reach the VM
# service of the app and sometimes never does on the emulators and
# simulators of CI (on an iOS simulator, a race of flutter_tools:
# https://github.com/flutter/flutter/issues/181771). So a run that fails
# is not tried again. The script fails when the check fails, when the app
# stops before the check writes its result, as when it crashes at start-up,
# and when the result does not come in time, and then prints the log of
# the app.
set -euo pipefail
# shellcheck source=build_apk.sh
source "$(dirname "${BASH_SOURCE[0]}")/build_apk.sh"

if [ $# -lt 3 ] || [ $# -gt 4 ] || [[ ! "$1" =~ ^(android|ios)$ ]] ||
  [[ ! "$3" =~ ^[0-9]+$ ]] || [[ ! "${4:-debug}" =~ ^(debug|release)$ ]]; then
  echo "Usage: $0 <android|ios> <device> <seconds> [debug|release]" >&2
  exit 64
fi
platform="$1"
device="$2"
seconds="$3"
mode="${4:-debug}"
if [ "$platform" = ios ] && [ "$mode" = release ]; then
  echo "Flutter builds no release app for an iOS simulator: start it in debug." >&2
  exit 64
fi
check=integration_test/start_check.dart
result=smf_start_check
# The seconds that the commands of `step` have since the last `allow`, what
# they have them for, and when they end by SECONDS.
limit=
purpose=
deadline=

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
# it fails.
build() {
  local name="$1" code=0
  shift
  "$@" || code=$?
  if [ "$code" -ne 0 ]; then
    echo "::error::$name failed with the exit code $code."
    exit 1
  fi
}

# Gives the commands of `step` from here on $1 seconds in all, and $2 says
# what for in the error of the one that runs out of them.
allow() {
  limit="$1"
  purpose="$2"
  deadline=$((SECONDS + limit))
}

# Runs the command after $1, which names it, in the seconds that are left,
# and fails when it fails. Prints how long the command took, so that the
# log of a run that ran out of time shows what the device was slow with.
step() {
  local name="$1" left=$((deadline - SECONDS)) began=$SECONDS code=0
  shift
  if [ "$left" -gt 0 ]; then
    within "$left" "$@" || code=$?
  else
    code=142
  fi
  if [ "$code" -eq 142 ]; then
    echo "::error::$name did not finish in the $limit s $purpose."
    exit 1
  elif [ "$code" -ne 0 ]; then
    echo "::error::$name failed with the exit code $code."
    exit 1
  fi
  echo "$name took $((SECONDS - began)) s."
}

# Runs the command after $1, which names it, for at most 60 s, whether it
# fails or not, as when the device has no app to stop or to remove, and
# prints how long it took.
attempt() {
  local name="$1" began=$SECONDS
  shift
  within 60 "$@" 2> /dev/null || true
  echo "$name took $((SECONDS - began)) s."
}

# Waits for the result of the check, which the command in the arguments
# prints once the app wrote it, as long as `alive` finds the app running.
# Fails when the result is not `passed`, when the app stops before it, and
# when it does not come in the time that is left, and then prints the log
# of the app with `show_log`.
wait_for_result() {
  local launched=$SECONDS line
  while :; do
    if line="$("$@" 2> /dev/null)" && [ -n "$line" ]; then
      break
    fi
    if ! alive; then
      # The result may have come just before the app stopped.
      if line="$("$@" 2> /dev/null)" && [ -n "$line" ]; then
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
  if [ "$mode" = release ]; then
    android_target
    build 'flutter build apk' build_apk --release --target-platform "$target" -t "$check"
  else
    build 'flutter build apk' build_apk --debug -t "$check"
  fi
  # The application id and the activity that starts the app, from the APK,
  # with aapt2 of the newest build tools of the Android SDK.
  local apk="build/app/outputs/flutter-apk/app-$mode.apk" build_tools badging activity
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
  # An emulator of CI installs the app in less than 10 s.
  allow 120 'that the device has to install the app'
  step 'adb install' "${adb[@]}" install -r "$apk"
  trap 'within 30 "${adb[@]}" shell am force-stop "$id" || true' EXIT
  # pm clear stops the app and deletes its data, with the result of an
  # earlier run.
  step 'adb shell pm clear' "${adb[@]}" shell pm clear "$id"
  within 30 "${adb[@]}" logcat -c || true
  allow "$seconds" 'of the start of the app'
  step 'adb shell am start' "${adb[@]}" shell am start -W -n "$id/$activity"
  if [ "$mode" = release ]; then
    # The process that the script launched, whose lines of the log count.
    pid="$(within 30 "${adb[@]}" shell pidof "$id" 2> /dev/null | tr -d '\r')" || pid=
    pid="${pid%% *}"
    wait_for_result android_logged_result
  else
    # The files of a debug app can be read with run-as, which starts in the
    # directory of its data. The temporary directory of Dart is code_cache/
    # there: Flutter gives the engine the code cache of the app as its cache
    # directory (--cache-dir-path), which the Dart VM takes as systemTemp.
    wait_for_result within 30 "${adb[@]}" shell run-as "$id" cat "code_cache/$result"
  fi
  android_printed
}

# Sets target to the target platform of Flutter for the ABI of the device,
# such as android-arm64 for arm64-v8a, the one ABI that a release app is
# built for.
android_target() {
  local abi
  abi="$(within 30 "${adb[@]}" shell getprop ro.product.cpu.abi 2> /dev/null | tr -d '\r')" || abi=
  case "$abi" in
    arm64-v8a) target=android-arm64 ;;
    x86_64) target=android-x64 ;;
    armeabi-v7a) target=android-arm ;;
    *)
      echo "::error::Flutter builds no release app for the ABI '$abi' of the device $device."
      exit 1
      ;;
  esac
}

# The result that the check printed to the log of the device after
# `SMF_START_CHECK: `, with the tag flutter, from the process $pid. A line
# longer than the log takes is cut short there, which leaves a failure a
# failure.
android_logged_result() {
  [ -n "$pid" ] || return 1
  within 30 "${adb[@]}" logcat -d --pid="$pid" -s flutter |
    sed -n 's/^.*SMF_START_CHECK: //p' | tail -n 1
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
  # A new simulator on a macOS runner of CI mostly has the app in 20 to
  # 70 s, but one took over 200 s, and another was not done after 240 s.
  allow 480 'that the device has to install the app'
  # A new install, without the data of an earlier run and its result.
  attempt 'xcrun simctl terminate' xcrun simctl terminate "$device" "$id"
  attempt 'xcrun simctl uninstall' xcrun simctl uninstall "$device" "$id"
  step 'xcrun simctl install' xcrun simctl install "$device" "$app"
  trap 'within 60 xcrun simctl terminate "$device" "$id" 2> /dev/null || true' EXIT
  # The container of the data of the app, whose tmp/ is the temporary
  # directory of the app.
  data="$(within 60 xcrun simctl get_app_container "$device" "$id" data)"
  since="$(date '+%Y-%m-%d %H:%M:%S')"
  allow "$seconds" 'of the start of the app'
  launched="$(within 60 xcrun simctl launch "$device" "$id")" || {
    echo "::error::xcrun simctl launch failed: $launched"
    exit 1
  }
  # The app runs as a process of the Mac: simctl prints `<id>: <pid>`.
  pid="${launched##*: }"
  wait_for_result within 30 cat "$data/tmp/$result"
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
