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
# With --tool-arguments, before or after --env, the command of each app
# also gets the arguments of the flutter tool that build the app with its
# values, such as --dart-define-from-file=.env, which a release build of an
# app with values needs: the lines of <app>.tool_arguments next to the
# app, outside it, which the --create of
# packages/smf_flutter_cli/tool/matrix.dart writes, and which are none for
# an app that needs none. They come after the arguments of the command,
# or, with --env, in the environment variable SMF_TOOL_ARGUMENTS, one on
# each line, for a command such as the tests of a package that build the
# app. The script does not run the command for an app without that file.
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

usage() {
  echo "Usage: $0 [--env <variable>] [--tool-arguments] <directory of apps> <command>..." >&2
  exit 64
}

env_given=
variable=
tool_arguments=
while [ $# -gt 0 ]; do
  case "$1" in
    --env)
      if [ $# -lt 2 ]; then
        usage
      fi
      env_given=1
      variable="$2"
      shift 2
      ;;
    --tool-arguments)
      tool_arguments=1
      shift
      ;;
    *) break ;;
  esac
done
if [ $# -lt 2 ] || [ ! -d "$1" ] || { [ -n "$env_given" ] && [[ ! "$variable" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; }; then
  usage
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

# Reads the tool arguments of the app $1 into the array arguments, one on
# each line of its file, without the empty lines, and fails when the app
# has no such file.
read_tool_arguments() {
  local file="$1.tool_arguments" argument
  arguments=()
  if [ ! -f "$file" ]; then
    return 1
  fi
  while IFS= read -r argument || [ -n "$argument" ]; do
    if [ -n "$argument" ]; then
      arguments+=("$argument")
    fi
  done < "$file"
}

command="${1##*/}"
failed=()
for app in "${apps[@]}"; do
  name="${app##*/}"
  # The arguments that the command gets after its own; the form keeps an
  # empty array from an unbound variable in bash 3, which macOS has.
  arguments=()
  if [ -n "$tool_arguments" ] && ! read_tool_arguments "$app"; then
    failed+=("$name")
    echo "::error::$name has no file of the arguments of the flutter tool that build it with its values, $app.tool_arguments, which the --create of packages/smf_flutter_cli/tool/matrix.dart writes next to the app: $command does not run for it without them."
    continue
  fi
  code=0
  if [ -n "$env_given" ]; then
    assignments=("$variable=$app")
    if [ -n "$tool_arguments" ]; then
      assignments+=("SMF_TOOL_ARGUMENTS=$(printf '%s\n' ${arguments[@]+"${arguments[@]}"})")
      echo "=== $name: $*, with SMF_TOOL_ARGUMENTS=${arguments[*]+"${arguments[*]}"}"
    else
      echo "=== $name: $*"
    fi
    env "${assignments[@]}" "$@" || code=$?
    keep_reports . "$name"
  else
    echo "=== $name: $* ${arguments[*]+"${arguments[*]}"}"
    (cd "$app" && "$@" ${arguments[@]+"${arguments[@]}"}) || code=$?
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
