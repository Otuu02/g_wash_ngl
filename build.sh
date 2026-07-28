#!/bin/bash

echo "🚀 Starting build process..."

# Install Flutter SDK
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
fi

# Set Flutter PATH correctly
export PATH="$(pwd)/flutter-sdk/bin:$PATH"

# Verify Flutter is available
echo "📋 Flutter version:"
flutter --version || echo "❌ Flutter not found!"

# Enable web
flutter config --enable-web

echo "📦 Getting packages..."
flutter pub get

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
