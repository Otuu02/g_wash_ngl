#!/bin/bash

echo "🚀 Starting build process..."

# Clone Flutter SDK using git (available on Vercel)
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
fi

# Verify Flutter SDK exists
if [ ! -d "flutter-sdk/bin" ]; then
  echo "❌ Flutter SDK not found!"
  exit 1
fi

# Add Flutter to PATH
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

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
