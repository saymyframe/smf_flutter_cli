#!/usr/bin/env bash
# install_firebase_linux.sh
# Purpose: Ensure Firebase CLI is installed on Linux without sudo.
# Flow:
#   1) If firebase exists -> exit 0
#   2) If node exists:
#        - ensure node major >= 20, otherwise install nvm + Node LTS (user scope)
#        - ensure npm global prefix is user-writable (~/$..., not /usr), switch to ~/.npm-global if needed
#      Else:
#        - install nvm + Node LTS (user scope)
#   3) npm i -g firebase-tools
#   4) Add npm bin to PATH for future shells, create ~/.local/bin shim, verify via absolute path
#
# Notes:
# - No sudo required. We never write to /usr.
# - If npm points to a system prefix, we switch it to $HOME/.npm-global.

set -euo pipefail

command_exists() { command -v "$1" >/dev/null 2>&1; }

choose_shell_rc() {
  # Pick a sensible rc file to append PATH for future shells
  if [[ "${SHELL:-}" = *"zsh" ]]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
}

append_path_once() {
  local entry="$1"
  local rc; rc="$(choose_shell_rc)"
  touch "$rc"
  if ! grep -Fq "$entry" "$rc" 2>/dev/null; then
    echo "export PATH=\"\$PATH:$entry\"" >> "$rc"
    echo "PATH updated in $rc with: $entry (open a new terminal to take effect)"
  fi
}

ensure_nvm_loaded() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    return 0
  fi
  return 1
}

install_nvm_if_needed() {
  if ensure_nvm_loaded; then
    return 0
  fi
  if ! command_exists curl && ! command_exists wget; then
    echo "curl or wget is required to install nvm. Please install one and re-run." >&2
    exit 1
  fi
  export NVM_INSTALL_GIT=0
  if command_exists curl; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  else
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  fi
  ensure_nvm_loaded || { echo "Failed to load nvm after install." >&2; exit 1; }
}

node_major_version() {
  # Prints Node major version number or 0 if not available
  if ! command_exists node; then echo 0; return; fi
  local v; v="$(node -v 2>/dev/null || echo v0)"
  v="${v#v}"
  echo "${v%%.*}"
}

ensure_user_npm_prefix() {
  # If npm global prefix is /usr* or outside $HOME, switch to ~/.npm-global.
  if ! command_exists npm; then return 0; fi
  local prefix; prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ -z "$prefix" || "$prefix" == /usr* || "$prefix" != "$HOME"* ]]; then
    local user_prefix="$HOME/.npm-global"
    mkdir -p "$user_prefix"
    npm config set prefix "$user_prefix" >/dev/null
  fi
}

npm_bin_dir() {
  npm bin -g 2>/dev/null || true
}

install_firebase_tools() {
  npm i -g firebase-tools
}

ensure_local_shim() {
  # Create ~/.local/bin/firebase wrapper that forwards to current npm -g path
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/firebase" <<'EOF'
#!/usr/bin/env bash
exec "$(npm bin -g)/firebase" "$@"
EOF
  chmod +x "$HOME/.local/bin/firebase"
  # Ensure ~/.local/bin in PATH for future shells
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
      local rc; rc="$(choose_shell_rc)"
      touch "$rc"
      if ! grep -Fq '$HOME/.local/bin' "$rc" 2>/dev/null; then
        echo 'export PATH="$PATH:$HOME/.local/bin"' >> "$rc"
        echo "PATH updated in $rc with: \$HOME/.local/bin (open a new terminal to take effect)"
      fi
      ;;
  esac
}

verify_and_finish() {
  local npm_bin; npm_bin="$(npm_bin_dir)"
  if [ -n "$npm_bin" ] && [ -x "$npm_bin/firebase" ]; then
    "$npm_bin/firebase" --version
    append_path_once "$npm_bin"
    ensure_local_shim
    echo ""
    echo "Tip: open a new terminal and run: firebase --help"
    echo "Or use absolute path now: $npm_bin/firebase --help"
    exit 0
  fi
  if command_exists firebase; then
    firebase --version
    exit 0
  fi
  echo "Firebase CLI verification failed" >&2
  exit 1
}

# 1) Already have firebase?
if command_exists firebase; then
  echo "Firebase CLI already installed"
  exit 0
fi

# 2) Ensure Node >= 20 without sudo
if command_exists node; then
  if [ "$(node_major_version)" -lt 20 ]; then
    install_nvm_if_needed
    nvm install --lts
    nvm use --lts >/dev/null
  fi
else
  install_nvm_if_needed
  nvm install --lts
  nvm use --lts >/dev/null
fi

# If npm still not on PATH after nvm install, source nvm again
if ! command_exists npm; then
  ensure_nvm_loaded || true
fi

# 3) Ensure npm writes to a user prefix, then install firebase-tools
ensure_user_npm_prefix
install_firebase_tools

# 4) Verify (absolute path) + add PATH for future shells + create shim
verify_and_finish
