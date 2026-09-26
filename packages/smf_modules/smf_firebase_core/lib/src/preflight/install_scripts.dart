import 'package:smf_contracts/lego.dart';

/// What an install script prints before each directory with the executables
/// that the rest of the run needs: those of the Firebase CLI and of Node.js,
/// which the Firebase CLI runs on.
const binDirPrefix = 'smf-bin-dir=';

/// A script that installs the Firebase CLI with npm, and how to run it.
final class InstallScript {
  /// Creates the script [text] named [fileName], which [shell] runs with
  /// [arguments] before its path.
  const InstallScript({
    required this.fileName,
    required this.shell,
    required this.text,
    this.arguments = const [],
    this.standaloneFallback = false,
  });

  /// The name of the temporary file of the script.
  final String fileName;

  /// The executable that runs the script.
  final String shell;

  /// The arguments of [shell] before the path of the script.
  final List<String> arguments;

  /// The script.
  final String text;

  /// Whether the standalone binary of the Firebase CLI can replace it when
  /// the installation with npm fails.
  final bool standaloneFallback;

  /// The script for [system], or `null` if there is none.
  static InstallScript? of(HostOperatingSystem system) => switch (system) {
        HostOperatingSystem.macos => const InstallScript(
            fileName: 'install_firebase_macos.sh',
            shell: 'bash',
            text: _macos,
            standaloneFallback: true,
          ),
        HostOperatingSystem.linux => const InstallScript(
            fileName: 'install_firebase_linux.sh',
            shell: 'bash',
            text: _linux,
            standaloneFallback: true,
          ),
        HostOperatingSystem.windows => const InstallScript(
            fileName: 'install_firebase_windows.ps1',
            shell: 'powershell',
            arguments: [
              '-ExecutionPolicy',
              'Bypass',
              '-NoLogo',
              '-NonInteractive',
              '-File',
            ],
            text: _windows,
          ),
        HostOperatingSystem.other => null,
      };
}

/// The directories that an install script printed in [output], each once.
List<String> binDirsIn(String output) => [
      ...{
        for (final line in output.split('\n'))
          if (line.trim() case final text when text.startsWith(binDirPrefix))
            if (text.substring(binDirPrefix.length).trim() case final directory
                when directory.isNotEmpty)
              directory,
      },
    ];

/// The command that installs the standalone binary of the Firebase CLI, in
/// /usr/local/bin, on macOS and Linux; it asks for the password of the user
/// when it needs sudo to write there.
const standaloneInstallCommand = 'curl -sL https://firebase.tools | bash';

/// The directory where [standaloneInstallCommand] puts the Firebase CLI.
const standaloneBinDir = '/usr/local/bin';

const _macos = r'''
#!/usr/bin/env bash
# Installs the Firebase CLI on macOS with npm, for SMF.
#
# When Node.js is missing or older than 20, which the Firebase CLI needs, it
# installs it first: with Homebrew if there is one, or else with nvm in the
# home directory. It adds the directory of the
# global npm executables to the PATH of new terminals, and prints the
# directories of the Firebase CLI and of Node.js as lines
# "smf-bin-dir=<directory>".
set -euo pipefail

command_exists() { command -v "$1" >/dev/null 2>&1; }

path_contains() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Loads nvm into this shell; fails when nvm is not installed.
load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [ -s "$NVM_DIR/nvm.sh" ] || return 1
  # nvm reads variables that may be unset.
  set +u
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  set -u
}

install_node() {
  if command_exists brew; then
    brew install node
    return
  fi
  if ! load_nvm; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    load_nvm
  fi
  set +u
  nvm install --lts
  set -u
}

# The major version of Node.js, or 0 if it is missing.
node_major_version() {
  if ! command_exists node; then
    echo 0
    return
  fi
  local version
  version="$(node -v 2>/dev/null || echo v0)"
  version="${version#v}"
  echo "${version%%.*}"
}

# Adds the directory $1 to the PATH in the profile of the login shell, which
# new terminals read.
add_to_path_of_new_terminals() {
  local profile="$HOME/.zprofile"
  case "${SHELL:-}" in
    */bash) profile="$HOME/.bash_profile" ;;
  esac
  touch "$profile"
  if ! grep -Fq "$1" "$profile"; then
    echo "export PATH=\"\$PATH:$1\"" >> "$profile"
    echo "Added $1 to the PATH in $profile for new terminals."
  fi
}

if ! command_exists firebase; then
  if [ "$(node_major_version)" -lt 20 ]; then
    install_node
    # An older node earlier on the PATH still comes first.
    if [ "$(node_major_version)" -lt 20 ]; then
      echo "The Firebase CLI needs Node.js 20 or newer, but node is $(node -v 2>/dev/null || echo missing)." >&2
      exit 1
    fi
  fi
  if ! command_exists npm; then
    load_nvm || true
  fi
  npm install -g firebase-tools
  npm_bin="$(npm prefix -g)/bin"
  if ! path_contains "$npm_bin"; then
    add_to_path_of_new_terminals "$npm_bin"
  fi
  export PATH="$npm_bin:$PATH"
fi

firebase --version
echo "smf-bin-dir=$(dirname "$(command -v firebase)")"
if command_exists node; then
  echo "smf-bin-dir=$(dirname "$(command -v node)")"
fi
''';

