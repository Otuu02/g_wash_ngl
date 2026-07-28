#!/bin/bash

echo "🚀 Starting build process..."

# Install Flutter SDK using direct download (more reliable)
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Downloading Flutter SDK..."
  # Use wget to download Flutter
  wget -q --show-progress https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
  echo "📦 Extracting Flutter..."
  tar -xf flutter_linux_3.16.0-stable.tar.xz
  mv flutter flutter-sdk
  rm flutter_linux_3.16.0-stable.tar.xz
fi

# Add Flutter to PATH
export PATH="$(pwd)/flutter-sdk/bin:$PATH"

# Verify Flutter is available
echo "📋 Checking Flutter..."
if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter not found! Checking directory..."
  ls -la flutter-sdk/bin/ || echo "Directory not found!"
  exit 1
fi

echo "✅ Flutter found!"
flutter --version

echo "🌐 Enabling web..."
flutter config --enable-web

echo "📦 Getting packages..."
flutter pub get

echo "🏗️ Building web..."
flutter build web --release

if [ -d "build/web" ]; then
  echo "✅ Build complete!"
  ls -la build/web/
else
  echo "❌ Build failed - no output directory!"
  exit 1
fi
