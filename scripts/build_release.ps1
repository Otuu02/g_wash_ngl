# ============================================================
# G-Wash NG: Production Release Build Script
# 1. Automatically fetches latest SSL certificates for pinning
# 2. Compiles production release APK with certificate pinning baked in
# ============================================================

param(
    [switch]$SkipCertFetch
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  G-Wash NG: Building Production Release APK" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Fetch and bake certificate pins
if (-not $SkipCertFetch) {
    Write-Host "Step 1: Refreshing SSL Certificate Pinning..." -ForegroundColor Yellow
    powershell -ExecutionPolicy Bypass -File "scripts\fetch_cert_pins.ps1"
} else {
    Write-Host "Step 1: Skipping certificate fetch (using cached pins)..." -ForegroundColor Yellow
}

# Step 2: Build release APK
Write-Host ""
Write-Host "Step 2: Compiling Flutter Release APK..." -ForegroundColor Yellow
Write-Host ""

$ErrorActionPreference = "Continue"

if (Test-Path ".env") {
    flutter build apk --release --dart-define-from-file=.env
} else {
    flutter build apk --release
}

$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $sourceApk) -and (Test-Path "C:\tmp\gwash_build\app\outputs\flutter-apk\app-release.apk")) {
    $sourceApk = "C:\tmp\gwash_build\app\outputs\flutter-apk\app-release.apk"
}

if (Test-Path $sourceApk) {
    Copy-Item -Path $sourceApk -Destination ".\g_wash_ng-release.apk" -Force
    Copy-Item -Path $sourceApk -Destination ".\app-release.apk" -Force

    $apkInfo = Get-Item ".\g_wash_ng-release.apk"
    $sizeMB = [math]::Round($apkInfo.Length / 1MB, 1)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  ✅ Release APK Built Successfully ($sizeMB MB)!" -ForegroundColor Green
    Write-Host "  Source: $sourceApk" -ForegroundColor Green
    Write-Host "  Copied to: .\g_wash_ng-release.apk" -ForegroundColor Green
    Write-Host "  Copied to: .\app-release.apk" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Host "❌ Build failed. APK not found." -ForegroundColor Red
    exit 1
}