const _linux = r'''
#!/usr/bin/env bash
# Installs the Firebase CLI on Linux with npm, without sudo, for SMF.
#
# When Node.js is missing or older than 20, it installs its LTS version with
# nvm in the home directory. When the global npm directory is outside the
# home directory, it moves it to ~/.npm-global. It adds the directory of the
# global npm executables to the PATH of new terminals, with a firebase
# command in ~/.local/bin, and prints the directories of the Firebase CLI and
# of Node.js as lines "smf-bin-dir=<directory>".
set -euo pipefail

command_exists() { command -v "$1" >/dev/null 2>&1; }

path_contains() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

# The file that new terminals of the shell of the user read.
shell_rc() {
  if [[ "${SHELL:-}" = *zsh ]]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
}

# Adds $1, as it is written, to the PATH in the rc file of the shell.
add_to_path_of_new_terminals() {
  local rc
  rc="$(shell_rc)"
  touch "$rc"
  if ! grep -Fq "$1" "$rc"; then
    echo "export PATH=\"\$PATH:$1\"" >> "$rc"
    echo "Added $1 to the PATH in $rc for new terminals."
  fi
}

# Loads nvm into this shell; fails when nvm is not installed.
load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [ -s "$NVM_DIR/nvm.sh" ] || return 1
  # nvm reads variables that may be unset.
  set +u
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  set -u
}

install_nvm() {
  if load_nvm; then
    return 0
  fi
  if command_exists curl; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  elif command_exists wget; then
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  else
    echo "Installing nvm needs curl or wget." >&2
    exit 1
  fi
  load_nvm || { echo "nvm did not load after its installation." >&2; exit 1; }
}

# The major version of Node.js, or 0 if it is missing.
node_major_version() {
  if ! command_exists node; then
    echo 0
    return
  fi
  local version
  version="$(node -v 2>/dev/null || echo v0)"
  version="${version#v}"
  echo "${version%%.*}"
}

# Moves the global npm directory to ~/.npm-global when it is outside the
# home directory, so installing needs no sudo.
use_npm_prefix_in_home() {
  local prefix
  prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ -z "$prefix" || "$prefix" == /usr* || "$prefix" != "$HOME"* ]]; then
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" >/dev/null
  fi
}

# A firebase command in ~/.local/bin that runs the one of the global npm
# directory, for shells that have ~/.local/bin on the PATH.
add_firebase_command() {
  mkdir -p "$HOME/.local/bin"
  cat > "$HOME/.local/bin/firebase" <<'EOF'
#!/usr/bin/env bash
exec "$(npm prefix -g)/bin/firebase" "$@"
EOF
  chmod +x "$HOME/.local/bin/firebase"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) add_to_path_of_new_terminals '$HOME/.local/bin' ;;
  esac
}

if ! command_exists firebase; then
  if [ "$(node_major_version)" -lt 20 ]; then
    install_nvm
    set +u
    nvm install --lts
    nvm use --lts >/dev/null
    set -u
  fi
  if ! command_exists npm; then
    load_nvm || true
  fi
  use_npm_prefix_in_home
  npm install -g firebase-tools
  npm_bin="$(npm prefix -g)/bin"
  # nvm puts the directory of its Node.js on the PATH itself.
  if ! path_contains "$npm_bin"; then
    add_to_path_of_new_terminals "$npm_bin"
  fi
  add_firebase_command
  export PATH="$npm_bin:$PATH"
fi

firebase --version
echo "smf-bin-dir=$(dirname "$(command -v firebase)")"
if command_exists node; then
  echo "smf-bin-dir=$(dirname "$(command -v node)")"
fi
''';

