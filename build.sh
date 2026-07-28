#!/bin/bash

echo "🚀 Starting build process..."

# Install Flutter using the official script
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
fi

export PATH="$PATH:$(pwd)/flutter-sdk/bin"

echo "📋 Flutter version:"
flutter --version

echo "📦 Getting packages..."
flutter pub get

echo "🏗️ Building web..."
flutter build web --release

echo "✅ Build complete!"
