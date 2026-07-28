#!/bin/bash

echo "🚀 Starting build process..."

# Install Flutter SDK
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
else
  echo "✅ Flutter SDK already exists"
fi

# ADD FLUTTER TO PATH - THIS IS THE KEY FIX
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

# Verify Flutter is available
echo "📋 Checking Flutter..."
if command -v flutter &> /dev/null; then
  echo "✅ Flutter found: $(which flutter)"
  flutter --version
else
  echo "❌ Flutter not found in PATH!"
  echo "Current PATH: $PATH"
  exit 1
fi

# Enable web
echo "🌐 Enabling web..."
flutter config --enable-web

# Get packages
echo "📦 Getting packages..."
flutter pub get

# Build web
echo "🏗️ Building web..."
flutter build web --release

# Check if build succeeded
if [ -d "build/web" ]; then
  echo "✅ Build complete!"
  ls -la build/web/
else
  echo "❌ Build failed - no output directory!"
  exit 1
fi
