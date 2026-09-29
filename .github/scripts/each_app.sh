#!/usr/bin/env bash
# Runs a command for each app in a directory, one after another: the apps
# are the directories right in it, such as the apps with every module that
# the --create of packages/smf_flutter_cli/tool/matrix.dart generates
# there, one for each combination of the providers of the roles that take
# one. So a new provider of such a role gets the command too.
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

command="${1##*/}"
failed=()
for app in "${apps[@]}"; do
  name="${app##*/}"
  echo "=== $name: $*"
  if [ -n "$variable" ]; then
    code=0
    env "$variable=$app" "$@" || code=$?
  else
    code=0
    (cd "$app" && "$@") || code=$?
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
