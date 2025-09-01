#!/usr/bin/env bash
set -euo pipefail

# Generate CHANGELOG.md for packages/smf_contracts using git-cliff.
# Usage:
#   tools/generate_contracts_changelog.sh

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACTS_DIR="$ROOT_DIR/packages/smf_contracts"

if ! command -v git-cliff >/dev/null 2>&1; then
  echo "❌ git-cliff is not installed. Install via 'brew install git-cliff' or 'cargo install git-cliff'." >&2
  exit 1
fi

if [ ! -f "$CONTRACTS_DIR/pubspec.yaml" ]; then
  echo "❌ pubspec.yaml not found in $CONTRACTS_DIR" >&2
  exit 1
fi

cd "$CONTRACTS_DIR"

# Extract version from pubspec.yaml (expects line: version: x.y.z)
VERSION=$(awk '/^version:/{print $2}' pubspec.yaml)
if [ -z "${VERSION:-}" ]; then
  echo "❌ Could not read version from pubspec.yaml" >&2
  exit 1
fi

echo "ℹ️ Generating CHANGELOG for smf_contracts v$VERSION ..."
git-cliff -c "$ROOT_DIR/tools/cliff_contracts.toml" --tag "v$VERSION" -o CHANGELOG.md

echo "✅ CHANGELOG.md generated at $CONTRACTS_DIR/CHANGELOG.md"
echo "   Next steps (optional):"
echo "     git add CHANGELOG.md pubspec.yaml"
echo "     git commit -m \"chore(contracts): release v$VERSION\""
echo "     git tag v$VERSION && git push --follow-tags"


