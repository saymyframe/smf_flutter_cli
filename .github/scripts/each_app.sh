#!/usr/bin/env bash
# Runs a command for each app in a directory, one after another: the apps
# are the directories right in it, such as the app with every module of a
# job of the plan of CI that the --create of
# packages/smf_flutter_cli/tool/matrix.dart generates there with --app,
# named after the providers other than the first of their roles. So a step
# needs no name of an app, and the app of a new provider gets the command
# too.
#
#   each_app.sh <directory of apps> <command>...
#     runs the command in the directory of each app;
#   each_app.sh --env <variable> <directory of apps> <command>...
#     runs it in the current directory, with the path of each app in the
#     environment variable, such as for the tests of a package that take
#     the app from the environment.
#
# The script runs the command for every app even when it fails for one,
# and fails at the end when it failed for any, naming them, or when the
# directory has no app.
#
# A report of tests that the command writes, as dart test does with
# --file-reporter json:<path>, gets the name of the app once the command
# ran for it, <path without .json>.<app>.json, so that the command for the
# next app does not replace it, and tools/test_annotations.dart annotates
# the tests that failed for each app. tools/each_app_test.dart tests the
# script.
set -euo pipefail

variable=
if [ "${1:-}" = --env ] && [ $# -ge 2 ]; then
  variable="$2"
  shift 2
fi
if [ $# -lt 2 ] || [ ! -d "$1" ] || { [ -n "$variable" ] && [[ ! "$variable" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; }; then
  echo "Usage: $0 [--env <variable>] <directory of apps> <command>..." >&2
  exit 64
fi
directory="${1%/}"
shift

apps=()
for app in "$directory"/*/; do
  if [ -d "$app" ]; then
    apps+=("${app%/}")
  fi
done
if [ ${#apps[@]} -eq 0 ]; then
  echo "::error::$directory has no app."
  exit 1
fi

# The reports of tests that the command writes, from the directory it runs
# in: the path of each --file-reporter <reporter>:<path> and
# --file-reporter=<reporter>:<path> of its arguments, as dart test takes
# them.
reports=()
previous=
for argument in "$@"; do
  if [ "$previous" = --file-reporter ]; then
    reports+=("${argument#*:}")
  fi
  case "$argument" in
    --file-reporter=*)
      reporter="${argument#--file-reporter=}"
      reports+=("${reporter#*:}")
      ;;
  esac
  previous="$argument"
done

# Gives the reports that the command wrote in the directory $1 the name of
# the app $2.
keep_reports() {
  local report path base
  if [ ${#reports[@]} -eq 0 ]; then
    return 0
  fi
  for report in "${reports[@]}"; do
    case "$report" in
      /*) path="$report" ;;
      *) path="$1/$report" ;;
    esac
    if [ -f "$path" ]; then
      base="$(basename "$path")"
      case "$base" in
        *.*) mv "$path" "$(dirname "$path")/${base%.*}.$2.${base##*.}" ;;
        *) mv "$path" "$path.$2" ;;
      esac
    fi
  done
}

command="${1##*/}"
failed=()
for app in "${apps[@]}"; do
  name="${app##*/}"
  echo "=== $name: $*"
  code=0
  if [ -n "$variable" ]; then
    env "$variable=$app" "$@" || code=$?
    keep_reports . "$name"
  else
    (cd "$app" && "$@") || code=$?
    keep_reports "$app" "$name"
  fi
  if [ "$code" -ne 0 ]; then
    failed+=("$name")
    echo "::error::$command failed for $name with the exit code $code."
  fi
done
if [ ${#failed[@]} -gt 0 ]; then
  echo "::error::$command failed for ${#failed[@]} of the ${#apps[@]} apps in $directory: ${failed[*]}."
  exit 1
fi
echo "$command passed for the ${#apps[@]} apps in $directory: ${apps[*]##*/}."
