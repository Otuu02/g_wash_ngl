#!/bin/bash

echo "🚀 Starting build process..."

# Check if we're on Vercel
if [ "$VERCEL" = "1" ]; then
  echo "📦 Running on Vercel - using pre-installed Flutter"
  
  # On Vercel, Flutter is already installed
  # Just make sure it's in PATH
  export PATH="$PATH:/opt/buildhome/flutter/bin"
  
  # Check if flutter exists
  if command -v flutter &> /dev/null; then
    echo "✅ Flutter found!"
    flutter --version
  else
    echo "❌ Flutter not found in /opt/buildhome/flutter"
    exit 1
  fi
else
  # Local build - install Flutter
  if [ ! -d "flutter-sdk" ]; then
    echo "📦 Installing Flutter locally..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
  fi
  
  export PATH="$PATH:$(pwd)/flutter-sdk/bin"
  
  if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found!"
    exit 1
  fi
  
  echo "✅ Flutter found!"
  flutter --version
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

# Verify build
if [ -d "build/web" ]; then
  echo "✅ Build complete!"
  ls -la build/web/
else
  echo "❌ Build failed!"
  exit 1
fi
