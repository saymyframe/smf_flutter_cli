# install_firebase_windows.ps1
# Purpose: Ensure Firebase CLI is installed on Windows.
# Flow: check firebase -> check node -> install node (winget/choco/scoop/portable ZIP) -> npm i -g firebase-tools -> PATH -> verify
# Notes:
# - Runs in user scope where possible. Portable Node ZIP does not require admin.
# - PATH changes affect new terminals only.

$ErrorActionPreference = "Stop"

function Command-Exists($name) {
  try { Get-Command $name -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

function Add-UserPathEntry($pathEntry) {
  if ([string]::IsNullOrWhiteSpace($pathEntry)) { return }
  $cur = [Environment]::GetEnvironmentVariable('Path','User')
  if ([string]::IsNullOrWhiteSpace($cur)) { $cur = "" }
  if ($cur.ToLower().Split(';') -contains $pathEntry.ToLower()) { return }
  $newPath = if ($cur.Trim().Length -gt 0) { "$cur;$pathEntry" } else { $pathEntry }
  setx Path $newPath | Out-Null
  Write-Host "PATH updated with: $pathEntry (restart the terminal to take effect)"
}

function Ensure-PortableNode {
  # Download latest LTS ZIP, extract to %LOCALAPPDATA%\Programs\node and add to PATH
  $index = Invoke-RestMethod https://nodejs.org/dist/index.json
  $lts = $index | Where-Object { $_.lts -ne $null } | Select-Object -First 1
  $ver = $lts.version.TrimStart('v')
  $zipUrl = "https://nodejs.org/dist/v$ver/node-v$ver-win-x64.zip"

  $dst = Join-Path $env:LOCALAPPDATA "Programs\node"
  $tmpZip = Join-Path $env:TEMP "node-v$ver-win-x64.zip"

  Invoke-WebRequest $zipUrl -OutFile $tmpZip
  if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
  Expand-Archive $tmpZip -DestinationPath (Split-Path $dst)
  Rename-Item (Join-Path (Split-Path $dst) "node-v$ver-win-x64") $dst

  Add-UserPathEntry $dst
  Add-UserPathEntry (Join-Path $dst "node_modules\npm\bin")
  Add-UserPathEntry (Join-Path $env:APPDATA "npm")

  $nodeExe = Join-Path $dst "node.exe"
  if (-not (Test-Path $nodeExe)) { throw "Portable Node installation failed" }
  return $dst
}

# 1) Already have firebase?
if (Command-Exists 'firebase') {
  Write-Host "Firebase CLI already installed"
  exit 0
}

# 2) Ensure Node
$hasNode = Command-Exists 'node'
if (-not $hasNode) {
  if (Command-Exists 'winget') {
    # Silent install Node LTS via winget
    winget install OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
    $hasNode = Command-Exists 'node'
  } elseif (Command-Exists 'choco') {
    choco install nodejs-lts -y | Out-Null
    $hasNode = Command-Exists 'node'
  } elseif (Command-Exists 'scoop') {
    scoop install nodejs-lts | Out-Null
    $hasNode = Command-Exists 'node'
  }

  if (-not $hasNode) {
    # Fallback to portable ZIP
    $portableRoot = Ensure-PortableNode
    $hasNode = Test-Path (Join-Path $portableRoot "node.exe")
  }
}

if (-not $hasNode) {
  Write-Error "Node.js installation failed"
  exit 1
}

# 3) Install Firebase CLI via npm (prefer calling npm from PATH; if missing, call npm-cli.js directly)
function Npm-Install-Firebase {
  if (Command-Exists 'npm') {
    npm i -g firebase-tools
  } else {
    $localNode = Join-Path $env:LOCALAPPDATA "Programs\node"
    $npmCli   = Join-Path $localNode "node_modules\npm\bin\npm-cli.js"
    $nodeExe  = Join-Path $localNode "node.exe"
    if (-not (Test-Path $nodeExe)) { throw "npm not found and no portable Node detected" }
    & $nodeExe $npmCli i -g firebase-tools
  }
}
Npm-Install-Firebase

# 4) Ensure %APPDATA%\npm in PATH for global npm binaries
$npmBin = Join-Path $env:APPDATA "npm"
Add-UserPathEntry $npmBin

# 5) Verify
# Try via PATH
if (Command-Exists 'firebase') {
  firebase --version
  exit 0
}

# Try direct .cmd path if PATH not refreshed yet
$fbCmd = Join-Path $npmBin "firebase.cmd"
if (Test-Path $fbCmd) {
  & $fbCmd --version
  exit 0
}

Write-Error "Firebase CLI verification failed"
exit 1
