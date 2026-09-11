param([int]$Port = 5173)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Install Flutter and add its bin directory to PATH. See README.md.'
}
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter run -d web-server --web-hostname 127.0.0.1 --web-port $Port
exit $LASTEXITCODE
