param(
  [switch]$SkipChecks
)

$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

$localTemp = Join-Path (Get-Location) ".tmp\build-temp"
$gradleHome = Join-Path (Get-Location) ".gradle-user-home"
New-Item -ItemType Directory -Force -Path $localTemp, $gradleHome | Out-Null
$env:TEMP = $localTemp
$env:TMP = $localTemp
$env:GRADLE_USER_HOME = $gradleHome
if ($env:JAVA_TOOL_OPTIONS) {
  $env:JAVA_TOOL_OPTIONS = "$env:JAVA_TOOL_OPTIONS -Djava.io.tmpdir=$localTemp"
} else {
  $env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=$localTemp"
}
Write-Host "Gradle user home: $env:GRADLE_USER_HOME" -ForegroundColor Cyan

$version = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(\S+)' | ForEach-Object { $_.Matches.Groups[1].Value }
if (-not $version) { $version = "0.0.0" }
$productName = -join ([char[]](0x672A, 0x5B8C, 0x5267, 0x573A))
Write-Host "Version: $version" -ForegroundColor Cyan

flutter pub get
if ($LASTEXITCODE -ne 0) { exit 1 }

if (-not $SkipChecks) {
  Write-Host "Analyzing project..." -ForegroundColor Yellow
  flutter analyze
  if ($LASTEXITCODE -ne 0) { exit 1 }

  Write-Host "Running tests..." -ForegroundColor Yellow
  flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { exit 1 }
}

Write-Host "Building Web..." -ForegroundColor Yellow
flutter build web --release
if ($LASTEXITCODE -ne 0) { exit 1 }

$webZip = "build/$productName-$version-Web.zip"
if (Test-Path $webZip) { Remove-Item $webZip }
Compress-Archive -Path "build/web/*" -DestinationPath $webZip
Write-Host "Web: $webZip" -ForegroundColor Green

Write-Host "Building APK..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit 1 }

$apkDest = "build/$productName-$version-Android.apk"
if (Test-Path $apkDest) { Remove-Item $apkDest }
Copy-Item "build/app/outputs/flutter-apk/app-release.apk" $apkDest -Force
if (-not (Test-Path "android/key.properties")) {
  Write-Warning "APK uses a debug signing key. Configure android/key.properties for official distribution."
}
Write-Host "APK: $apkDest" -ForegroundColor Green

Write-Host "Done." -ForegroundColor Cyan
