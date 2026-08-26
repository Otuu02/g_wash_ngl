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

flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  ✅ Release APK Built Successfully with Certificate Pinning!" -ForegroundColor Green
    Write-Host "  Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Build failed. Check errors above." -ForegroundColor Red
    exit 1
}
