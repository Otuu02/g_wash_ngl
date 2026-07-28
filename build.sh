#!/bin/bash

# Exit on any error
set -e

echo "🚀 Starting build process..."

# Clone Flutter stable branch if it doesn't exist
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Cloning Flutter stable branch..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter-sdk
else
  echo "🔄 Flutter SDK already exists, updating..."
  cd flutter-sdk
  git fetch --depth 1
  git reset --hard origin/stable
  cd ..
fi

# Add Flutter to path
export PATH="$PATH:$(pwd)/flutter-sdk/bin"

# Enable web
echo "🌐 Enabling web..."
flutter config --enable-web

# Print doctor info to verify
echo "📋 Flutter Doctor..."
flutter doctor

# Get packages
echo "📦 Getting packages..."
flutter pub get

# Build web in release mode
echo "🏗️ Building web..."
flutter build web --release

echo "✅ Build complete!"
