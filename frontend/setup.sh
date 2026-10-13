#!/usr/bin/env bash
# Run this ONCE from the frontend/ directory to scaffold the Flutter project boilerplate.
# Our custom source files (lib/, web/index.html, pubspec.yaml) are preserved.
set -euo pipefail

echo "==> Initializing Flutter project boilerplate..."
# --org sets the Android package ID; adjust for your own bundle ID if needed
flutter create . \
  --project-name artisan_commerce \
  --org com.artisan \
  --platforms=android,web \
  --no-overwrite

echo "==> Installing dependencies..."
flutter pub get

echo ""
echo "Done! Now build with:"
echo "  flutter build apk  --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL"
echo "  flutter build web  --dart-define=API_BASE_URL=https://YOUR_CLOUD_RUN_URL"