const _windows = r'''
# Installs the Firebase CLI on Windows with npm, for SMF.
#
# When Node.js is missing or older than 20, which the Firebase CLI needs, it
# installs it first: with winget, Chocolatey or Scoop, or else from the
# portable ZIP of its LTS version in %LOCALAPPDATA%\Programs\node. It adds the directories to the PATH of the
# user for new terminals, and prints the directories of the Firebase CLI and
# of Node.js as lines "smf-bin-dir=<directory>".
$ErrorActionPreference = "Stop"

function Command-Exists($name) {
  try { Get-Command $name -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

function Add-UserPathEntry($pathEntry) {
  if ([string]::IsNullOrWhiteSpace($pathEntry)) { return }
  $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ([string]::IsNullOrWhiteSpace($cur)) { $cur = "" }
  if ($cur.ToLower().Split(';') -contains $pathEntry.ToLower()) { return }
  $newPath = if ($cur.Trim().Length -gt 0) { "$cur;$pathEntry" } else { $pathEntry }
  # Unlike setx, it does not cut a PATH longer than 1024 characters.
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  Write-Host "Added $pathEntry to the PATH for new terminals."
}

# The major version of Node.js, or 0 if it is missing.
function Get-NodeMajorVersion {
  try {
    $version = (& node -v | Out-String).Trim().TrimStart('v')
    return [int]($version.Split('.')[0])
  } catch { return 0 }
}

$portableNode = Join-Path $env:LOCALAPPDATA "Programs\node"

function Install-PortableNode {
  # The ZIP of the latest LTS version, extracted to %LOCALAPPDATA%\Programs\node.
  $index = Invoke-RestMethod https://nodejs.org/dist/index.json
  $lts = $index | Where-Object { $_.lts -ne $false -and $_.lts -ne $null } | Select-Object -First 1
  $ver = $lts.version.TrimStart('v')
  $zipUrl = "https://nodejs.org/dist/v$ver/node-v$ver-win-x64.zip"
  $tmpZip = Join-Path $env:TEMP "node-v$ver-win-x64.zip"

  Invoke-WebRequest $zipUrl -OutFile $tmpZip
  if (Test-Path $portableNode) { Remove-Item $portableNode -Recurse -Force }
  Expand-Archive $tmpZip -DestinationPath (Split-Path $portableNode)
  Rename-Item (Join-Path (Split-Path $portableNode) "node-v$ver-win-x64") $portableNode

  Add-UserPathEntry $portableNode
  if (-not (Test-Path (Join-Path $portableNode "node.exe"))) { throw "The portable Node.js was not installed." }
  $env:Path = "$portableNode;$env:Path"
}

if (-not (Command-Exists 'firebase')) {
  if ((Get-NodeMajorVersion) -lt 20) {
    if (Command-Exists 'winget') {
      winget install OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
    } elseif (Command-Exists 'choco') {
      choco install nodejs-lts -y | Out-Null
    } elseif (Command-Exists 'scoop') {
      scoop install nodejs-lts | Out-Null
    }
    # A new installation is on the PATH of new terminals only.
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$env:Path;$machinePath;$userPath"
    # The portable one goes first on the PATH of this script.
    if ((Get-NodeMajorVersion) -lt 20) { Install-PortableNode }
  }

  if (Command-Exists 'npm') {
    npm install -g firebase-tools
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $npmBin = (npm prefix -g | Out-String).Trim()
  } else {
    $nodeExe = Join-Path $portableNode "node.exe"
    $npmCli = Join-Path $portableNode "node_modules\npm\bin\npm-cli.js"
    if (-not (Test-Path $nodeExe)) { throw "npm was not found, and there is no portable Node.js." }
    & $nodeExe $npmCli install -g firebase-tools
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $npmBin = (& $nodeExe $npmCli prefix -g | Out-String).Trim()
  }
  Add-UserPathEntry $npmBin
  $env:Path = "$npmBin;$env:Path"
}

$firebase = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebase) {
  Write-Error "The Firebase CLI was not found after its installation."
  exit 1
}
# The Firebase CLI stops at once on a Node.js that is too old for it.
& $firebase.Source --version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output "smf-bin-dir=$(Split-Path $firebase.Source)"
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) { Write-Output "smf-bin-dir=$(Split-Path $node.Source)" }
''';
