#!/bin/bash
set -e  # Exit immediately on any error

echo "🚀 Starting G-Wash NG Vercel build..."

# ─── Install Flutter ─────────────────────────────────────────────────────────
if [ ! -d "flutter-sdk" ]; then
  echo "📦 Installing Flutter SDK (3.24.0)..."
  git clone https://github.com/flutter/flutter.git -b 3.24.0 --depth 1 flutter-sdk
fi

export PATH="$PATH:$(pwd)/flutter-sdk/bin"

# Verify Flutter is available
if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter not found after install. Retrying..."
  rm -rf flutter-sdk
  git clone https://github.com/flutter/flutter.git -b 3.24.0 --depth 1 flutter-sdk
  export PATH="$PATH:$(pwd)/flutter-sdk/bin"
fi


echo "✅ Flutter version:"
flutter --version

# ─── Configure & Fetch Packages ─────────────────────────────────────────────
flutter config --enable-web
flutter pub get

# ─── Build Web ───────────────────────────────────────────────────────────────
# All secrets are injected from Vercel Environment Variables.
# Set these in your Vercel dashboard → Project → Settings → Environment Variables.
echo "🔑 Injecting environment variables from Vercel..."

flutter build web --release --no-tree-shake-icons \
  --dart-define=PAYSTACK_PUBLIC_KEY="${PAYSTACK_PUBLIC_KEY:-}" \
  --dart-define=PAYSTACK_SECRET_KEY="${PAYSTACK_SECRET_KEY:-}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}" \
  --dart-define=CLOUDINARY_CLOUD_NAME="${CLOUDINARY_CLOUD_NAME:-}" \
  --dart-define=CLOUDINARY_API_KEY="${CLOUDINARY_API_KEY:-}" \
  --dart-define=CLOUDINARY_API_SECRET="${CLOUDINARY_API_SECRET:-}" \
  --dart-define=TWILIO_ACCOUNT_SID="${TWILIO_ACCOUNT_SID:-}" \
  --dart-define=TWILIO_AUTH_TOKEN="${TWILIO_AUTH_TOKEN:-}" \
  --dart-define=TWILIO_PHONE_NUMBER="${TWILIO_PHONE_NUMBER:-}" \
  --dart-define=GMAIL_USER="${GMAIL_USER:-}" \
  --dart-define=GMAIL_APP_PASSWORD="${GMAIL_APP_PASSWORD:-}" \
  --dart-define=SMTP_HOST="${SMTP_HOST:-smtp.gmail.com}" \
  --dart-define=SMTP_PORT="${SMTP_PORT:-587}"


# ─── Verify Output ───────────────────────────────────────────────────────────
if [ -d "build/web" ]; then
  echo "✅ Build complete! Output:"
  ls -la build/web/
else
  echo "❌ Build failed — build/web directory not found!"
  exit 1
fi
