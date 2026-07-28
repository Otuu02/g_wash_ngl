#!/bin/bash

echo "🚀 Starting build process..."

# Install Flutter on Vercel
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
fi

# Add Flutter to PATH
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

# Verify Flutter
if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter not found! Installing..."
  rm -rf flutter-sdk
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
  export PATH="$PATH:$(pwd)/flutter-sdk/bin"
fi

echo "✅ Flutter version:"
flutter --version

# Build
flutter config --enable-web
flutter pub get
flutter build web --release

if [ -d "build/web" ]; then
  echo "✅ Build complete!"
  ls -la build/web/
else
  echo "❌ Build failed!"
  exit 1
fi
