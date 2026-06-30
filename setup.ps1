# ============================================================
#  Ishaqiyin App — one-shot setup (Flutter)
#  Generates the Android platform scaffold, applies the clean
#  manifest, fetches packages, and generates the launcher icon.
#
#  Usage:
#     ./setup.ps1                 # assumes Flutter is installed
#     ./setup.ps1 -InstallFlutter # also git-clones Flutter (stable) if missing
# ============================================================
param(
    [switch]$InstallFlutter
)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $proj
Write-Host "Project: $proj" -ForegroundColor Cyan

function Have($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# 1) Ensure Flutter -------------------------------------------------
if (-not (Have flutter)) {
    if ($InstallFlutter) {
        if (-not (Have git)) { throw "git is required to install Flutter. Install Git first: https://git-scm.com" }
        $dest = Join-Path $HOME "flutter"
        if (-not (Test-Path $dest)) {
            Write-Host "Cloning Flutter (stable) into $dest ... this is large (~1GB)" -ForegroundColor Yellow
            git clone --depth 1 -b stable https://github.com/flutter/flutter.git $dest
        }
        $env:Path = "$dest\bin;" + $env:Path
        Write-Host "Flutter added to PATH for this session." -ForegroundColor Green
    } else {
        Write-Host "Flutter not found." -ForegroundColor Red
        Write-Host "Install it (https://docs.flutter.dev/get-started/install/windows) then re-run," -ForegroundColor Red
        Write-Host "or run:  ./setup.ps1 -InstallFlutter" -ForegroundColor Red
        exit 1
    }
}

flutter --version

# 2) Generate the Android platform scaffold (skips existing lib/pubspec) ----
Write-Host "Generating Android scaffold..." -ForegroundColor Cyan
flutter create --platforms=android --org com.ali --project-name menbaradkshk .

# 3) Apply the clean AndroidManifest (overwrites the generated one) ----
$manifestSrc = Join-Path $proj "_overrides\AndroidManifest.xml"
$manifestDst = Join-Path $proj "android\app\src\main\AndroidManifest.xml"
Copy-Item $manifestSrc $manifestDst -Force
Write-Host "Applied clean AndroidManifest.xml" -ForegroundColor Green

# 3b) Firebase needs minSdk >= 23 — patch the Gradle file ------------
$gradleKts = Join-Path $proj "android\app\build.gradle.kts"
$gradleGroovy = Join-Path $proj "android\app\build.gradle"
if (Test-Path $gradleKts) {
    (Get-Content $gradleKts -Raw) `
        -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23' `
        | Set-Content $gradleKts -Encoding UTF8
    Write-Host "Set minSdk = 23 (build.gradle.kts)" -ForegroundColor Green
} elseif (Test-Path $gradleGroovy) {
    (Get-Content $gradleGroovy -Raw) `
        -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23' `
        | Set-Content $gradleGroovy -Encoding UTF8
    Write-Host "Set minSdkVersion 23 (build.gradle)" -ForegroundColor Green
}

# 4) Remove the stray placeholder package folder if it is empty -------
$stray = Join-Path $proj "android\app\src\main\kotlin\com\ali\menbaradkshk"
if (Test-Path $stray) {
    if (-not (Get-ChildItem $stray -Recurse -File)) { Remove-Item $stray -Recurse -Force }
}

# 5) Packages + launcher icon ----------------------------------------
flutter pub get
try { dart run flutter_launcher_icons } catch { Write-Host "Icon generation skipped: $_" -ForegroundColor Yellow }

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " Setup complete." -ForegroundColor Green
Write-Host " Connect your phone (USB debugging) then run:" -ForegroundColor Green
Write-Host "   flutter devices" -ForegroundColor White
Write-Host "   flutter run" -ForegroundColor White
Write-Host " Build a shareable APK:" -ForegroundColor Green
Write-Host "   flutter build apk --release" -ForegroundColor White
Write-Host " Build an App Bundle for Google Play:" -ForegroundColor Green
Write-Host "   flutter build appbundle --release" -ForegroundColor White
Write-Host "==================================================" -ForegroundColor Green
