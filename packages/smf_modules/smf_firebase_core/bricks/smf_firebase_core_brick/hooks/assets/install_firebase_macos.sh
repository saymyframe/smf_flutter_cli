#!/usr/bin/env bash
# install_firebase_macos.sh
# Purpose: Ensure Firebase CLI is installed on macOS.
# Flow: check firebase -> ensure node (brew or nvm fallback) -> npm i -g firebase-tools -> ensure npm bin in PATH -> verify

set -euo pipefail

command_exists() { command -v "$1" >/dev/null 2>&1; }

ensure_node_macos() {
  if command_exists brew; then
    brew install node
  else
    # Fallback to nvm in user scope
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts
  fi
}

ensure_path_contains() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

append_path_to_shell_rc_macos() {
  local entry="$1"
  # On modern macOS default shell is zsh
  local rc="$HOME/.zprofile"
  if [ -n "${BASH_VERSION:-}" ]; then rc="$HOME/.bash_profile"; fi
  touch "$rc"
  if ! grep -Fq "$entry" "$rc"; then
    echo "export PATH=\"\$PATH:$entry\"" >> "$rc"
    echo "PATH updated in $rc with: $entry (open a new terminal to take effect)"
  fi
}

# 1) Already have firebase?
if command_exists firebase; then
  echo "Firebase CLI already installed"
  exit 0
fi

# 2) Ensure Node
if ! command_exists node; then
  ensure_node_macos
fi

# Source nvm if needed to expose npm
if ! command_exists npm && [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.nvm/nvm.sh"
fi

# 3) Install Firebase CLI
npm i -g firebase-tools

# 4) Ensure global npm bin in PATH
npm_bin="$(npm bin -g 2>/dev/null || true)"
if [ -n "$npm_bin" ] && ! ensure_path_contains "$npm_bin"; then
  append_path_to_shell_rc_macos "$npm_bin"
fi

# 5) Verify
if command_exists firebase; then
  firebase --version
  exit 0
fi
if [ -n "$npm_bin" ] && [ -x "$npm_bin/firebase" ]; then
  "$npm_bin/firebase" --version
  exit 0
fi

echo "Firebase CLI verification failed" >&2
exit 1
